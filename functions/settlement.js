// منطق حساب العمولة وصافي الكابتن (نسخة JS من lib/pricing.dart — لازم يفضلوا متطابقين).
// ملف نقي من غير firebase عشان يتختبر لوحده.
const DEFAULT_COMMISSION_PERCENT = 16;
// true = العمولة على إجمالي الأوردر كامل (زي commissionOnFullOrderTotal في pricing.dart)
const COMMISSION_ON_FULL_TOTAL = true;

const round2 = (v) => Math.round(v * 100) / 100;

function goodsTotalOf(order) {
  const price = Number(order.price) || 0;
  if (typeof order.goodsTotal === 'number') return Math.max(0, order.goodsTotal);
  const items = Array.isArray(order.foodItems) ? order.foodItems : [];
  if (items.length) {
    const total = items.reduce((s, i) => s + (Number(i.price) || 0) * (Number(i.quantity) || 0), 0);
    return total > price ? 0 : total;
  }
  const g = Number(order.goodsCost) || 0;
  return g <= 0 || g > price ? 0 : g;
}

function computeSettlement(order, commissionPercent) {
  const price = Number(order.price) || 0;
  const goods = goodsTotalOf(order);
  const pct = typeof commissionPercent === 'number' && commissionPercent >= 0 && commissionPercent <= 100
    ? commissionPercent
    : DEFAULT_COMMISSION_PERCENT;
  const deliveryFare = price - goods > 0 ? price - goods : price;
  const base = COMMISSION_ON_FULL_TOTAL ? price : deliveryFare;
  const commission = base <= 0 ? 0 : round2((base * pct) / 100);
  const earnings = round2(price - goods - commission);
  return { price, goods, commission, earnings, commissionPercent: pct };
}

module.exports = { computeSettlement, goodsTotalOf, round2, DEFAULT_COMMISSION_PERCENT };
