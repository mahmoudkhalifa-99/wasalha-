// خيارات الاتصال بنفس مشروع Firebase المستخدم في نسخة الويب (sada-51292)
// ملحوظة مهمة: apiKey الخاص بالويب لا يُستخدم عادة في تطبيقات الموبايل.
// لازم تضيف تطبيق Android/iOS جديد من Firebase Console وتحمّل منه:
//   google-services.json → android/app/
//   GoogleService-Info.plist → ios/Runner/
// وبعدين تستبدل القيم دي بالقيم الحقيقية الخاصة بكل منصة (appId مختلف لكل من Android وiOS).
// أسهل طريقة: نفّذ `flutterfire configure` من الطرفية وهو هيولّد الملف ده تلقائيًا.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions غير مُعدّة لهذه المنصة. شغّل flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDlfpN0JCsmpCKdTyb4ZX_QN0sZbypIv48',
    appId: '1:821734316791:web:a41030678e2ecaa168d1f2',
    messagingSenderId: '821734316791',
    projectId: 'sada-51292',
    authDomain: 'sada-51292.firebaseapp.com',
    storageBucket: 'sada-51292.firebasestorage.app',
    databaseURL: 'https://sada-51292-default-rtdb.firebaseio.com',
  );

  // ✅ قيم حقيقية من google-services.json (تطبيق Android com.wasalah.app)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBotBdkEY8NKXwJBnTcB4FDQLSpb0PCX68',
    appId: '1:821734316791:android:aa1ab6b3f528af7868d1f2',
    messagingSenderId: '821734316791',
    projectId: 'sada-51292',
    storageBucket: 'sada-51292.firebasestorage.app',
    databaseURL: 'https://sada-51292-default-rtdb.firebaseio.com',
  );

  // ⚠️ استبدل appId وiosBundleId بالقيم الحقيقية من GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDlfpN0JCsmpCKdTyb4ZX_QN0sZbypIv48',
    appId: '1:821734316791:ios:REPLACE_ME',
    messagingSenderId: '821734316791',
    projectId: 'sada-51292',
    storageBucket: 'sada-51292.firebasestorage.app',
    databaseURL: 'https://sada-51292-default-rtdb.firebaseio.com',
    iosBundleId: 'com.wasalah.app',
  );
}
