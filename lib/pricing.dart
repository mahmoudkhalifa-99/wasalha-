// قواعد تسعير المشوار — مصدر واحد للحساب في كل التطبيق.
//
//   سعر التوصيل/المشوار  = حسب المسافة الفعلية على الطريق (حد أدنى 25)
//   إجمالي الأوردر       = سعر التوصيل + تمن الطلبات (أكل/أدوية) لو فيه
//   عمولة المنصة         = 16% من إجمالي الأوردر
//   صافي الكابتن         = إجمالي الأوردر − تمن الطلبات − العمولة
//
// العميل بيشوف إجمالي الأوردر بس، والكابتن بيشوف الإجمالي ← العمولة ← الصافي.
import 'config_constants.dart'
    show platformCommissionRate, ConfigPricing, configDefaultPricing, activePricing, activeCommissionRate;
import 'models/models.dart' show Order, VehicleType;

/// الحد الأدنى لسعر أي مشوار (جنيه) — لكل أنواع المركبات.
const double minTripFare = 25;

/// true  → العمولة 16% من إجمالي الأوردر كامل (شامل تمن الأكل/الأدوية).
/// false → العمولة 16% من أجرة التوصيل بس (من غير تمن الطلبات).
const bool commissionOnFullOrderTotal = true;

/// السعر النهائي للمشوار: لو المحسوب أقل من 25 يترفع لـ 25، غير كده يفضل زي ما هو.
double finalFare(double calculated) =>
    calculated < minTripFare ? minTripFare : calculated;

double _round2(double v) => (v * 100).round() / 100;

/// سعر مشوار حسب المسافة الفعلية على الطريق ونوع المركبة:
/// (السعر الأساسي + كم × سعر الكيلو) × مضاعف المركبة، بعدين الحد الأدنى 25
/// والحد الأقصى (maxPrice)، مقرّب لأقرب جنيه.
double calculateTripFare(double roadKm, VehicleType vehicle,
    {ConfigPricing? cfgOverride}) {
  final cfg = cfgOverride ?? activePricing;
  final km = (roadKm.isNaN || roadKm < 0) ? 0.0 : roadKm;
  final multiplier = cfg.multipliers[vehicle] ?? 1.0;
  final fare = finalFare((cfg.basePrice + km * cfg.pricePerKm) * multiplier)
      .roundToDouble();
  return fare > cfg.maxPrice ? cfg.maxPrice : fare;
}

/// أجرة توصيل المطاعم والصيدلية حسب المسافة الفعلية على الطريق:
/// السعر الأساسي + كم × سعر كيلو التوصيل، والحد الأدنى 25، مقرّب لأقرب جنيه.
/// (مفيش مبلغ ثابت: كل ما المسافة تزيد الأجرة بتزيد.)
double calculateDeliveryFare(double roadKm, {ConfigPricing? cfgOverride}) {
  final cfg = cfgOverride ?? activePricing;
  final km = (roadKm.isNaN || roadKm < 0) ? 0.0 : roadKm;
  final fare = finalFare(cfg.basePrice + km * cfg.foodOutsidePricePerKm)
      .roundToDouble();
  return fare > cfg.maxPrice ? cfg.maxPrice : fare;
}

/// إجمالي الأوردر = أجرة التوصيل + تمن الطلبات (أكل/أدوية).
double orderTotal(double deliveryFare, double goodsTotal) =>
    deliveryFare + (goodsTotal < 0 ? 0 : goodsTotal);

/// عمولة التطبيق على أساس [base] (16%)، مقرّبة لأقرب قرش.
double commissionOnBase(double base) =>
    base <= 0 ? 0 : _round2(base * activeCommissionRate);

/// تمن الطلبات اللي الكابتن بيدفعها (مش جزء من أجرته): أصناف المطعم، أو تمن
/// الأدوية/المطعم اليدوي لو العميل كتبه.
double goodsTotalOf(Order o) {
  // الطلبات الجديدة: القيمة المخزّنة وقت الإنشاء هي المرجع (مبتتغيّرش بقبول عرض).
  final stored = o.goodsTotal;
  if (stored != null) return stored < 0 ? 0 : stored;
  final items = o.foodItems;
  if (items != null && items.isNotEmpty) {
    final total = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
    return total > o.price ? 0 : total;
  }
  final g = o.goodsCost ?? 0;
  return (g <= 0 || g > o.price) ? 0 : g;
}

/// قيمة المشوار نفسه (أجرة التوصيل) من الطلب: السعر الكلي − تمن الطلبات.
double tripFareOf(Order o) {
  final stored = o.deliveryFare;
  if (stored != null && stored > 0) return stored;
  final trip = o.price - goodsTotalOf(o);
  return trip > 0 ? trip : o.price;
}

/// الأساس اللي بتتحسب عليه عمولة الطلب ده.
double commissionBaseOf(Order o) =>
    commissionOnFullOrderTotal ? o.price : tripFareOf(o);

/// عمولة التطبيق على الطلب (16%).
double platformCommissionOf(Order o) => commissionOnBase(commissionBaseOf(o));

/// صافي الكابتن من الطلب = الإجمالي − تمن الطلبات − العمولة.
double driverEarningsOf(Order o) =>
    _round2(o.price - goodsTotalOf(o) - platformCommissionOf(o));

/// نفس الحساب بالأرقام (لعرض عرض السعر قبل ما يبقى فيه Order): [total] إجمالي
/// الأوردر، [goods] تمن الطلبات.
double commissionFor(double total, {double goods = 0}) =>
    commissionOnBase(commissionOnFullOrderTotal ? total : total - goods);

double driverEarningsFor(double total, {double goods = 0}) =>
    _round2(total - goods - commissionFor(total, goods: goods));
