// دوال الأوردرات (بتشتغل بصلاحيات الـ Admin SDK، العميل ما يقدرش يكتب نفس الحاجات):
//  1) settleDeliveredOrder : أول ما الأوردر يبقى DELIVERED يكتب سجل المعاملات وأرقام محفظة الكابتن
//                            (مرة واحدة بس، idempotent بمعرّف ثابت).
//  2) updateDriverRating   : يحسب تقييم الكابتن ومتوسطه من تقييمات الأوردرات.
//  3) expireStalePendingOrders : يلغي الأوردرات المنتظرة القديمة وينضّف عروضها.
const { onDocumentUpdated, onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { computeSettlement, round2 } = require('./settlement');

const db = () => admin.firestore();
const PENDING_TTL_MS = 60 * 60 * 1000; // ساعة من غير كابتن = ينتهي
const STALE_OFFER_MS = 24 * 60 * 60 * 1000;

exports.settleDeliveredOrder = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (after.status !== 'DELIVERED' || before.status === 'DELIVERED') return;
  const driverId = after.driverId || after.assignedTo;
  if (!driverId) {
    console.warn('delivered order without driver', event.params.orderId);
    return;
  }

  const orderId = event.params.orderId;
  const userRef = db().collection('users').doc(driverId);
  const earnRef = db().collection('transactions').doc(`earning_${orderId}`);
  const commRef = db().collection('transactions').doc(`commission_${orderId}`);

  await db().runTransaction(async (tx) => {
    const [earnSnap, userSnap] = await Promise.all([tx.get(earnRef), tx.get(userRef)]);
    if (earnSnap.exists) return; // اتسوّى قبل كده
    const cfgSnap = await tx.get(db().collection('config').doc('pricing'));
    const globalPct = cfgSnap.exists ? cfgSnap.get('commissionPercent') : undefined;
    // نسبة الكابتن الخاصة لها الأولوية، وبعدها النسبة العامة من config/pricing، وبعدها 16%
    const own = userSnap.exists ? userSnap.get('commissionPercent') : undefined;
    const pct = typeof own === 'number' ? own : globalPct;
    const s = computeSettlement(after, typeof pct === 'number' ? pct : undefined);
    const now = Date.now();
    const common = { userId: driverId, orderId, createdAt: now, orderPrice: s.price, goods: s.goods };

    tx.set(earnRef, {
      ...common, type: 'CREDIT', kind: 'EARNING', amount: s.earnings,
      description: `صافي أرباح أوردر (بعد عمولة ${s.commissionPercent}%)`,
    });
    tx.set(commRef, {
      ...common, type: 'DEBIT', kind: 'COMMISSION', amount: s.commission,
      description: `عمولة التطبيق ${s.commissionPercent}% مستحقة على الأوردر`,
    });
    tx.set(userRef, {
      wallet: {
        totalEarnings: admin.firestore.FieldValue.increment(s.earnings),
        commissionDue: admin.firestore.FieldValue.increment(s.commission),
      },
    }, { merge: true });
    tx.update(event.data.after.ref, { settledAt: now, driverEarnings: s.earnings, platformCommission: s.commission });
  });
});

exports.updateDriverRating = onDocumentCreated('reviews/{orderId}', async (event) => {
  const r = event.data && event.data.data();
  if (!r || !r.driverId || !Number.isInteger(r.rating)) return;
  const ref = db().collection('users').doc(r.driverId);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const count = (snap.get('ratingCount') || 0) + 1;
    const sum = (snap.get('ratingSum') || 0) + r.rating;
    tx.update(ref, { ratingCount: count, ratingSum: sum, rating: round2(sum / count) });
  });
});

async function expireStale(now) {
  const cutoff = now - PENDING_TTL_MS;
  const snap = await db().collection('orders')
    .where('status', '==', 'PENDING').where('createdAt', '<', cutoff).limit(200).get();
  let n = 0;
  for (const d of snap.docs) {
    await d.ref.update({
      status: 'CANCELLED', cancelledAt: now, cancelledBy: 'SYSTEM', cancelReason: 'انتهت مهلة انتظار الكباتن',
      updatedAt: now,
      statusHistory: admin.firestore.FieldValue.arrayUnion({ status: 'CANCELLED', changedAt: now, changedBy: 'SYSTEM' }),
    });
    n++;
  }
  // عروض قديمة على أوردرات خلصت/اتاخدت
  const offers = await db().collection('offers').where('createdAt', '<', now - STALE_OFFER_MS).limit(300).get();
  let m = 0;
  for (const o of offers.docs) {
    const ord = await db().collection('orders').doc(o.get('orderId')).get();
    if (!ord.exists || ord.get('status') !== 'PENDING') { await o.ref.delete(); m++; }
  }
  return { expiredOrders: n, deletedOffers: m };
}

exports.expireStalePendingOrders = onSchedule({ schedule: 'every 10 minutes', timeZone: 'Africa/Cairo' }, async () => {
  console.log('stale sweep', await expireStale(Date.now()));
});

// كابتن واحد = مشوار واحد في نفس الوقت. لو عميل قبل عرض كابتن عنده مشوار شغال، بنرجّع
// الأوردر الجديد PENDING (بسعره الأصلي) وبنبلّغ العميل، بدل ما يتعلّق من غير ما حد يشوفه.
const ACTIVE = ['ASSIGNED', 'PICKED', 'IN_DELIVERY'];
exports.guardDoubleAssignment = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (!(before.status === 'PENDING' && after.status === 'ASSIGNED') || !after.driverId) return;
  const others = await db().collection('orders')
    .where('driverId', '==', after.driverId).where('status', 'in', ACTIVE).get();
  if (others.docs.every((d) => d.id === event.params.orderId)) return;

  const now = Date.now();
  const FV = admin.firestore.FieldValue;
  const base = typeof after.baseFare === 'number' ? after.baseFare : after.deliveryFare;
  const goods = typeof after.goodsTotal === 'number' ? after.goodsTotal : 0;
  await event.data.after.ref.update({
    status: 'PENDING', updatedAt: now,
    driverId: FV.delete(), driverName: FV.delete(), driverPhone: FV.delete(), driverPhoto: FV.delete(),
    acceptedAt: FV.delete(), acceptedOfferId: FV.delete(), assignedTo: FV.delete(),
    ...(typeof base === 'number' ? { deliveryFare: base, price: base + goods } : {}),
    statusHistory: FV.arrayUnion({ status: 'PENDING', changedAt: now, changedBy: 'SYSTEM' }),
  });
  await db().collection('notifications').add({
    userId: after.customerId, title: 'الكابتن مشغول بمشوار تاني',
    body: 'اختار عرض كابتن تاني من فضلك.', type: 'ALERT', key: `busy_${event.params.orderId}`,
    orderId: event.params.orderId, createdAt: now, read: false, senderId: 'SYSTEM',
  });
});

// حذف حساب (من المستخدم نفسه أو من الأدمن): نكمّل التنضيف من السيرفر.
//  - حساب Auth نفسه (حذف الأدمن لوثيقة المستخدم مكانش بيمسحه)
//  - الموقع، الإشعارات، رسايل الشات
//  - الأوردرات بتفضل (سجل مالي) لكن بدون بيانات شخصية: تليفون وروشتة وملاحظات
//  - مستندات توثيق الكابتن بتفضل لحد سياسة احتفاظ قانونية (متعمّد، شوف القواعد)
exports.cleanupDeletedUser = onDocumentDeleted('users/{uid}', async (event) => {
  const uid = event.params.uid;
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') console.warn('auth delete failed', uid, e.code);
  }
  await db().collection('driver_locations').doc(uid).delete().catch(() => {});

  const delAll = async (q) => {
    for (;;) {
      const snap = await q.limit(400).get();
      if (snap.empty) return;
      const b = db().batch();
      snap.docs.forEach((d) => b.delete(d.ref));
      await b.commit();
    }
  };
  await delAll(db().collection('notifications').where('userId', '==', uid));
  await delAll(db().collection('messages').where('senderId', '==', uid));

  const FV = admin.firestore.FieldValue;
  const orders = await db().collection('orders').where('customerId', '==', uid).limit(500).get();
  const b = db().batch();
  orders.docs.forEach((d) => b.update(d.ref, {
    customerPhone: FV.delete(), prescriptionImage: FV.delete(), pickupNotes: FV.delete(),
    dropoffNotes: FV.delete(), specialRequest: FV.delete(), anonymized: true,
  }));
  await b.commit();
});
