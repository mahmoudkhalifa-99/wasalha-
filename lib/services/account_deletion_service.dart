// حذف حساب المستخدم من جوه التطبيق (متطلب متجر Google Play).
//
// الخطوات: (1) إعادة تحقق من الهوية (2) مسح موقع الكابتن (3) مسح وثيقة
// users/{uid} (4) مسح حساب الدخول (Firebase Auth).
// بيفضل محفوظ: سجل الطلبات (طرف تاني فيها) ومستندات التوثيق/سجل المراجعة
// (القواعد بتمنع حذفها: احتفاظ حسب السياسة القانونية).
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'auth_service.dart';
import 'remembered_login.dart';
import 'firebase_service.dart';

/// بيتفعّل أثناء الحذف عشان الـ shell ما يعيدش إنشاء وثيقة المستخدم اللي
/// لسه ماسحينها (والحساب لسه مسجّل دخول لحظة).
bool accountDeletionInProgress = false;

const List<String> _activeStatuses = [
  'PENDING',
  'ASSIGNED',
  'PICKED',
  'IN_DELIVERY',
];

/// هل للمستخدم طلب شغال (كعميل أو ككابتن)؟ لو أيوه ما نحذفش الحساب.
Future<bool> hasActiveOrders(String uid) async {
  for (final field in ['customerId', 'driverId']) {
    final snap = await db
        .collection('orders')
        .where(field, isEqualTo: uid)
        .where('status', whereIn: _activeStatuses)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return true;
  }
  return false;
}

/// الحساب بإيميل وكلمة مرور (لازم نسأل عن كلمة المرور قبل الحذف)؟
bool accountNeedsPassword() =>
    auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
    false;

Future<void> deleteMyAccount(String uid, {String? password}) async {
  final u = auth.currentUser;
  if (u == null || u.uid != uid) {
    throw fb.FirebaseAuthException(code: 'no-current-user');
  }

  // 1) إعادة التحقق من الهوية — قبل أي مسح عشان ما نوصلش لنص حذف.
  if (accountNeedsPassword()) {
    if (password == null || password.isEmpty || (u.email ?? '').isEmpty) {
      throw fb.FirebaseAuthException(code: 'wrong-password');
    }
    await u.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: u.email!, password: password));
  } else {
    await reauthenticateWithGoogle();
  }

  accountDeletionInProgress = true;
  try {
    // 2) موقع الكابتن (best-effort)
    try {
      await db.collection('driver_locations').doc(uid).delete();
    } catch (_) {}

    // 3) وثيقة المستخدم (الاسم/الهاتف/الصورة/المحفظة/توكن الإشعارات)
    await db.collection('users').doc(uid).delete();

    // 4) حساب الدخول
    await u.delete();
    await RememberedLogin.clear();
    await googleSignOutQuiet();
  } finally {
    accountDeletionInProgress = false;
  }
}
