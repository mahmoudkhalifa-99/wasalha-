import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'firebase_service.dart';

/// استعادة الجلسة لما "تذكرني" يكون مفعّل.
///
/// Firebase بيحفظ الجلسة لوحده، لكن على بعض الأجهزة بتضيع لما التطبيق يتقفل.
/// عشان كده بنحفظ طريقة الدخول (وكلمة المرور لحسابات الإيميل) مشفّرة في
/// التخزين الآمن للجهاز (Android Keystore)، ولو Firebase رجع من غير جلسة
/// بنسجّل الدخول بصمت. بيتمسح عند تسجيل الخروج أو حذف الحساب أو إلغاء "تذكرني".
class RememberedLogin {
  RememberedLogin._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kMethod = 'rl_method';
  static const _kEmail = 'rl_email';
  static const _kPass = 'rl_pass';

  static Future<void> savePassword(String email, String password) async {
    try {
      await _storage.write(key: _kMethod, value: 'password');
      await _storage.write(key: _kEmail, value: email.trim());
      await _storage.write(key: _kPass, value: password);
    } catch (e) {
      debugPrint('RememberedLogin.savePassword failed: $e');
    }
  }

  static Future<void> saveGoogle() async {
    try {
      await _storage.write(key: _kMethod, value: 'google');
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPass);
    } catch (e) {
      debugPrint('RememberedLogin.saveGoogle failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _kMethod);
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPass);
    } catch (e) {
      debugPrint('RememberedLogin.clear failed: $e');
    }
  }

  /// لو مفيش جلسة Firebase: نحاول نرجّعها من اللي محفوظ. بترجّع true لو فيه جلسة.
  static Future<bool> tryRestore() async {
    if (auth.currentUser != null) return true;
    try {
      final method = await _storage.read(key: _kMethod);
      if (method == 'password') {
        final email = await _storage.read(key: _kEmail);
        final pass = await _storage.read(key: _kPass);
        if (email == null || pass == null) return false;
        await auth.signInWithEmailAndPassword(email: email, password: pass);
        return true;
      }
      if (method == 'google') {
        return await signInWithGoogleSilently();
      }
    } on FirebaseAuthException catch (e) {
      // كلمة المرور اتغيّرت أو الحساب اتعطّل/اتحذف: المحفوظ ما بقاش صالح
      const stale = {
        'wrong-password',
        'invalid-credential',
        'user-disabled',
        'user-not-found',
      };
      if (stale.contains(e.code)) await clear();
      debugPrint('RememberedLogin.tryRestore: ${e.code}');
    } catch (e) {
      debugPrint('RememberedLogin.tryRestore failed: $e');
    }
    return false;
  }
}
