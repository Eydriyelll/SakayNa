import 'package:flutter_test/flutter_test.dart';
import 'package:parapo_transpo/core/constants/fare_rates.dart';
import 'package:parapo_transpo/core/services/fare_engine.dart';

void main() {
  const engine = FareEngine();

  test('traditional PUJ: base covers first 4 km', () {
    expect(engine.distanceFare(FareRates.pujTraditional, 1), 1400);
    expect(engine.distanceFare(FareRates.pujTraditional, 4), 1400);
  });

  test('traditional PUJ: started km is charged in full', () {
    expect(engine.distanceFare(FareRates.pujTraditional, 4.1), 1600);
    expect(engine.distanceFare(FareRates.pujTraditional, 10), 2600);
  });

  test('modern PUJ 10 km = 17 + 6 x 2.40', () {
    expect(engine.distanceFare(FareRates.pujModern, 10), 3140);
  });

  test('20% discount rounds to nearest 0.25', () {
    expect(engine.applyDiscount(2600), 2075); // 20.80 -> 20.75
    expect(engine.applyDiscount(3140), 2500); // 25.12 -> 25.00
    expect(engine.applyDiscount(1400), 1125); // 11.20 -> 11.25
  });
}
