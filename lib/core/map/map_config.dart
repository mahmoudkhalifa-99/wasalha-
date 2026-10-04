import 'package:flutter/painting.dart' show Color;
import 'package:latlong2/latlong.dart';

/// إعدادات الخريطة المشتركة. لو عايز تغيّر مزوّد التايلز مستقبلًا، غيّره هنا بس.
/// (نفس التايل سيرفر المستخدم في WasalhaMap الحالية: CartoDB على بيانات OSM.)
/// شكل خط المسار (قابل للتعديل من مكان واحد، وممكن يتمرّر لـ TrackingMap).
class RouteStyle {
  const RouteStyle({
    this.color = const Color(0xFF059669),
    this.width = 6,
    this.opacity = 0.9,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 2,
    this.dotted = false,
  });

  final Color color;
  final double width;

  /// 0..1 — شفافية الخط.
  final double opacity;
  final Color borderColor;
  final double borderWidth;

  /// true = خط منقّط بدل المتصل.
  final bool dotted;
}

class MapConfig {
  const MapConfig._();

  /// ممكن تتغيّر وقت البناء من غير تعديل كود:
  ///   --dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}{r}.png?key=XXX
  ///   --dart-define=MAP_TILE_ATTRIBUTION="© OpenStreetMap contributors © MapTiler"
  /// تنبيه: CARTO بقت بتطلب API key، وتصريحها موجّه للاستخدام غير التجاري.
  /// راجع شروط المزوّد قبل الإنتاج.
  static const String tileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  );
  static const List<String> tileSubdomains = ['a', 'b', 'c', 'd'];
  static const String userAgentPackageName = 'com.wasalah.app';
  static const String attribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors © CARTO',
  );
  static const String osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

  /// شكل المسار الافتراضي.
  static const RouteStyle routeStyle = RouteStyle();

  /// هوامش عرض الكل (fitBounds) — الأسفل أكبر عشان الـ Bottom Sheet.
  static const double fitSidePadding = 56;
  static const double fitTopPadding = 120;
  static const double fitBottomPadding = 260;
  static const double fitMaxZoom = 17;

  /// سيرفر الـ Geocoding (Nominatim-compatible). للتجربة فقط — مش للإنتاج:
  ///   --dart-define=GEOCODER_URL=https://your-geocoder.example.com
  /// (ممكن يحتوي على ?key=... لو المزوّد بيطلب).
  static const String geocoderUrl = String.fromEnvironment(
    'GEOCODER_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );
  static const String httpUserAgent = 'Wasalha/1.0 ($userAgentPackageName)';

  /// مركز افتراضي (محافظة المنوفية) لحد ما يتوفر موقع فعلي.
  static const LatLng defaultCenter = LatLng(30.556, 31.008);
  static const double defaultZoom = 14;
  static const double minZoom = 5;
  static const double maxZoom = 18;
}
