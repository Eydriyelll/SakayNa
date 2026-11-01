import 'package:latlong2/latlong.dart';
import '../core/services/route_engine.dart';
import '../models/place.dart';
import '../models/transit_mode.dart';

/// SakayNa! network data - BETA.
///
/// What is solid: the 18 Cabuyao + 18 Santa Rosa barangay names (PSA).
/// What is approximate: ALL coordinates here except Mamatid and Balibago
/// (PhilAtlas) are estimates. Refine them with tools/geocode_places.dart.
/// Routes: only Calamba Crossing -> Pulo (jeepney) and PUDTODA -> Mapua MCL
/// (tricycle) are documented; every other PUJ link and non-corridor barangay
/// TODA link is auto-generated/approximate and needs a field survey. Barangays
/// already on the represented PUJ corridor are connected directly to that
/// corridor rather than assigned a fabricated TODA stand.
/// Keep the _b/_t/_l(...) call format: the geocode tool edits those lines.
class TransitNetwork {
  TransitNetwork._();

  static Place _b(String id, String name, String city, double lat, double lng) =>
      Place(id: id, name: name, city: city, kind: PlaceKind.barangay, position: LatLng(lat, lng));
  static Place _t(String id, String name, String city, double lat, double lng) =>
      Place(id: id, name: name, city: city, kind: PlaceKind.terminal, position: LatLng(lat, lng));
  static Place _l(String id, String name, String city, double lat, double lng) =>
      Place(id: id, name: name, city: city, kind: PlaceKind.landmark, position: LatLng(lat, lng));

  static final List<Place> places = [
    // ---- Terminals & landmarks ----
    _t('calamba_crossing', 'Calamba Central Terminal (Crossing)', 'Calamba', 14.2117, 121.1653),
    _t('pulo_stop', 'Pulo Jeepney Stop & PUDTODA Terminal (Jollibee Pulo)', 'Cabuyao', 14.2470, 121.1300),
    _t('st_james_puj_stop', 'St. James Hospital SB PUJ Stop', 'Cabuyao', 14.2764, 121.1218),
    _t('mariquita_puj_stop', 'Mariquita Pueblo SB PUJ Stop', 'Cabuyao', 14.2770, 121.1255),
    _t('mamatid_terminal', 'Mamatid Terminal', 'Cabuyao', 14.2360, 121.1565),
    _t('balibago_terminal', 'Balibago Terminal', 'Santa Rosa', 14.3020, 121.1040),
    _t('strit', 'Santa Rosa Integrated Terminal (STRIT)', 'Santa Rosa', 14.3035, 121.0925),
    _l('cabuyao_plaza', 'Cabuyao City Hall & Plaza', 'Cabuyao', 14.2760, 121.1240),
    _l('mapua_mcl', 'Mapua Malayan Colleges Laguna', 'Cabuyao', 14.2440, 121.1160),
    _l('sm_santa_rosa', 'SM City Santa Rosa', 'Santa Rosa', 14.3100, 121.1115),

    // ---- Cabuyao: 18 barangays ----
    _b('baclaran', 'Baclaran', 'Cabuyao', 14.2720, 121.1440),
    _b('banay_banay', 'Banay-Banay', 'Cabuyao', 14.2830, 121.1120),
    _b('banlic', 'Banlic', 'Cabuyao', 14.2290, 121.1430),
    _b('uno', 'Barangay Uno (Poblacion)', 'Cabuyao', 14.2778, 121.1235),
    _b('dos', 'Barangay Dos (Poblacion)', 'Cabuyao', 14.2790, 121.1248),
    _b('tres', 'Barangay Tres (Poblacion)', 'Cabuyao', 14.2765, 121.1226),
    _b('bigaa', 'Bigaa', 'Cabuyao', 14.2860, 121.1420),
    _b('butong', 'Butong', 'Cabuyao', 14.2790, 121.1390),
    _b('casile', 'Casile', 'Cabuyao', 14.2290, 121.0900),
    _b('diezmo', 'Diezmo', 'Cabuyao', 14.2480, 121.1110),
    _b('gulod', 'Gulod', 'Cabuyao', 14.2590, 121.1450),
    _b('mamatid', 'Mamatid', 'Cabuyao', 14.2352, 121.1575),
    _b('marinig', 'Marinig', 'Cabuyao', 14.2480, 121.1500),
    _b('niugan', 'Niugan', 'Cabuyao', 14.2830, 121.1300),
    _b('pittland', 'Pittland', 'Cabuyao', 14.2390, 121.1050),
    _b('pulo', 'Pulo', 'Cabuyao', 14.2490, 121.1290),
    _b('sala', 'Sala', 'Cabuyao', 14.2860, 121.1220),
    _b('san_isidro', 'San Isidro', 'Cabuyao', 14.2640, 121.1180),

    // ---- Santa Rosa: 18 barangays ----
    _b('aplaya', 'Aplaya', 'Santa Rosa', 14.3080, 121.1290),
    _b('balibago', 'Balibago', 'Santa Rosa', 14.2946, 121.1054),
    _b('caingin', 'Caingin', 'Santa Rosa', 14.3040, 121.0950),
    _b('dila', 'Dila', 'Santa Rosa', 14.3290, 121.1010),
    _b('dita', 'Dita', 'Santa Rosa', 14.3250, 121.0900),
    _b('don_jose', 'Don Jose', 'Santa Rosa', 14.3170, 121.0860),
    _b('ibaba', 'Ibaba', 'Santa Rosa', 14.3145, 121.1160),
    _b('kanluran', 'Kanluran (Poblacion)', 'Santa Rosa', 14.3150, 121.1080),
    _b('labas', 'Labas', 'Santa Rosa', 14.3210, 121.1100),
    _b('macabling', 'Macabling', 'Santa Rosa', 14.3270, 121.1170),
    _b('malitlit', 'Malitlit', 'Santa Rosa', 14.3300, 121.0830),
    _b('malusak', 'Malusak (Poblacion)', 'Santa Rosa', 14.3135, 121.1105),
    _b('market_area', 'Market Area (Poblacion)', 'Santa Rosa', 14.3120, 121.1135),
    _b('pook', 'Pook', 'Santa Rosa', 14.3090, 121.0990),
    _b('pulong_sta_cruz', 'Pulong Santa Cruz', 'Santa Rosa', 14.2870, 121.1000),
    _b('santo_domingo', 'Santo Domingo', 'Santa Rosa', 14.3130, 121.0780),
    _b('sinalhan', 'Sinalhan', 'Santa Rosa', 14.2940, 121.1200),
    _b('tagapo', 'Tagapo', 'Santa Rosa', 14.3000, 121.1110),
  ];

  static Map<String, Place> get placeMap => {for (final p in places) p.id: p};

  static const _trunk = 'Calamba - Cabuyao - Sta. Rosa PUJ';
  static const _mamatidLine = 'Mamatid - Cabuyao PUJ';
  static const _stritLine = 'Balibago - STRIT PUJ';

  static NetworkEdge _puj(String a, String b, String label, {bool verified = false}) =>
      NetworkEdge(a, b, TransitMode.pujTraditional, label, verified: verified);

  /// Corridors are jeepney (PUJ) links. Other places connect to their nearest
  /// corridor as a walk when it is within the walking limit, otherwise by
  /// estimated tricycle (TODA) access. The jeepney type can be switched to
  /// Modern PUJ in the app, which re-prices and recolors those legs.
  static List<NetworkEdge> buildEdges() {
    final byId = placeMap;
    final edges = <NetworkEdge>[
      _puj('calamba_crossing', 'pulo_stop', _trunk, verified: true), // documented (Mapua MCL guide)
      _puj('pulo_stop', 'cabuyao_plaza', _trunk),
      // These marked SB stops are mapped from the supplied map reference;
      // their coordinates and links remain approximate pending field survey.
      _puj('st_james_puj_stop', 'cabuyao_plaza', _trunk),
      _puj('mariquita_puj_stop', 'cabuyao_plaza', _trunk),
      _puj('cabuyao_plaza', 'sala', _trunk),
      _puj('sala', 'balibago_terminal', _trunk),
      _puj('balibago_terminal', 'sm_santa_rosa', _trunk),
      _puj('sm_santa_rosa', 'market_area', _trunk),
      _puj('mamatid_terminal', 'marinig', _mamatidLine),
      _puj('marinig', 'gulod', _mamatidLine),
      _puj('gulod', 'cabuyao_plaza', _mamatidLine),
      _puj('balibago_terminal', 'strit', _stritLine),
      const NetworkEdge('mapua_mcl', 'pulo_stop', TransitMode.tricycle, 'PUDTODA (Pulo)',
          todaZone: 'pudtoda-pulo', verified: true), // documented (Mapua MCL guide)
    ];

    const anchors = [
      'pulo_stop', 'st_james_puj_stop', 'mariquita_puj_stop', 'cabuyao_plaza',
      'sala', 'balibago_terminal', 'sm_santa_rosa',
      'market_area', 'mamatid_terminal', 'marinig', 'gulod', 'strit',
    ];
    const skip = {...anchors, 'calamba_crossing', 'mapua_mcl'};
    const meters = Distance();

    for (final p in places) {
      if (skip.contains(p.id)) continue;
      var best = anchors.first;
      var bestD = double.infinity;
      for (final a in anchors) {
        final d = meters.as(LengthUnit.Meter, p.position, byId[a]!.position);
        if (d < bestD) {
          bestD = d;
          best = a;
        }
      }
      final estimatedRoadKm = bestD / 1000 * RouteEngine.roadFactor;
      final mode = RouteEngine.isWalkableDistance(estimatedRoadKm)
          ? TransitMode.walk
          : TransitMode.tricycle;
      edges.add(NetworkEdge(
        p.id,
        best,
        mode,
        mode == TransitMode.walk
            ? 'Walk to ${byId[best]!.name}'
            : '${p.name} TODA',
        todaZone: mode == TransitMode.tricycle ? 'toda-${p.id}' : null,
      ));
    }
    return edges;
  }
}
