تنبيه مهم جدًا
===============
الملفات دي (wasalah-release.jks + الباسوردات) هي مفتاح توقيع تطبيقك الرسمي.
لو ضاعت أو اتغيّرت، مش هتقدر تحدّث نفس التطبيق على Google Play تاني (هيعتبره تطبيق مختلف).
لو سُرقت أو اتسربت لحد تاني، ممكن حد ينتحل تطبيقك.

- متِرفعش مجلد signing/ ده على Git أبدًا (already مضاف في .gitignore).
- خده نسخة احتياطية في مكان آمن عندك (مش على الريبو).

خطوات الإعداد في Codemagic
============================
1) روح Codemagic → Teams → Team settings → Environment variables (أو من صفحة الـ App
   نفسها → Environment variables)، واختار الجروب اللي اسمه "wasalah_env" (هو نفس الاسم
   المستخدم في codemagic.yaml).

2) ضيف المتغيرات دي (خليهم Secure/Encrypted):

   CM_KEYSTORE           = محتوى ملف wasalah-release.jks.base64.txt (انسخه كامل كنص واحد)
   CM_KEYSTORE_PASSWORD  = (شوف القيمة في الملف اللي وصلك على الشات باسم CREDENTIALS)
   CM_KEY_ALIAS          = wasalah_release
   CM_KEY_PASSWORD       = (نفس قيمة CM_KEYSTORE_PASSWORD)

3) بعد ما تضيفهم، أي بيلد جديد هيوقّع الـ APK/AAB تلقائيًا بالمفتاح الثابت ده،
   بدل مفتاح الـ debug العشوائي اللي كان بيتغيّر كل بيلد.

4) سجّل بصمة SHA-1 و SHA-256 دي في Firebase Console:
   Firebase Console → إعدادات المشروع (sada-51292) → تطبيق Android (com.wasalah.app)
   → Add fingerprint

   SHA1:   FD:4B:D0:4B:C8:CD:BE:A5:B8:9C:AC:D1:7E:9D:24:4F:C5:39:D8:BC
   SHA256: 8F:A1:5A:7C:94:79:B1:C3:0F:75:11:BD:7B:6A:2C:EC:3F:8B:56:24:98:BB:E6:0E:DC:26:27:15:4B:1F:D8:FC

   من غير الخطوة دي، تسجيل الدخول بجوجل هيفضل بيدّي error حتى لو التوقيع اتظبط.

5) لو نزّلت google-services.json من Firebase بعد إضافة البصمة، حطه في android/app/
   (مش إجباري طالما firebase_options.dart فيه القيم الصح، بس بيحسّن استقرار
   google_sign_in على بعض الأجهزة).
