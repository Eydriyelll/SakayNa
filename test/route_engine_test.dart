import 'package:flutter_test/flutter_test.dart';
import 'package:parapo_transpo/core/constants/fare_rates.dart';
import 'package:parapo_transpo/core/services/fare_engine.dart';
import 'package:parapo_transpo/core/services/route_engine.dart';
import 'package:parapo_transpo/data/transit_network.dart';
import 'package:parapo_transpo/models/place.dart';
import 'package:parapo_transpo/models/transit_mode.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final places = TransitNetwork.placeMap;
  final edges = TransitNetwork.buildEdges();
  final engine = RouteEngine(places: places, edges: edges);

  test('all 18 Cabuyao + 18 Santa Rosa barangays are present', () {
    int count(String city) => TransitNetwork.places
        .where((p) => p.kind == PlaceKind.barangay && p.city == city)
        .length;
    expect(count('Cabuyao'), 18);
    expect(count('Santa Rosa'), 18);
  });

  test('known terminal stops and a TODA access edge are represented', () {
    final terminals = TransitNetwork.places
        .where((p) => p.kind == PlaceKind.terminal)
        .map((p) => p.id)
        .toSet();
    expect(
      terminals,
      containsAll({
        'calamba_crossing',
        'pulo_stop',
        'st_james_puj_stop',
        'mariquita_puj_stop',
        'mamatid_terminal',
        'balibago_terminal',
        'strit',
      }),
    );
    expect(
      edges.any((e) => e.label == 'PUDTODA (Pulo)'),
      isTrue,
    );
    for (final stop in ['st_james_puj_stop', 'mariquita_puj_stop']) {
      expect(
        edges.any((e) =>
            e.mode == TransitMode.pujTraditional &&
            (e.a == stop || e.b == stop)),
        isTrue,
        reason: stop,
      );
    }
  });

  test('non-corridor barangays have walking or TODA access links', () {
    const pujCorridorPlaces = {
      'pulo',
      'sala',
      'marinig',
      'gulod',
    };
    final barangays = TransitNetwork.places
        .where((p) =>
            p.kind == PlaceKind.barangay && !pujCorridorPlaces.contains(p.id))
        .toList();
    for (final barangay in barangays) {
      expect(
        edges.any((e) =>
            (e.mode == TransitMode.tricycle || e.mode == TransitMode.walk) &&
            (e.a == barangay.id || e.b == barangay.id)),
        isTrue,
        reason: barangay.name,
      );
    }
  });

  test('every edge references existing places and ids are unique', () {
    for (final e in edges) {
      expect(places.containsKey(e.a), isTrue, reason: e.a);
      expect(places.containsKey(e.b), isTrue, reason: e.b);
    }
    expect(places.length, TransitNetwork.places.length);
  });

  test('every place is reachable from Cabuyao City Hall & Plaza', () {
    for (final p in TransitNetwork.places) {
      if (p.id == 'cabuyao_plaza') continue;
      expect(engine.find('cabuyao_plaza', p.id), isNotNull, reason: p.name);
    }
  });

  test('a manually pinned origin connects to the transit network', () {
    const pinned = Place(
      id: 'test_pin',
      name: 'Pinned starting point',
      city: 'Cabuyao',
      kind: PlaceKind.landmark,
      position: LatLng(14.2500, 121.1295),
    );
    final route = engine.findBetween(pinned, places['sm_santa_rosa']!);

    expect(route, isNotNull);
    expect(route!.legs.first.fromName, pinned.name);
    expect(route.legs.last.toName, 'SM City Santa Rosa');
  });

  test('arbitrary nearby origin and destination pins can walk to PUJ stops', () {
    const originPin = Place(
      id: 'near_pulo_pin',
      name: 'Origin pin',
      city: 'Cabuyao',
      kind: PlaceKind.landmark,
      position: LatLng(14.2490, 121.1300),
    );
    const destinationPin = Place(
      id: 'near_cabuyao_pin',
      name: 'Destination pin',
      city: 'Cabuyao',
      kind: PlaceKind.landmark,
      position: LatLng(14.2770, 121.1250),
    );
    final route = engine.findBetween(originPin, destinationPin)!;

    expect(route.legs.first.mode, TransitMode.walk);
    expect(route.legs.last.mode, TransitMode.walk);
    expect(route.legs.any((leg) => leg.mode == TransitMode.pujTraditional), isTrue);
    expect(route.legs.any((leg) => leg.mode == TransitMode.tricycle), isFalse);
  });

  test('Plaza -> Balibago Terminal is one traditional PUJ leg', () {
    final r = engine.find('cabuyao_plaza', 'balibago_terminal')!;
    expect(r.legs.length, 1);
    expect(r.legs.first.mode, TransitMode.pujTraditional);
  });

  test('Pulo barangay -> SM Santa Rosa: walk to PUJ corridor', () {
    final r = engine.find('pulo', 'sm_santa_rosa')!;
    expect(r.legs.first.mode, TransitMode.walk);
    expect(r.legs.last.mode, TransitMode.pujTraditional);
  });

  test('marked Cabuyao route uses a PUJ and one TODA ride to Mapua MCL', () {
    const pinned = Place(
      id: 'mcl_reference_pin',
      name: 'Pinned starting point',
      city: 'Cabuyao',
      kind: PlaceKind.landmark,
      position: LatLng(14.28070, 121.12065),
    );
    final r = engine.findBetween(pinned, places['mapua_mcl']!)!;

    expect(r.legs.any((l) => l.mode == TransitMode.walk), isTrue);
    expect(
      r.legs.where((l) => l.mode == TransitMode.pujTraditional),
      hasLength(1),
    );
    expect(
      r.legs.where((l) => l.mode == TransitMode.tricycle),
      hasLength(1),
    );
  });

  test('walking access is capped at 10 minutes and less than 1 km', () {
    expect(RouteEngine.isWalkableDistance(0.8), isTrue);
    expect(RouteEngine.isWalkableDistance(0.84), isFalse);
    expect(RouteEngine.isWalkableDistance(1.0), isFalse);
    expect(RouteEngine.walkingMinutes(0.8), 10);
  });

  test('fare for a single PUJ leg equals the distance fare', () {
    final r = engine.find('cabuyao_plaza', 'balibago_terminal')!;
    const fares = FareEngine();
    expect(fares.breakdown(r).regularTotal,
        fares.distanceFare(FareRates.pujTraditional, r.legs.first.distanceKm));
  });
}
