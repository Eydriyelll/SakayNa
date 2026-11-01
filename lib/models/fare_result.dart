import 'transit_mode.dart';

class FareLine {
  const FareLine({
    required this.mode,
    required this.label,
    required this.regularCentavos,
    required this.discountedCentavos,
    this.discountApplies = true,
  });
  final TransitMode mode;
  final String label;
  final int regularCentavos;
  final int discountedCentavos;

  /// Some tricycle "special" trips are not discountable per local rules.
  final bool discountApplies;
}

class FareBreakdown {
  const FareBreakdown(this.lines);
  final List<FareLine> lines;

  int get regularTotal => lines.fold(0, (s, l) => s + l.regularCentavos);
  int get discountedTotal => lines.fold(0, (s, l) => s + l.discountedCentavos);
  int get savings => regularTotal - discountedTotal;
}
