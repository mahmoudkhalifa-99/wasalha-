const test = require('node:test');
const assert = require('node:assert');
const { computeSettlement } = require('./settlement');

test('مشوار عادي: عمولة 16% وصافي', () => {
  const r = computeSettlement({ price: 100 });
  assert.deepStrictEqual([r.commission, r.earnings, r.goods], [16, 84, 0]);
});

test('طلب أكل: تمن البضاعة المخزّن مش بيتمسح', () => {
  const r = computeSettlement({ price: 160, goodsTotal: 120 });
  assert.deepStrictEqual([r.commission, r.earnings, r.goods], [25.6, 14.4, 120]);
});

test('طلب قديم من غير goodsTotal بيتحسب من الأصناف', () => {
  const r = computeSettlement({ price: 150, foodItems: [{ price: 40, quantity: 3 }] });
  assert.strictEqual(r.goods, 120);
  assert.strictEqual(r.commission, 24);
  assert.strictEqual(r.earnings, 6);
});

test('نسبة عمولة مخصصة للكابتن', () => {
  const r = computeSettlement({ price: 100 }, 10);
  assert.deepStrictEqual([r.commission, r.earnings], [10, 90]);
});

test('نسبة غير صالحة ترجع للافتراضي', () => {
  assert.strictEqual(computeSettlement({ price: 100 }, 500).commission, 16);
});
