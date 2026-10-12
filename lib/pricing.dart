// قواعد تسعير المشوار — مصدر واحد للحساب في كل التطبيق.
//
//   Final Fare          = MAX(Calculated Fare, 25)
//   Platform Commission = 5            (ثابتة، بتتخصم من قيمة الرحلة)
//   Driver Earnings     = Final Fare - 5
//
// الحد الأدنى 25 ج.م لكل أنواع المركبات، والعمولة 5 ج.م ثابتة (مش نسبة).
// العميل بيشوف السعر النهائي بس، والكابتن بيشوف قيمة الرحلة ← العمولة ← الصافي.
import 'config_constants.dart'
    show platformFeePerTrip, ConfigPricing, configDefaultPricing;
import 'models/models.dart' show Order, VehicleType;

/// الحد الأدنى لسعر أي مشوار (جنيه) — لكل أنواع المركبات.
const double minTripFare = 25;

/// السعر النهائي للمشوار: لو المحسوب أقل من 25 يترفع لـ 25، غير كده يفضل زي ما هو.
double finalFare(double calculated) =>
    calculated < minTripFare ? minTripFare : calculated;

/// سعر مشوار حسب المسافة الفعلية على الطريق ونوع المركبة:
/// (السعر الأساسي + كم × سعر الكيلو) × مضاعف المركبة، بعدين الحد الأدنى 25
/// والحد الأقصى (maxPrice)، مقرّب لأقرب جنيه.
double calculateTripFare(double roadKm, VehicleType vehicle,
    {ConfigPricing cfg = configDefaultPricing}) {
  final km = (roadKm.isNaN || roadKm < 0) ? 0.0 : roadKm;
  final multiplier = cfg.multipliers[vehicle] ?? 1.0;
  final fare = finalFare((cfg.basePrice + km * cfg.pricePerKm) * multiplier)
      .roundToDouble();
  return fare > cfg.maxPrice ? cfg.maxPrice : fare;
}

/// عمولة التطبيق الثابتة على المشوار المكتمل (بتتخصم من قيمة الرحلة).
double get platformCommission => platformFeePerTrip;

/// صافي مستحق الكابتن = السعر النهائي − العمولة.
double driverEarnings(double fare) => fare - platformCommission;

/// قيمة المشوار نفسه من الطلب: في طلبات المطاعم الـ price بيشمل تمن الأصناف
/// (اللي الكابتن بيدفعه للمطعم)، فنشيله ونسيب رسوم التوصيل/المشوار بس.
double tripFareOf(Order o) {
  final items = o.foodItems;
  if (items == null || items.isEmpty) return o.price;
  final itemsTotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
  final trip = o.price - itemsTotal;
  return trip > 0 ? trip : o.price;
}
