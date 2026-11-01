import 'package:latlong2/latlong.dart';
import 'transit_mode.dart';

class RouteLeg {
  const RouteLeg({
    required this.mode,
    required this.instruction,
    required this.fromName,
    required this.toName,
    required this.distanceKm,
    required this.polyline,
    this.routeLabel,
    this.todaZone,
    this.verified = false,
    this.roadSnapped = false,
  });

  final TransitMode mode;
  final String instruction;
  final String fromName;
  final String toName;
  final double distanceKm;
  final List<LatLng> polyline;
  final String? routeLabel;
  final String? todaZone;

  /// false = corridor/link is an approximation that still needs a field survey.
  final bool verified;
  final bool roadSnapped;

  RouteLeg withMode(TransitMode m) => RouteLeg(
        mode: m,
        instruction: instruction,
        fromName: fromName,
        toName: toName,
        distanceKm: distanceKm,
        polyline: polyline,
        routeLabel: routeLabel,
        todaZone: todaZone,
        verified: verified,
        roadSnapped: roadSnapped,
      );

  RouteLeg withGeometry(List<LatLng> points, double km) => RouteLeg(
        mode: mode,
        instruction: instruction,
        fromName: fromName,
        toName: toName,
        distanceKm: km,
        polyline: points,
        routeLabel: routeLabel,
        todaZone: todaZone,
        verified: verified,
        roadSnapped: true,
      );
}

class TransitRoute {
  const TransitRoute({required this.legs});
  final List<RouteLeg> legs;

  double get totalKm => legs.fold(0.0, (s, l) => s + l.distanceKm);
  bool get allVerified => legs.every((l) => l.verified);
  bool get allRoadSnapped => legs.every((l) => l.roadSnapped);
  Iterable<RouteLeg> get paidLegs => legs.where((l) => l.mode != TransitMode.walk);
}
