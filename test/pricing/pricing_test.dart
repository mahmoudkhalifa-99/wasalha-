import 'package:flutter_test/flutter_test.dart';
import 'package:wasalha/config_constants.dart';
import 'package:wasalha/models/models.dart';
import 'package:wasalha/pricing.dart';

Order _order(Map<String, dynamic> extra, {double price = 100}) =>
    Order.fromMap({'customerId': 'c', 'price': price, ...extra}, 'o1');

void main() {
  group('الحد الأدنى', () {
    test('المحسوب الأقل من 25 بيترفع لـ 25', () {
      expect(finalFare(15), 25);
      expect(finalFare(25), 25);
      expect(finalFare(50), 50);
    });

    test('نفس الحد الأدنى لكل أنواع المركبات', () {
      expect(minTripFare, 25);
      expect(configDefaultPricing.minPrice, minTripFare);
      for (final m in configDefaultPricing.multipliers.values) {
        expect(finalFare(1 * m), 25);
      }
    });
  });

  group('عمولة 16% من إجمالي الأوردر', () {
    test('النسبة 16%', () {
      expect(platformCommissionRate, 0.16);
      expect(platformCommissionPercent, 16);
    });

    test('commissionFor: 16% من الإجمالي', () {
      expect(commissionFor(100), 16);
      expect(commissionFor(50), 8);
      expect(commissionFor(25), 4);
      expect(commissionFor(0), 0);
    });

    test('صافي الكابتن = الإجمالي − العمولة (من غير بضاعة)', () {
      expect(driverEarningsFor(100), 84);
      expect(driverEarningsFor(25), 21);
    });

    test('مع بضاعة: العمولة على الإجمالي الكامل، والصافي بعد تمن البضاعة', () {
      // 150 = 30 توصيل + 120 أكل → عمولة 24، صافي 150 − 120 − 24 = 6
      expect(commissionFor(150, goods: 120), 24);
      expect(driverEarningsFor(150, goods: 120), 6);
    });

    test('طلب مطعم: العمولة 16% من إجمالي الأوردر (أصناف + توصيل)', () {
      final o = _order({
        'foodItems': [
          {'id': 'a', 'name': 'x', 'price': 60.0, 'quantity': 2}
        ],
      }, price: 150);
      expect(platformCommissionOf(o), 24);
      expect(driverEarningsOf(o), 6);
    });

    test('طلب صيدلية: تمن الأدوية goodsCost جزء من الإجمالي', () {
      final o = _order({'goodsCost': 80.0}, price: 110);
      expect(goodsTotalOf(o), 80);
      expect(tripFareOf(o), 30);
      expect(platformCommissionOf(o), 17.6);
      expect(driverEarningsOf(o), 12.4);
    });

    test('مشوار عادي من غير بضاعة', () {
      final o = _order({}, price: 100);
      expect(goodsTotalOf(o), 0);
      expect(platformCommissionOf(o), 16);
      expect(driverEarningsOf(o), 84);
    });
  });

  group('calculateTripFare', () {
    test('صفر كم = الحد الأدنى 25', () {
      expect(calculateTripFare(0, VehicleType.motorcycle), 25);
      expect(calculateTripFare(0, VehicleType.toktok), 25);
    });

    test('توكتوك: (5 + كم × 4)', () {
      expect(calculateTripFare(10, VehicleType.toktok), 45);
    });

    test('موتوسيكل 0.85 / عربية 2.2 (مقرّب لأقرب جنيه)', () {
      expect(calculateTripFare(10, VehicleType.motorcycle), 38); // 38.25
      expect(calculateTripFare(10, VehicleType.car), 99);
    });

    test('الحد الأقصى 900، ومسافة سالبة/NaN = الحد الأدنى', () {
      expect(calculateTripFare(500, VehicleType.car), 900);
      expect(calculateTripFare(-3, VehicleType.toktok), 25);
      expect(calculateTripFare(double.nan, VehicleType.toktok), 25);
    });
  });

  group('calculateDeliveryFare (مطعم/صيدلية حسب المسافة)', () {
    test('قريب جدًا = الحد الأدنى 25', () {
      expect(calculateDeliveryFare(0), 25);
      expect(calculateDeliveryFare(2), 25);
    });

    test('السعر بيزيد مع المسافة: 5 + كم × 3', () {
      expect(calculateDeliveryFare(10), 35);
      expect(calculateDeliveryFare(20), 65);
      expect(calculateDeliveryFare(20), greaterThan(calculateDeliveryFare(10)));
    });

    test('مسافة سالبة/NaN = الحد الأدنى', () {
      expect(calculateDeliveryFare(-1), 25);
      expect(calculateDeliveryFare(double.nan), 25);
    });

    test('إجمالي الأوردر = أجرة التوصيل + تمن الطلبات', () {
      expect(orderTotal(calculateDeliveryFare(10), 120), 155);
      expect(orderTotal(25, -5), 25);
    });
  });

  group('tripFareOf', () {
    test('طلب مطعم: الصافي بعد استبعاد تمن الأصناف', () {
      final o = _order({
        'foodItems': [
          {'id': 'a', 'name': 'x', 'price': 60.0, 'quantity': 2}
        ],
      }, price: 150);
      expect(tripFareOf(o), 30); // 150 - 120
    });
  });

  group('قبول عرض: الأجرة بس، وتمن البضاعة محفوظ', () {
    test('goodsTotal المخزّن هو المرجع حتى لو السعر اتغيّر', () {
      final o = _order({'goodsTotal': 120.0, 'deliveryFare': 40.0}, price: 160);
      expect(goodsTotalOf(o), 120);
      expect(tripFareOf(o), 40);
      // العمولة 16% من الإجمالي 160 = 25.6، الصافي 160 − 120 − 25.6 = 14.4
      expect(platformCommissionOf(o), 25.6);
      expect(driverEarningsOf(o), 14.4);
    });

    test('طلب قديم من غير goodsTotal بيتحسب من goodsCost زي الأول', () {
      final o = _order({'goodsCost': 120.0}, price: 160);
      expect(goodsTotalOf(o), 120);
      expect(tripFareOf(o), 40);
    });
  });

  group('التسعير من الإعدادات (config/pricing)', () {
    tearDown(() => applyPricingConfig(null));

    test('قيم صالحة بتتطبّق على الأجرة والعمولة', () {
      applyPricingConfig({'basePrice': 10, 'pricePerKm': 5, 'commissionPercent': 10});
      // (10 + 4×5) × 1.0 = 30
      expect(calculateTripFare(4, VehicleType.toktok), 30);
      expect(commissionOnBase(100), 10);
    });

    test('قيم برّه الحدود الآمنة بتتتجاهل وترجع للافتراضي', () {
      applyPricingConfig({'maxPrice': 5000, 'commissionPercent': 90});
      expect(activePricing.maxPrice, 900);
      expect(commissionOnBase(100), 16);
    });

    test('null يرجّع الافتراضي', () {
      applyPricingConfig({'basePrice': 50});
      applyPricingConfig(null);
      expect(activePricing.basePrice, configDefaultPricing.basePrice);
    });
  });
}
