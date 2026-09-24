/**
 * Cloud Function مطلوبة عشان الإشعارات تتحول لـ Push فعلي.
 *
 * التطبيق (Flutter) بيكتب مستند جديد في مجموعة "notifications" في Firestore
 * (مثلاً لما حد يبعت رسالة شات). الفانكشن دي بتستمع لأي إضافة جديدة في
 * المجموعة دي، وبتجيب توكنات FCM بتاعة المستخدم المستهدف من مستنده في
 * "users"، وبتبعتلهم Push فعلي عن طريق Firebase Admin SDK.
 *
 * ده الجزء اللي التطبيق نفسه (Flutter) مش يقدر يعمله - إرسال Push لجهاز
 * تاني لازم يحصل من سيرفر موثوق (Cloud Function هنا) وليس من جهاز العميل،
 * لأسباب أمنية.
 *
 * خطوات النشر:
 *   1) firebase init functions   (لو أول مرة، اختار Node.js وTypeScript أو JavaScript)
 *   2) انسخ الملف ده مكان functions/index.js
 *   3) firebase deploy --only functions
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

exports.sendPushOnNotificationCreate = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const data = event.data.data();
    if (!data || !data.userId) return;

    const userDoc = await db.collection('users').doc(data.userId).get();
    const tokens = userDoc.data()?.fcmTokens;
    if (!tokens || tokens.length === 0) return;

    const message = {
      notification: {
        title: data.title || 'وصلها',
        body: data.body || '',
      },
      data: {
        orderId: data.orderId || '',
        type: data.type || 'INFO',
      },
      tokens: tokens,
    };

    try {
      const response = await messaging.sendEachForMulticast(message);
      // تنظيف التوكنات الميتة (اللي فشل الإرسال ليها) عشان القائمة تفضل نضيفة
      const deadTokens = [];
      response.responses.forEach((r, i) => {
        if (!r.success) deadTokens.push(tokens[i]);
      });
      if (deadTokens.length > 0) {
        await db.collection('users').doc(data.userId).update({
          fcmTokens: tokens.filter((t) => !deadTokens.includes(t)),
        });
      }
    } catch (err) {
      console.error('فشل إرسال الإشعار:', err);
    }
  }
);
