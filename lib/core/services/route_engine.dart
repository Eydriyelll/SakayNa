import 'package:latlong2/latlong.dart';
import '../../models/place.dart';
import '../../models/route_leg.dart';
import '../../models/transit_mode.dart';

class NetworkEdge {
  const NetworkEdge(this.a, this.b, this.mode, this.label, {this.todaZone, this.verified = false});
  final String a;
  final String b;
  final TransitMode mode;
  final String label;
  final String? todaZone;
  final bool verified;
}

class _Hop {
  _Hop(this.from, this.to, this.edge);
  final String from;
  final String to;
  final NetworkEdge edge;
}

/// Dijkstra over the local transit graph.
/// - Tricycle edges cost [tricycleCostMultiplier]x, so PUJ corridors win wherever they exist
///   and tricycles are used mainly for first/last-mile links.
/// - Changing vehicle/route costs [transferPenaltyKm].
class RouteEngine {
  RouteEngine({
    required this.places,
    required this.edges,
    this.tricycleCostMultiplier = 3.0,
    this.transferPenaltyKm = 1.5,
  });

  final Map<String, Place> places;
  final List<NetworkEdge> edges;
  final double tricycleCostMultiplier;
  final double transferPenaltyKm;

  static const walkingSpeedKmh = 5.0;
  static const maxWalkingMinutes = 10;
  static const maxWalkingDistanceKm = 1.0;

  /// Straight-line distance is multiplied by this to approximate road distance
  /// (replaced by real road distance when Mapbox Directions is available).
  static const roadFactor = 1.3;
  final Distance _dist = const Distance();

  static bool isWalkableDistance(double estimatedRoadKm) =>
      estimatedRoadKm <= maxWalkingDistanceKm &&
      estimatedRoadKm / walkingSpeedKmh * 60 <= maxWalkingMinutes;

  static int walkingMinutes(double distanceKm) =>
      (distanceKm / walkingSpeedKmh * 60).ceil();

  List<Place> get placeList => places.values.toList();

  double edgeKm(NetworkEdge e) =>
      _dist.as(LengthUnit.Kilometer, places[e.a]!.position, places[e.b]!.position) * roadFactor;

  TransitRoute? findBetween(Place from, Place to) {
    if (places.containsKey(from.id) && places.containsKey(to.id)) {
      return find(from.id, to.id);
    }

    final expandedPlaces = {...places};
    final expandedEdges = [...edges];
    for (final endpoint in [from, to]) {
      if (expandedPlaces.containsKey(endpoint.id)) continue;
      expandedPlaces[endpoint.id] = endpoint;
      final nearest = places.values.reduce((a, b) {
        final distanceA = _dist.as(
          LengthUnit.Meter,
          endpoint.position,
          a.position,
        );
        final distanceB = _dist.as(
          LengthUnit.Meter,
          endpoint.position,
          b.position,
        );
        return distanceA <= distanceB ? a : b;
      });
      final distanceMeters = _dist.as(
        LengthUnit.Meter,
        endpoint.position,
        nearest.position,
      );
      final estimatedRoadKm = distanceMeters / 1000 * roadFactor;
      final mode = isWalkableDistance(estimatedRoadKm)
          ? TransitMode.walk
          : TransitMode.tricycle;
      expandedEdges.add(NetworkEdge(
        endpoint.id,
        nearest.id,
        mode,
        mode == TransitMode.walk
            ? 'Walk to ${nearest.name}'
            : 'Estimated TODA access near ${endpoint.name}',
        todaZone: 'toda-${endpoint.city.toLowerCase().replaceAll(' ', '-')}',
      ));
    }
    return RouteEngine(
      places: expandedPlaces,
      edges: expandedEdges,
      tricycleCostMultiplier: tricycleCostMultiplier,
      transferPenaltyKm: transferPenaltyKm,
    ).find(from.id, to.id);
  }

  TransitRoute? find(String fromId, String toId) {
    if (fromId == toId || !places.containsKey(fromId) || !places.containsKey(toId)) return null;

    final dist = <String, double>{for (final id in places.keys) id: double.infinity};
    final prev = <String, _Hop>{};
    final open = places.keys.toSet();
    dist[fromId] = 0;

    while (open.isNotEmpty) {
      String? u;
      for (final id in open) {
        if (u == null || dist[id]! < dist[u]!) u = id;
      }
      if (u == null || dist[u]!.isInfinite) break;
      final here = u;
      open.remove(here);
      if (here == toId) break;

      for (final e in edges) {
        final String? v = e.a == here ? e.b : (e.b == here ? e.a : null);
        if (v == null || !open.contains(v)) continue;
        final km = edgeKm(e);
        final weighted = e.mode == TransitMode.tricycle ? km * tricycleCostMultiplier : km;
        final prevLabel = prev[here]?.edge.label;
        final penalty = (prevLabel != null && prevLabel != e.label) ? transferPenaltyKm : 0.0;
        final alt = dist[here]! + weighted + penalty;
        if (alt < dist[v]!) {
          dist[v] = alt;
          prev[v] = _Hop(here, v, e);
        }
      }
    }
    if (!prev.containsKey(toId)) return null;

    final hops = <_Hop>[];
    var cur = toId;
    while (cur != fromId) {
      final h = prev[cur]!;
      hops.add(h);
      cur = h.from;
    }
    return TransitRoute(legs: _mergeIntoLegs(hops.reversed.toList()));
  }

  List<RouteLeg> _mergeIntoLegs(List<_Hop> hops) {
    final legs = <RouteLeg>[];
    String? label;
    TransitMode? mode;
    String? zone;
    String fromId = '';
    String toId = '';
    double km = 0;
    bool verified = true;
    List<LatLng> line = [];

    void flush() {
      if (label == null) return;
      final from = places[fromId]!.name;
      final to = places[toId]!.name;
      final isTrike = mode == TransitMode.tricycle;
      legs.add(RouteLeg(
        mode: mode!,
        instruction: isTrike
            ? 'Take a tricycle ($label) from $from to $to.'
            : mode == TransitMode.walk
                ? 'Walk from $from to $to.'
                : 'Board $label at $from. Alight at $to.',
        fromName: from,
        toName: to,
        distanceKm: km,
        polyline: line,
        routeLabel: label,
        todaZone: zone,
        verified: verified,
      ));
    }

    for (final h in hops) {
      if (h.edge.label != label) {
        flush();
        label = h.edge.label;
        mode = h.edge.mode;
        zone = h.edge.todaZone;
        fromId = h.from;
        km = 0;
        verified = true;
        line = [places[h.from]!.position];
      }
      toId = h.to;
      km += edgeKm(h.edge);
      verified = verified && h.edge.verified;
      line.add(places[h.to]!.position);
    }
    flush();
    return legs;
  }
}
