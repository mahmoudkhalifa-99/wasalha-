import 'package:latlong2/latlong.dart';

/// إعدادات الخريطة المشتركة. لو عايز تغيّر مزوّد التايلز مستقبلًا، غيّره هنا بس.
/// (نفس التايل سيرفر المستخدم في WasalhaMap الحالية: CartoDB على بيانات OSM.)
class MapConfig {
  const MapConfig._();

  static const String tileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const List<String> tileSubdomains = ['a', 'b', 'c', 'd'];
  static const String userAgentPackageName = 'com.wasalah.app';
  static const String attribution = '© OpenStreetMap contributors © CARTO';

  /// مركز افتراضي (محافظة المنوفية) لحد ما يتوفر موقع فعلي.
  static const LatLng defaultCenter = LatLng(30.556, 31.008);
  static const double defaultZoom = 14;
  static const double minZoom = 5;
  static const double maxZoom = 18;
}
