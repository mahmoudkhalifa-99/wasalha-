import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'remembered_login.dart';

/// خيار "تذكرني" في شاشة الدخول.
/// - مفعّل (الافتراضي): الجلسة بتفضل محفوظة والتطبيق بيفتح على طول من غير دخول.
/// - متعطّل: التطبيق بيعمل تسجيل خروج تلقائي عند فتحه في المرة الجاية.
class SessionPrefs {
  SessionPrefs._();

  static const _key = 'remember_me_v1';

  static bool rememberMe = true;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      rememberMe = prefs.getBool(_key) ?? true;
    } catch (e) {
      debugPrint('SessionPrefs.load failed: $e');
    }
  }

  static Future<void> setRememberMe(bool value) async {
    rememberMe = value;
    if (!value) await RememberedLogin.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('SessionPrefs.setRememberMe failed: $e');
    }
  }
}
