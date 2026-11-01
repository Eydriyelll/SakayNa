/// All money is stored as INTEGER CENTAVOS to avoid floating point errors.
///
/// VERIFY BEFORE LAUNCH. Rates follow the LTFRB adjustment effective
/// March 19, 2026 as reported by news outlets. Reports differ on the modern
/// PUJ per-km add-on (2.40 vs 2.30), so confirm against the official LTFRB
/// matrix. Tricycle fares are set by LGU/TODA ordinance, so the TODA values
/// below are PLACEHOLDERS until you obtain the Cabuyao / Santa Rosa ordinance.
class DistanceFareRate {
  const DistanceFareRate({
    required this.baseCentavos,
    required this.baseKm,
    required this.perKmCentavos,
  });
  final int baseCentavos;
  final int baseKm;
  final int perKmCentavos;
}

class FareRates {
  static const pujTraditional =
      DistanceFareRate(baseCentavos: 1400, baseKm: 4, perKmCentavos: 200);
  static const pujModern =
      DistanceFareRate(baseCentavos: 1700, baseKm: 4, perKmCentavos: 240);

  /// 20% discount for students, senior citizens, and PWDs.
  static const discountPercent = 20;

  /// Discounted fares rounded to the nearest 0.25 (configurable).
  static const discountRoundingCentavos = 25;
}

class TodaRate {
  const TodaRate({required this.sharedCentavos, required this.specialCentavos});
  final int sharedCentavos; // per person
  final int specialCentavos; // per trip, whole tricycle
}

class TodaFares {
  /// Used for any TODA zone without its own entry. PLACEHOLDER until the
  /// Cabuyao / Santa Rosa tricycle fare ordinances are obtained.
  static const defaultRate = TodaRate(sharedCentavos: 1500, specialCentavos: 6000);

  /// Per-zone overrides, keyed by todaZone id (e.g. 'toda-pulo').
  static const Map<String, TodaRate> zones = {
    'pudtoda-pulo': TodaRate(sharedCentavos: 1500, specialCentavos: 5000),
  };
}
