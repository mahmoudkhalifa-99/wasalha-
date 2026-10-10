import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// شاشة الترحيب (أهلاً بك في وصلها) بتظهر مرة واحدة بس بعد تثبيت التطبيق.
/// بتتحمّل قبل ما الواجهة تبدأ (في main) عشان ما يحصلش وميض.
class OnboardingPrefs {
  OnboardingPrefs._();

  static const _key = 'onboarding_seen_v1';

  /// المستخدم شاف الترحيب قبل كده؟ (false لو التحميل فشل → نعرضه مرة)
  static bool seen = false;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_key) ?? false;
    } catch (e) {
      debugPrint('OnboardingPrefs.load failed: $e');
    }
  }

  static Future<void> markSeen() async {
    seen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (e) {
      debugPrint('OnboardingPrefs.markSeen failed: $e');
    }
  }
}
