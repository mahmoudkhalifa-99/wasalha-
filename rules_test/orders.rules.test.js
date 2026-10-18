// اختبارات قواعد الأوردرات. التشغيل (من مجلد rules_test، محتاج firebase-tools):
//   npm install && npm test
// ⚠️ مكتوبة بدون تشغيل — لو فشل اختبار، اتأكد هل الغلط في الاختبار ولا في القواعد.
const { test, before, after, beforeEach } = require('node:test');
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

let env;
const now = Date.now();
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'wasalha-rules-test',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
after(async () => env.cleanup());

const user = (role, extra = {}) => ({
  name: role, phone: '010', email: `${role}@x.com`, role, status: 'APPROVED',
  wallet: { balance: 0, totalEarnings: 0, withdrawn: 0 }, ...extra,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/cust').set(user('CUSTOMER'));
    await db.doc('users/other').set(user('CUSTOMER'));
    await db.doc('users/drv').set(user('DRIVER', { isOnline: true }));
    await db.doc('users/admin').set(user('ADMIN'));
    await db.doc('orders/o1').set({
      customerId: 'cust', category: 'FOOD', status: 'PENDING', price: 160, goodsTotal: 120,
      deliveryFare: 40, baseFare: 40, dropoff: { address: 'x' }, requestedVehicleType: 'TOKTOK',
      createdAt: now, updatedAt: now,
      statusHistory: [{ status: 'PENDING', changedAt: now, changedBy: 'cust' }],
    });
    await db.doc('offers/f1').set({ orderId: 'o1', driverId: 'drv', price: 45, createdAt: now });
  });
});

const hist = (st, by, prev) => [...prev, { status: st, changedAt: now, changedBy: by }];
const oldHist = [{ status: 'PENDING', changedAt: now, changedBy: 'cust' }];

test('عميل تاني ميقرأش الأوردر', async () => {
  await assertFails(env.authenticatedContext('other').firestore().doc('orders/o1').get());
});

test('العميل صاحب الأوردر يقرأه', async () => {
  await assertSucceeds(env.authenticatedContext('cust').firestore().doc('orders/o1').get());
});

test('قبول عرض صحيح: السعر = أجرة العرض + البضاعة', async () => {
  await assertSucceeds(env.authenticatedContext('cust').firestore().doc('orders/o1').update({
    status: 'ASSIGNED', driverId: 'drv', driverName: 'd', driverPhone: '011', acceptedAt: now,
    acceptedOfferId: 'f1', deliveryFare: 45, price: 165, updatedAt: now,
    statusHistory: hist('ASSIGNED', 'cust', oldHist),
  }));
});

test('قبول عرض بسعر بيمسح البضاعة يترفض', async () => {
  await assertFails(env.authenticatedContext('cust').firestore().doc('orders/o1').update({
    status: 'ASSIGNED', driverId: 'drv', acceptedAt: now, acceptedOfferId: 'f1',
    deliveryFare: 45, price: 45, updatedAt: now, statusHistory: hist('ASSIGNED', 'cust', oldHist),
  }));
});

test('الكابتن مينفعش يعدّل السعر مباشرة', async () => {
  await env.withSecurityRulesDisabled(async (c) => c.firestore().doc('orders/o1').update({ status: 'ASSIGNED', driverId: 'drv' }));
  await assertFails(env.authenticatedContext('drv').firestore().doc('orders/o1').update({ price: 900, updatedAt: now }));
});

test('الكابتن مينفعش يقفل "تم التسليم" قبل تأكيد العميل', async () => {
  await env.withSecurityRulesDisabled(async (c) => c.firestore().doc('orders/o1').update({ status: 'PICKED', driverId: 'drv' }));
  await assertFails(env.authenticatedContext('drv').firestore().doc('orders/o1').update({
    status: 'DELIVERED', deliveredAt: now, updatedAt: now, statusHistory: hist('DELIVERED', 'drv', oldHist),
  }));
});

test('عرض أعلى من 900 يترفض، و45 يتقبل', async () => {
  const d = env.authenticatedContext('drv').firestore();
  await assertFails(d.doc('offers/new').set({ orderId: 'o1', driverId: 'drv', price: 5000, createdAt: now }));
  await assertSucceeds(d.doc('offers/new2').set({ orderId: 'o1', driverId: 'drv', price: 45, createdAt: now, driverRating: 5 }));
});

test('مستخدم عادي ميبعتش إشعار لدور الأدمن', async () => {
  await assertFails(env.authenticatedContext('other').firestore().collection('notifications').add({
    userId: 'ADMIN', title: 't', body: 'b', type: 'ALERT', createdAt: now, senderId: 'other',
  }));
});

test('حساب مطعم يحدّث تحضير أوردر مطعمه بس، ومينفعش يغيّر السعر', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await c.firestore().doc('users/rest').set({ ...user('RESTAURANT'), restaurantId: 'r1' });
    await c.firestore().doc('orders/o1').update({ restaurantId: 'r1' });
  });
  const r = env.authenticatedContext('rest').firestore();
  await assertSucceeds(r.doc('orders/o1').update({ restaurantStatus: 'ACCEPTED', restaurantUpdatedAt: now, updatedAt: now }));
  await assertFails(r.doc('orders/o1').update({ price: 1, updatedAt: now }));
});

test('مطعم تاني مايقرأش أوردر مطعم غيره', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await c.firestore().doc('users/rest2').set({ ...user('RESTAURANT'), restaurantId: 'r2' });
    await c.firestore().doc('orders/o1').update({ restaurantId: 'r1' });
  });
  await assertFails(env.authenticatedContext('rest2').firestore().doc('orders/o1').get());
});

test('العناوين المحفوظة خاصة بصاحبها', async () => {
  const c = env.authenticatedContext('cust').firestore();
  await assertSucceeds(c.collection('saved_addresses').add({ userId: 'cust', label: 'البيت', placeName: 'x', createdAt: now }));
  await assertFails(env.authenticatedContext('other').firestore().collection('saved_addresses').where('userId', '==', 'cust').get());
});

test('تذكرة دعم: صاحبها يفتحها، والأدمن بس يقفلها', async () => {
  const c = env.authenticatedContext('cust').firestore();
  await assertSucceeds(c.collection('tickets').doc('t1').set({
    userId: 'cust', type: 'SUPPORT', message: 'عندي مشكلة', status: 'OPEN', createdAt: now }));
  await assertFails(c.doc('tickets/t1').update({ status: 'RESOLVED', updatedAt: now }));
  await assertSucceeds(env.authenticatedContext('admin').firestore().doc('tickets/t1').update({ status: 'RESOLVED', updatedAt: now }));
});
