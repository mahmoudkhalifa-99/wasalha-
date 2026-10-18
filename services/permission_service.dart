// طلب الأذونات المطلوبة مرة واحدة عند أول فتح للتطبيق (مباشرة من غير شاشة وسيطة).
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const _askedKey = 'permissions_asked_v2';

class PermissionService {
  static bool _running = false;

  /// أول فتح بس: بيطلب الإشعارات ثم الموقع على طول (نوافذ النظام الأصلية).
  static Future<void> requestOnFirstLaunch() async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) == true) return;

      try {
        await NotificationService.requestPermission();
      } catch (e) {
        debugPrint('notification permission failed: $e');
      }
      try {
        await Permission.locationWhenInUse.request();
      } catch (e) {
        debugPrint('location permission failed: $e');
      }
      await prefs.setBool(_askedKey, true);
    } catch (e) {
      debugPrint('PermissionService failed: $e');
    } finally {
      _running = false;
    }
  }
}
