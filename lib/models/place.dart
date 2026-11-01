import 'package:latlong2/latlong.dart';

enum PlaceKind { barangay, terminal, landmark }

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.city,
    required this.kind,
    required this.position,
  });
  final String id;
  final String name;
  final String city;
  final PlaceKind kind;
  final LatLng position;

  String get kindLabel => switch (kind) {
        PlaceKind.barangay => 'Barangay',
        PlaceKind.terminal => 'Terminal',
        PlaceKind.landmark => 'Landmark',
      };
  String get subtitle => '$kindLabel · $city';
}
