import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_service.dart';

/// المستخدم قفل نافذة اختيار الحساب بنفسه.
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
  @override
  String toString() => 'GoogleSignInCancelledException';
}

// Web client ID (client_type 3) من google-services.json — بيضمن إن idToken
// يرجع حتى لو الـ plugin ما ولّدش default_web_client_id.
const String _webClientId =
    '821734316791-v4n5r7slachnbfj51nnnbborae0r81jn.apps.googleusercontent.com';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: const ['email', 'profile'],
  serverClientId: _webClientId,
);

/// تسجيل الدخول بجوجل على الأندرويد بالطريقة الأصلية (Native).
///
/// بتظهر قايمة حسابات جوجل جوه التطبيق مباشرة من غير ما يفتح المتصفح، فمفيش
/// صفحة firebaseapp.com ولا خطأ "missing initial state" ولا اختيار حساب مرتين.
/// المطلوب: google-services.json محدّث + بصمة SHA-1 مسجلة في Firebase.
Future<UserCredential> signInWithGoogle() async {
  // نخرّج الحساب السابق عشان قايمة الحسابات تظهر كل مرة
  try {
    await _googleSignIn.signOut();
  } catch (e) {
    debugPrint('google signOut before signIn failed: $e');
  }
  final account = await _googleSignIn.signIn();
  if (account == null) throw const GoogleSignInCancelledException();

  final g = await account.authentication;
  // لو idToken رجع null لأي سبب، Firebase بيقبل accessToken لوحده، فنكمل بيه
  // بدل ما نوقف تسجيل الدخول. بنفشل بس لو الاتنين مش موجودين.
  if (g.idToken == null && g.accessToken == null) {
    throw FirebaseAuthException(
      code: 'missing-id-token',
      message: 'جوجل ما رجّعش أي توكن (راجع Web client ID و SHA-1)',
    );
  }
  final credential = GoogleAuthProvider.credential(
    idToken: g.idToken,
    accessToken: g.accessToken,
  );
  return auth.signInWithCredential(credential);
}

/// هل الخطأ ده معناه إن المستخدم لغى شاشة جوجل بنفسه؟
bool isGoogleSignInCancelled(Object error) {
  if (error is GoogleSignInCancelledException) return true;
  if (error is PlatformException) {
    return error.code == 'sign_in_canceled' || error.code == 'canceled';
  }
  if (error is FirebaseAuthException) {
    return error.code == 'web-context-canceled' ||
        error.code == 'canceled' ||
        error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request';
  }
  return false;
}

/// كود مختصر للخطأ (للرسالة اللي بتظهر للمستخدم).
String googleSignInErrorCode(Object error) {
  if (error is FirebaseAuthException) return error.code;
  if (error is PlatformException) return error.code;
  return error.runtimeType.toString();
}

/// إعادة التحقق من الهوية بجوجل (قبل العمليات الحساسة زي حذف الحساب).
Future<void> reauthenticateWithGoogle() async {
  final user = auth.currentUser;
  if (user == null) {
    throw FirebaseAuthException(code: 'no-current-user');
  }
  try {
    await _googleSignIn.signOut();
  } catch (e) {
    debugPrint('google signOut before reauth failed: $e');
  }
  final account = await _googleSignIn.signIn();
  if (account == null) throw const GoogleSignInCancelledException();
  final g = await account.authentication;
  if (g.idToken == null && g.accessToken == null) {
    throw FirebaseAuthException(
      code: 'missing-id-token',
      message: 'جوجل ما رجّعش أي توكن',
    );
  }
  await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
    idToken: g.idToken,
    accessToken: g.accessToken,
  ));
}

/// تسجيل خروج حساب جوجل من الـ plugin (بدون أخطاء).
Future<void> googleSignOutQuiet() async {
  try {
    await _googleSignIn.signOut();
  } catch (e) {
    debugPrint('google signOut failed: $e');
  }
}

/// دخول جوجل بصمت (من غير قايمة حسابات) — لاستعادة الجلسة لو Firebase فقدها.
/// بيرجّع false لو مفيش حساب جوجل متسجّل دخول على الجهاز.
Future<bool> signInWithGoogleSilently() async {
  final account = await _googleSignIn.signInSilently();
  if (account == null) return false;
  final g = await account.authentication;
  if (g.idToken == null && g.accessToken == null) return false;
  await auth.signInWithCredential(GoogleAuthProvider.credential(
    idToken: g.idToken,
    accessToken: g.accessToken,
  ));
  return true;
}
