/**
 * Relay لإرسال إشعارات FCM بدون Cloud Functions / Blaze.
 * التطبيق بيبعت: { idToken, userId, title, body, key, orderId }
 *  - idToken: توكن Firebase للمستخدم الحالي (للتأكد إنه مستخدم حقيقي في المشروع).
 *  - userId: معرّف مستخدم، أو دور كامل (DRIVER = الكباتن الأونلاين بس).
 *
 * Script Properties المطلوبة:
 *   SERVICE_ACCOUNT_JSON : محتوى ملف الـ service account كامل (Firebase Admin SDK)
 *   WEB_API_KEY          : (اختياري) الـ API key بتاع Firebase، الافتراضي تحت
 */
const PROJECT_ID = 'sada-51292';
const DEFAULT_API_KEY = 'AIzaSyDlfpN0JCsmpCKdTyb4ZX_QN0sZbypIv48';
const ROLES = ['DRIVER', 'CUSTOMER', 'ADMIN', 'OPERATOR'];

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    if (!verifyIdToken_(body.idToken)) return out_({ ok: false, error: 'unauthorized' });

    const tokens = tokensFor_(String(body.userId || ''));
    if (!tokens.length) return out_({ ok: true, sent: 0 });

    const access = getAccessToken_();
    const url = 'https://fcm.googleapis.com/v1/projects/' + PROJECT_ID + '/messages:send';
    const reqs = tokens.map(function (t) {
      return {
        url: url,
        method: 'post',
        contentType: 'application/json',
        headers: { Authorization: 'Bearer ' + access },
        muteHttpExceptions: true,
        payload: JSON.stringify({
          message: {
            token: t,
            data: {
              title: String(body.title || 'وصلها'),
              body: String(body.body || ''),
              key: String(body.key || ''),
              orderId: String(body.orderId || ''),
            },
            android: { priority: 'HIGH' },
          },
        }),
      };
    });
    const res = UrlFetchApp.fetchAll(reqs);
    const ok = res.filter(function (r) { return r.getResponseCode() === 200; }).length;
    return out_({ ok: true, sent: ok, total: tokens.length });
  } catch (err) {
    return out_({ ok: false, error: String(err) });
  }
}

function out_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

function verifyIdToken_(idToken) {
  if (!idToken) return false;
  const key = PropertiesService.getScriptProperties().getProperty('WEB_API_KEY') || DEFAULT_API_KEY;
  const res = UrlFetchApp.fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + key,
    { method: 'post', contentType: 'application/json', payload: JSON.stringify({ idToken: idToken }), muteHttpExceptions: true }
  );
  if (res.getResponseCode() !== 200) return false;
  const j = JSON.parse(res.getContentText());
  return !!(j.users && j.users.length);
}

function tokensFor_(userId) {
  const access = getAccessToken_();
  const base = 'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID + '/databases/(default)/documents';
  const headers = { Authorization: 'Bearer ' + access };

  if (ROLES.indexOf(userId) >= 0) {
    const filters = [fieldEq_('role', { stringValue: userId })];
    if (userId === 'DRIVER') filters.push(fieldEq_('isOnline', { booleanValue: true }));
    const res = UrlFetchApp.fetch(base + ':runQuery', {
      method: 'post', contentType: 'application/json', headers: headers, muteHttpExceptions: true,
      payload: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'users' }],
          where: { compositeFilter: { op: 'AND', filters: filters } },
          limit: 300,
        },
      }),
    });
    if (res.getResponseCode() !== 200) return [];
    return JSON.parse(res.getContentText())
      .map(function (r) { return r.document && r.document.fields && r.document.fields.fcmToken && r.document.fields.fcmToken.stringValue; })
      .filter(Boolean);
  }

  if (!userId || userId === 'ALL') return [];
  const res = UrlFetchApp.fetch(base + '/users/' + encodeURIComponent(userId), { headers: headers, muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) return [];
  const f = JSON.parse(res.getContentText()).fields || {};
  return f.fcmToken && f.fcmToken.stringValue ? [f.fcmToken.stringValue] : [];
}

function fieldEq_(path, value) {
  return { fieldFilter: { field: { fieldPath: path }, op: 'EQUAL', value: value } };
}

function getAccessToken_() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('access_token');
  if (cached) return cached;

  const sa = JSON.parse(PropertiesService.getScriptProperties().getProperty('SERVICE_ACCOUNT_JSON'));
  const now = Math.floor(Date.now() / 1000);
  const enc = function (o) { return Utilities.base64EncodeWebSafe(JSON.stringify(o)).replace(/=+$/, ''); };
  const unsigned = enc({ alg: 'RS256', typ: 'JWT' }) + '.' + enc({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const sig = Utilities.base64EncodeWebSafe(Utilities.computeRsaSha256Signature(unsigned, sa.private_key)).replace(/=+$/, '');
  const res = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    payload: { grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: unsigned + '.' + sig },
  });
  const token = JSON.parse(res.getContentText()).access_token;
  cache.put('access_token', token, 3000);
  return token;
}
