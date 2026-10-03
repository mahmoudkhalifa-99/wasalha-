import 'package:latlong2/latlong.dart';

/// موقع لحظي (للسائق أو للجهاز).
class GeoFix {
  const GeoFix({
    required this.position,
    required this.updatedAt,
    this.bearing,
  });

  final LatLng position;
  final DateTime updatedAt;

  /// اتجاه الحركة بالدرجات (0–360) لو معروف.
  final double? bearing;
}

enum TrackingStatus {
  /// جاري تجهيز الموقع/التتبع.
  starting,

  /// وضع العميل: لسه موقع السائق ما وصلش.
  waitingForDriver,

  /// التتبع شغال.
  live,

  /// وضع السائق: مفيش صلاحية أو GPS مقفول.
  locationBlocked,
}

enum LocationIssue { serviceDisabled, denied, deniedForever, unavailable }

extension LocationIssueText on LocationIssue {
  String get message {
    switch (this) {
      case LocationIssue.serviceDisabled:
        return 'خدمة الموقع (GPS) مقفولة. فعّلها عشان نحدد موقعك.';
      case LocationIssue.denied:
        return 'محتاجين صلاحية الموقع عشان نعرض موقعك على الخريطة.';
      case LocationIssue.deniedForever:
        return 'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات التطبيق.';
      case LocationIssue.unavailable:
        return 'تعذّر تحديد موقعك حاليًا. حاول تاني بعد شوية.';
    }
  }

  String get actionLabel {
    switch (this) {
      case LocationIssue.serviceDisabled:
        return 'فتح إعدادات الموقع';
      case LocationIssue.deniedForever:
        return 'فتح إعدادات التطبيق';
      case LocationIssue.denied:
      case LocationIssue.unavailable:
        return 'إعادة المحاولة';
    }
  }
}

/// دور الجهاز في الشاشة.
enum TrackingRole {
  /// العميل بيتابع موقع السائق (من Firestore).
  customerWatchingDriver,

  /// الجهاز نفسه هو السائق (بيستخدم الـ GPS ويبث الموقع).
  driverSharing,
}
