import '../constants/fare_rates.dart';
import '../../models/fare_result.dart';
import '../../models/route_leg.dart';
import '../../models/transit_mode.dart';

/// Fare calculator. Pure Dart (no Flutter imports) so it is trivially testable.
class FareEngine {
  /// Constructor params double as calibration overrides (fuel surcharges,
  /// new ordinances) without touching the engine logic.
  const FareEngine({
    this.pujTraditional = FareRates.pujTraditional,
    this.pujModern = FareRates.pujModern,
    this.todaZones = TodaFares.zones,
    this.todaDefault = TodaFares.defaultRate,
    this.discountPercent = FareRates.discountPercent,
    this.discountRoundingCentavos = FareRates.discountRoundingCentavos,
  });

  final DistanceFareRate pujTraditional;
  final DistanceFareRate pujModern;
  final Map<String, TodaRate> todaZones;
  final TodaRate todaDefault;
  final int discountPercent;
  final int discountRoundingCentavos;

  /// Base covers the first baseKm; each started km after adds perKm
  /// (matrices are whole-km, so we round UP).
  int distanceFare(DistanceFareRate rate, double km) {
    final wholeKm = km <= 0 ? 0 : km.ceil();
    final extraKm = wholeKm > rate.baseKm ? wholeKm - rate.baseKm : 0;
    return rate.baseCentavos + extraKm * rate.perKmCentavos;
  }

  /// 20% off, then rounded to the nearest [discountRoundingCentavos].
  int applyDiscount(int regularCentavos) {
    final raw = regularCentavos * (100 - discountPercent) ~/ 100;
    final step = discountRoundingCentavos;
    final rem = raw % step;
    return rem * 2 >= step ? raw - rem + step : raw - rem;
  }

  FareLine fareForLeg(RouteLeg leg, {TricycleService tricycle = TricycleService.shared}) {
    switch (leg.mode) {
      case TransitMode.pujTraditional:
        return _line(leg, distanceFare(pujTraditional, leg.distanceKm));
      case TransitMode.pujModern:
        return _line(leg, distanceFare(pujModern, leg.distanceKm));
      case TransitMode.tricycle:
        final rate = todaZones[leg.todaZone] ?? todaDefault;
        final special = tricycle == TricycleService.special;
        // Assumption: chartered (special) trips are not discountable.
        return _line(leg, special ? rate.specialCentavos : rate.sharedCentavos,
            discountable: !special);
      case TransitMode.walk:
        return FareLine(
            mode: leg.mode, label: leg.instruction, regularCentavos: 0, discountedCentavos: 0);
    }
  }

  FareBreakdown breakdown(TransitRoute route,
          {TricycleService tricycle = TricycleService.shared}) =>
      FareBreakdown(route.paidLegs.map((l) => fareForLeg(l, tricycle: tricycle)).toList());

  FareLine _line(RouteLeg leg, int regular, {bool discountable = true}) => FareLine(
        mode: leg.mode,
        label: leg.routeLabel ?? leg.mode.label,
        regularCentavos: regular,
        discountedCentavos: discountable ? applyDiscount(regular) : regular,
        discountApplies: discountable,
      );
}

String pesos(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';
