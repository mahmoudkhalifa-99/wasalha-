#!/usr/bin/env node
// ترحيل الصور القديمة من base64 (جوه مستندات Firestore) إلى Firebase Storage.
// بيغطي: users.photoURL ، ads.imageUrl ، restaurants.photoURL و menuImageURL.
//
// الاستخدام (من مجلد functions، بعد npm install وتسجيل الدخول بحساب فيه صلاحية):
//   GOOGLE_APPLICATION_CREDENTIALS=key.json GCLOUD_PROJECT=<project> \
//   STORAGE_BUCKET=<project>.firebasestorage.app node scripts/migrate_images.js          # تجربة (مفيش كتابة)
//   ... node scripts/migrate_images.js --apply                                            # تنفيذ فعلي
//
// آمن للتكرار: بيعدّي بس على القيم اللي بتبدأ بـ data:image. بعد الرفع بيكتب الرابط مكان
// الـ base64 (ومبيمسحش حاجة لو الرفع فشل). خد نسخة احتياطية (Firestore export) قبل --apply.
const admin = require('firebase-admin');
const crypto = require('crypto');

const APPLY = process.argv.includes('--apply');
admin.initializeApp({ storageBucket: process.env.STORAGE_BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const TARGETS = [
  { coll: 'users', field: 'photoURL', folder: (id) => `profiles/${id}` },
  { coll: 'ads', field: 'imageUrl', folder: () => 'ads' },
  { coll: 'restaurants', field: 'photoURL', folder: () => 'restaurants' },
  { coll: 'restaurants', field: 'menuImageURL', folder: () => 'restaurants' },
];

function decode(dataUrl) {
  const m = /^data:(image\/(?:jpeg|png|webp));base64,(.+)$/s.exec(dataUrl);
  if (!m) return null;
  return { mime: m[1], bytes: Buffer.from(m[2].replace(/\s/g, ''), 'base64') };
}

async function upload(path, img) {
  const token = crypto.randomUUID();
  const file = bucket.file(path);
  await file.save(img.bytes, {
    contentType: img.mime,
    metadata: { metadata: { firebaseStorageDownloadTokens: token } },
  });
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

(async () => {
  let found = 0, migrated = 0, failed = 0;
  for (const t of TARGETS) {
    const snap = await db.collection(t.coll).get();
    for (const doc of snap.docs) {
      const v = doc.get(t.field);
      if (typeof v !== 'string' || !v.startsWith('data:image')) continue;
      found++;
      const img = decode(v);
      if (!img) { console.warn('skip (bad data URL):', t.coll, doc.id, t.field); failed++; continue; }
      const ext = img.mime.includes('png') ? 'png' : img.mime.includes('webp') ? 'webp' : 'jpg';
      const path = `${t.folder(doc.id)}/migrated_${doc.id}_${t.field}.${ext}`;
      console.log(`${APPLY ? 'migrate' : 'would migrate'} ${t.coll}/${doc.id}.${t.field} (${Math.round(img.bytes.length / 1024)} KB) -> ${path}`);
      if (!APPLY) continue;
      try {
        const url = await upload(path, img);
        await doc.ref.update({ [t.field]: url });
        migrated++;
      } catch (e) {
        console.error('FAILED', t.coll, doc.id, t.field, e.message);
        failed++;
      }
    }
  }
  console.log(`\nfound=${found} migrated=${migrated} failed=${failed} ${APPLY ? '' : '(تجربة: ما اتكتبش حاجة، أضف --apply للتنفيذ)'}`);
})();
