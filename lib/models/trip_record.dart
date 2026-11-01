import 'package:latlong2/latlong.dart';

import 'fare_result.dart';
import 'transit_mode.dart';

class TripLine {
  const TripLine({
    required this.mode,
    required this.label,
    required this.regularCentavos,
    required this.discountedCentavos,
    required this.discountApplies,
  });

  factory TripLine.fromFareLine(FareLine l) => TripLine(
        mode: l.mode,
        label: l.label,
        regularCentavos: l.regularCentavos,
        discountedCentavos: l.discountedCentavos,
        discountApplies: l.discountApplies,
      );

  factory TripLine.fromJson(Map<String, dynamic> j) => TripLine(
        mode: TransitMode.values.byName(j['mode'] as String),
        label: j['label'] as String,
        regularCentavos: j['regular'] as int,
        discountedCentavos: j['discounted'] as int,
        discountApplies: j['discountApplies'] as bool,
      );

  final TransitMode mode;
  final String label;
  final int regularCentavos;
  final int discountedCentavos;
  final bool discountApplies;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'label': label,
        'regular': regularCentavos,
        'discounted': discountedCentavos,
        'discountApplies': discountApplies,
      };
}

class TripRecord {
  const TripRecord({
    required this.id,
    required this.createdAt,
    required this.originId,
    required this.originName,
    required this.destId,
    required this.destName,
    required this.totalKm,
    required this.lines,
    required this.regularTotal,
    required this.discountedTotal,
    this.pujChoice,
    this.tricycleService = 'shared',
    this.originPosition,
    this.destPosition,
    this.originCity,
    this.destCity,
  });

  factory TripRecord.fromJson(Map<String, dynamic> j) => TripRecord(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        originId: j['originId'] as String,
        originName: j['originName'] as String,
        destId: j['destId'] as String,
        destName: j['destName'] as String,
        totalKm: (j['totalKm'] as num).toDouble(),
        lines: [for (final l in j['lines'] as List<dynamic>) TripLine.fromJson(l as Map<String, dynamic>)],
        regularTotal: j['regularTotal'] as int,
        discountedTotal: j['discountedTotal'] as int,
        pujChoice: j['pujChoice'] as String?,
        tricycleService: (j['tricycleService'] as String?) ?? 'shared',
        originPosition: _positionFromJson(j, 'origin'),
        destPosition: _positionFromJson(j, 'dest'),
        originCity: j['originCity'] as String?,
        destCity: j['destCity'] as String?,
      );

  final String id;
  final DateTime createdAt;
  final String originId;
  final String originName;
  final String destId;
  final String destName;
  final double totalKm;
  final List<TripLine> lines;
  final int regularTotal;
  final int discountedTotal;
  final String? pujChoice; // null = as routed
  final String tricycleService; // 'shared' | 'special'
  final LatLng? originPosition;
  final LatLng? destPosition;
  final String? originCity;
  final String? destCity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'originId': originId,
        'originName': originName,
        'destId': destId,
        'destName': destName,
        'totalKm': totalKm,
        'lines': lines.map((l) => l.toJson()).toList(),
        'regularTotal': regularTotal,
        'discountedTotal': discountedTotal,
        'pujChoice': pujChoice,
        'tricycleService': tricycleService,
        if (originPosition != null) ...{
          'originLat': originPosition!.latitude,
          'originLng': originPosition!.longitude,
        },
        if (originCity != null) 'originCity': originCity,
        if (destPosition != null) ...{
          'destLat': destPosition!.latitude,
          'destLng': destPosition!.longitude,
        },
        if (destCity != null) 'destCity': destCity,
      };

  static LatLng? _positionFromJson(Map<String, dynamic> json, String prefix) {
    final lat = json['${prefix}Lat'];
    final lng = json['${prefix}Lng'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }
}
