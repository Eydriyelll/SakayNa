import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/route_leg.dart';
import '../config/app_config.dart';

class RoadRouter {
  RoadRouter(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  static const _maxWaypoints = 25;
  static const _snapRadiusMeters = 100;

  final SharedPreferences _prefs;
  final http.Client _client;
  final Map<String, ({List<LatLng> points, double km})> _cache = {};

  Future<TransitRoute> refine(TransitRoute route) async {
    if (!AppConfig.hasMapbox) return route;
    final legs = <RouteLeg>[];
    for (final leg in route.legs) {
      legs.add(await _refineLeg(leg));
    }
    return TransitRoute(legs: legs);
  }

  Future<RouteLeg> _refineLeg(RouteLeg leg) async {
    if (leg.polyline.length < 2) return leg;
    final key = leg.polyline
        .map((point) =>
            '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}')
        .join(';');
    final cached = _cache[key];
    if (cached != null) {
      return leg.withGeometry(cached.points, cached.km);
    }

    final points = <LatLng>[];
    var distanceKm = 0.0;
    var offset = 0;
    while (offset < leg.polyline.length - 1) {
      final end = (offset + _maxWaypoints).clamp(0, leg.polyline.length);
      final waypoints = leg.polyline.sublist(offset, end);
      final result = await _requestRoadGeometry(waypoints);
      if (result == null) return leg;
      points.addAll(points.isEmpty ? result.points : result.points.skip(1));
      distanceKm += result.km;
      offset = end - 1;
    }

    if (points.length < 2) return leg;
    _cache[key] = (points: points, km: distanceKm);
    return leg.withGeometry(points, distanceKm);
  }

  Future<({List<LatLng> points, double km})?> _requestRoadGeometry(
    List<LatLng> waypoints,
  ) async {
    if (!await _consume()) return null;
    final coordinates = waypoints
        .map((point) =>
            '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}')
        .join(';');
    final radiuses = List.filled(
      waypoints.length,
      '$_snapRadiusMeters',
    ).join(';');
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/$coordinates',
      {
        'geometries': 'geojson',
        'overview': 'full',
        'radiuses': radiuses,
        'access_token': AppConfig.mapboxToken,
      },
    );

    try {
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode != 200) {
        debugPrint(
          'Mapbox road snapping failed with HTTP ${response.statusCode}.',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint('Mapbox did not find a road route for a transit leg.');
        return null;
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final rawPoints = geometry['coordinates'] as List<dynamic>;
      final points = <LatLng>[
        for (final coordinate in rawPoints)
          if (coordinate is List<dynamic> &&
              coordinate.length >= 2 &&
              coordinate[0] is num &&
              coordinate[1] is num)
            LatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            ),
      ];
      if (points.length < 2 || route['distance'] is! num) {
        debugPrint('Mapbox returned incomplete road geometry.');
        return null;
      }
      return (
        points: points,
        km: (route['distance'] as num).toDouble() / 1000,
      );
    } catch (error) {
      debugPrint('Mapbox road snapping failed: $error');
      return null;
    }
  }

  Future<bool> _consume() async {
    final now = DateTime.now();
    final key = 'mb_dir_${now.year}_${now.month}';
    final used = _prefs.getInt(key) ?? 0;
    if (used >= AppConfig.mapboxMonthlyCap) return false;
    final saved = await _prefs.setInt(key, used + 1);
    if (!saved) {
      debugPrint('Mapbox routing stopped because its local usage cap was not saved.');
    }
    return saved;
  }
}
