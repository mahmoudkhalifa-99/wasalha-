// قواعد تسعير المشوار — مصدر واحد للحساب في كل التطبيق.
//
//   Final Fare          = MAX(Calculated Fare, 25)
//   Platform Commission = 1 جنيه عن كل 5 جنيه من أجرة المشوار (بتتخصم من قيمة الرحلة)
//                         مثال: 25 ← 5، 50 ← 10، 100 ← 20
//   Driver Earnings     = Final Fare - Platform Commission
//
// الحد الأدنى 25 ج.م لكل أنواع المركبات. العمولة بتتحسب بالخمسات الكاملة بس
// (مثال: 27 ← 5 لأن فيها 5 خمسات كاملة).
// العميل بيشوف السعر النهائي بس، والكابتن بيشوف قيمة الرحلة ← العمولة ← الصافي.
import 'models/models.dart' show Order;

/// الحد الأدنى لسعر أي مشوار (جنيه) — لكل أنواع المركبات.
const double minTripFare = 25;

/// السعر النهائي للمشوار: لو المحسوب أقل من 25 يترفع لـ 25، غير كده يفضل زي ما هو.
double finalFare(double calculated) =>
    calculated < minTripFare ? minTripFare : calculated;

/// كل كام جنيه من الأجرة بيتحسب عليها جنيه عمولة.
const double commissionStepFare = 5;

/// العمولة اللي بتتحسب على كل خطوة كاملة من الأجرة (جنيه).
const double commissionPerStep = 1;

/// عمولة التطبيق على مشوار قيمته [fare]: جنيه عن كل 5 جنيه كاملة.
/// (25 ← 5، 50 ← 10، 27 ← 5، 4 ← 0). الأجرة الصفر أو السالبة = صفر.
double commissionFor(double fare) {
  if (fare.isNaN || fare <= 0) return 0;
  // +1e-9 عشان أخطاء الفاصلة العائمة (مثال 15.000000000000002 / 5)
  final steps = ((fare / commissionStepFare) + 1e-9).floor();
  return steps * commissionPerStep;
}

/// صافي مستحق الكابتن = السعر النهائي − العمولة.
double driverEarnings(double fare) => fare - commissionFor(fare);

/// قيمة المشوار نفسه من الطلب: في طلبات المطاعم الـ price بيشمل تمن الأصناف
/// (اللي الكابتن بيدفعه للمطعم)، فنشيله ونسيب رسوم التوصيل/المشوار بس.
double tripFareOf(Order o) {
  final items = o.foodItems;
  if (items == null || items.isEmpty) return o.price;
  final itemsTotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
  final trip = o.price - itemsTotal;
  return trip > 0 ? trip : o.price;
}
