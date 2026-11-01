import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/fare_engine.dart';
import '../core/services/road_router.dart';
import '../core/services/route_engine.dart';
import '../data/transit_network.dart';
import '../models/fare_result.dart';
import '../models/place.dart';
import '../models/route_leg.dart';
import '../models/transit_mode.dart';
import '../models/trip_record.dart';

/// Overridden in main() with the real SharedPreferences instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final routeEngineProvider = Provider<RouteEngine>(
  (ref) => RouteEngine(places: TransitNetwork.placeMap, edges: TransitNetwork.buildEdges()),
);
final fareEngineProvider = Provider<FareEngine>((ref) => const FareEngine());
final roadRouterProvider = Provider<RoadRouter>((ref) => RoadRouter(ref.watch(sharedPrefsProvider)));

final originProvider = StateProvider<Place?>((ref) => null);
final destinationProvider = StateProvider<Place?>((ref) => null);

enum MapPinTarget { origin, destination }

final mapPinTargetProvider = StateProvider<MapPinTarget?>((ref) => null);

/// null = price jeepney legs as routed; otherwise re-price/recolor them as this PUJ type.
final pujOverrideProvider = StateProvider<TransitMode?>((ref) => null);
final tricycleServiceProvider = StateProvider<TricycleService>((ref) => TricycleService.shared);

bool _isPuj(TransitMode m) => m == TransitMode.pujTraditional || m == TransitMode.pujModern;
String _sig(TransitRoute r) => r.legs.map((l) => '${l.routeLabel}|${l.fromName}|${l.toName}').join('>');

/// Route on the local graph (straight lines between stops).
final baseRouteProvider = Provider<TransitRoute?>((ref) {
  final o = ref.watch(originProvider);
  final d = ref.watch(destinationProvider);
  if (o == null || d == null) return null;
  return ref.watch(routeEngineProvider).findBetween(o, d);
});

class RefinedRoute {
  const RefinedRoute(this.sig, this.route);
  final String sig;
  final TransitRoute route;
}

/// Same route snapped to real roads (when a Mapbox token is configured).
final roadRouteProvider = FutureProvider<RefinedRoute?>((ref) async {
  final base = ref.watch(baseRouteProvider);
  if (base == null) return null;
  final refined = await ref.watch(roadRouterProvider).refine(base);
  return RefinedRoute(_sig(base), refined);
});

final roadLoadingProvider = Provider<bool>(
  (ref) => ref.watch(baseRouteProvider) != null && ref.watch(roadRouteProvider).isLoading,
);

/// The route the UI shows and prices: road-snapped if ready, with the user's jeepney choice applied.
final routeProvider = Provider<TransitRoute?>((ref) {
  final base = ref.watch(baseRouteProvider);
  if (base == null) return null;
  final road = ref.watch(roadRouteProvider).valueOrNull;
  var route = (road != null && road.sig == _sig(base)) ? road.route : base;
  final override = ref.watch(pujOverrideProvider);
  if (override != null) {
    route = TransitRoute(legs: [for (final l in route.legs) _isPuj(l.mode) ? l.withMode(override) : l]);
  }
  return route;
});

/// Live fare - recalculated automatically whenever the route or options change.
final fareProvider = Provider<FareBreakdown?>((ref) {
  final route = ref.watch(routeProvider);
  if (route == null) return null;
  final trike = ref.watch(tricycleServiceProvider);
  return ref.watch(fareEngineProvider).breakdown(route, tricycle: trike);
});

// ---------------- Trip history ----------------
class TripHistoryNotifier extends Notifier<List<TripRecord>> {
  static const _key = 'sakayna_trip_history_v1';

  @override
  List<TripRecord> build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [for (final e in list) TripRecord.fromJson(e as Map<String, dynamic>)];
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while reading saved SakayNa! trip history'),
      ));
      return [];
    }
  }

  Future<void> add(TripRecord r) async {
    final next = [r, ...state].take(200).toList();
    await _save(next);
    state = next;
  }

  Future<void> remove(String id) async {
    final next = state.where((t) => t.id != id).toList();
    await _save(next);
    state = next;
  }

  Future<void> clear() async {
    await _save([]);
    state = [];
  }

  Future<void> _save(List<TripRecord> trips) async {
    final saved = await ref.read(sharedPrefsProvider).setString(
          _key,
          jsonEncode(trips.map((t) => t.toJson()).toList()),
        );
    if (!saved) throw StateError('Could not save trip history on this device.');
  }
}

final tripHistoryProvider =
    NotifierProvider<TripHistoryNotifier, List<TripRecord>>(TripHistoryNotifier.new);
