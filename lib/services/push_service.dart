import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';

/// يجب أن تكون top-level function (مش داخل كلاس) عشان تشتغل كـ background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // الرسائل اللي بتوصل والتطبيق مقفول بتتعرض تلقائيًا بواسطة النظام لو فيها
  // "notification" payload (مش data-only)، فمفيش داعي لعمل حاجة إضافية هنا
  // غير لو حبيت تعالج البيانات (مثلاً تحديث Badge count).
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// تهيئة كاملة لخدمة الإشعارات - يُستدعى مرة واحدة بعد تسجيل الدخول
  Future<void> init(String userId) async {
    if (_initialized) return;
    _initialized = true;

    // طلب إذن الإشعارات (إلزامي على iOS، وAndroid 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // إعداد الإشعارات المحلية (لعرض الإشعار لما التطبيق مفتوح - foreground)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // حفظ التوكن الحالي، ومتابعة أي تحديث ليه (بيتغيّر أحيانًا)
    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseService.instance.saveFcmToken(userId, token);
    }
    _messaging.onTokenRefresh.listen((newToken) {
      FirebaseService.instance.saveFcmToken(userId, newToken);
    });

    // رسالة توصل والتطبيق مفتوح (foreground) - نعرضها يدويًا كإشعار محلي
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif != null) {
        _localNotifications.show(
          notif.hashCode,
          notif.title,
          notif.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'wasalah_default',
              'إشعارات وصلها',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    });

    if (kDebugMode) {
      debugPrint('FCM token: $token');
    }
  }

  /// إلغاء ربط الجهاز بالإشعارات عند تسجيل الخروج
  Future<void> unregister(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseService.instance.removeFcmToken(userId, token);
    }
    _initialized = false;
  }
}
