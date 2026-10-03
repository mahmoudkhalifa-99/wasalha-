import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double _earthRadiusM = 6371000;

double _rad(double deg) => deg * math.pi / 180;

/// المسافة بالمتر بين نقطتين (Haversine).
double distanceMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

/// الاتجاه (Bearing) بالدرجات من 0 إلى 360 (0 = شمال، 90 = شرق).
double bearingDegrees(LatLng from, LatLng to) {
  final lat1 = _rad(from.latitude);
  final lat2 = _rad(to.latitude);
  final dLng = _rad(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// استيفاء زاوية بأقصر دوران: من 359° إلى 1° بيمشي +2° (مش −358°).
/// الناتج في [0, 360). t بين 0 و1.
double lerpBearing(double from, double to, double t) {
  final delta = ((to - from + 540) % 360) - 180;
  return (from + delta * t) % 360;
}

/// أقل مسافة (بالمتر) بين نقطة وخط مكسور (Polyline).
/// بنحوّل لإحداثيات محلية بالمتر (تقريب مناسب للمسافات القصيرة).
double distanceToPolylineMeters(LatLng p, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return distanceMeters(p, line.first);

  final cosLat = math.cos(_rad(p.latitude));
  double toX(LatLng q) => _rad(q.longitude - p.longitude) * _earthRadiusM * cosLat;
  double toY(LatLng q) => _rad(q.latitude - p.latitude) * _earthRadiusM;

  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    final ax = toX(line[i]);
    final ay = toY(line[i]);
    final bx = toX(line[i + 1]);
    final by = toY(line[i + 1]);
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    // النقطة p هي نقطة الأصل (0,0) في الإحداثيات المحلية.
    var t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy)) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (d < best) best = d;
  }
  return best;
}

/// تنسيق المسافة بالعربي: "350 م" أو "2.4 كم".
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} م';
  return '${(meters / 1000).toStringAsFixed(1)} كم';
}

/// تنسيق الوقت المتوقع بالعربي.
String formatEta(double seconds) {
  if (seconds < 60) return 'أقل من دقيقة';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes د';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h س' : '$h س $m د';
}
