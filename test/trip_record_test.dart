import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parapo_transpo/models/transit_mode.dart';
import 'package:parapo_transpo/models/trip_record.dart';
import 'package:parapo_transpo/providers/app_providers.dart';

void main() {
  final trip = TripRecord(
    id: '1',
    createdAt: DateTime(2026, 11, 1, 9, 30),
    originId: 'pulo',
    originName: 'Pulo',
    destId: 'balibago',
    destName: 'Balibago',
    totalKm: 9.4,
    lines: const [
      TripLine(
        mode: TransitMode.pujModern,
        label: 'Calamba - Cabuyao - Sta. Rosa PUJ',
        regularCentavos: 2600,
        discountedCentavos: 2075,
        discountApplies: true,
      ),
    ],
    regularTotal: 2600,
    discountedTotal: 2075,
    pujChoice: 'Modern PUJ',
    tricycleService: 'special',
    originPosition: const LatLng(14.2501, 121.1297),
    destPosition: const LatLng(14.3101, 121.1112),
    originCity: 'Cabuyao',
    destCity: 'Santa Rosa',
  );

  test('TripRecord survives a JSON round trip', () {
    final back = TripRecord.fromJson(trip.toJson());
    expect(back.id, trip.id);
    expect(back.lines.single.mode, TransitMode.pujModern);
    expect(back.discountedTotal, 2075);
    expect(back.tricycleService, 'special');
    expect(back.createdAt, trip.createdAt);
    expect(back.originPosition, trip.originPosition);
    expect(back.destPosition, trip.destPosition);
    expect(back.destCity, trip.destCity);
  });

  test('trip history writes and clears persisted records', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(preferences),
    ]);
    addTearDown(container.dispose);

    await container.read(tripHistoryProvider.notifier).add(trip);

    expect(container.read(tripHistoryProvider), [trip]);
    final saved = jsonDecode(
      preferences.getString('sakayna_trip_history_v1')!,
    ) as List<dynamic>;
    expect(
      TripRecord.fromJson(saved.single as Map<String, dynamic>).id,
      trip.id,
    );

    await container.read(tripHistoryProvider.notifier).clear();
    expect(container.read(tripHistoryProvider), isEmpty);
  });
}
