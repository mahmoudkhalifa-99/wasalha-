import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_service.dart';

/// تسجيل الدخول بجوجل على الأندرويد.
///
/// بيستخدم `signInWithProvider` بتاع firebase_auth — وده بيفتح شاشة جوجل
/// الرسمية عن طريق Chrome Custom Tab (مش WebView مدمج)، وده المسموح من جوجل،
/// فمفيش المشكلة القديمة اللي كانت بتطلّع "فشل تسجيل الدخول".
/// المطلوب بس: google-services.json + تسجيل بصمة SHA-1 في Firebase Console.
Future<UserCredential> signInWithGoogle() {
  final provider = GoogleAuthProvider()
    ..addScope('email')
    ..addScope('profile');
  return auth.signInWithProvider(provider);
}

/// هل الخطأ ده معناه إن المستخدم لغى شاشة جوجل بنفسه؟
bool isGoogleSignInCancelled(Object error) {
  if (error is FirebaseAuthException) {
    return error.code == 'web-context-canceled' ||
        error.code == 'canceled' ||
        error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request';
  }
  return false;
}
