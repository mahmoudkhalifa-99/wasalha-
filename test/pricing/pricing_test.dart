import 'package:flutter_test/flutter_test.dart';
import 'package:wasalha/config_constants.dart';
import 'package:wasalha/models/models.dart';
import 'package:wasalha/pricing.dart';

void main() {
  // (المحسوب, السعر النهائي للعميل, العمولة, مستحق الكابتن)
  const cases = <List<double>>[
    [15, 25, 5, 20],
    [20, 25, 5, 20],
    [25, 25, 5, 20],
    [27, 27, 5, 22],
    [50, 50, 10, 40],
    [100, 100, 20, 80],
  ];

  group('قواعد التسعير', () {
    for (final c in cases) {
      test('محسوب ${c[0].toInt()} ← نهائي ${c[1].toInt()} / صافي ${c[3].toInt()}',
          () {
        final fare = finalFare(c[0]);
        expect(fare, c[1]);
        expect(commissionFor(fare), c[2]);
        expect(driverEarnings(fare), c[3]);
      });
    }

    test('العمولة جنيه عن كل 5 جنيه كاملة، والحد الأدنى 25', () {
      expect(commissionFor(25), 5);
      expect(commissionFor(24.99), 4);
      expect(commissionFor(4), 0);
      expect(commissionFor(0), 0);
      expect(commissionFor(-10), 0);
      expect(commissionFor(15.000000000000002), 3);
      expect(minTripFare, 25);
      expect(configDefaultPricing.minPrice, minTripFare);
    });

    test('نفس الحد الأدنى لكل أنواع المركبات (مفيش مضاعف بيقلل عنه)', () {
      for (final m in configDefaultPricing.multipliers.values) {
        // أقل سعر محسوب مهما كان المضاعف بيترفع لـ 25
        expect(finalFare(1 * m), 25);
      }
    });
  });

  group('tripFareOf', () {
    test('طلب مطعم: الصافي بعد استبعاد تمن الأصناف', () {
      final o = Order.fromMap({
        'customerId': 'c',
        'price': 150.0,
        'foodItems': [
          {'id': 'a', 'name': 'x', 'price': 60.0, 'quantity': 2}
        ],
      }, 'o1');
      expect(tripFareOf(o), 30); // 150 - 120
    });
  });
}
