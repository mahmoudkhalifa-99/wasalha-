import 'package:latlong2/latlong.dart';

/// إعدادات الخريطة المشتركة. لو عايز تغيّر مزوّد التايلز مستقبلًا، غيّره هنا بس.
/// (نفس التايل سيرفر المستخدم في WasalhaMap الحالية: CartoDB على بيانات OSM.)
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

  /// مركز افتراضي (محافظة المنوفية) لحد ما يتوفر موقع فعلي.
  static const LatLng defaultCenter = LatLng(30.556, 31.008);
  static const double defaultZoom = 14;
  static const double minZoom = 5;
  static const double maxZoom = 18;
}
