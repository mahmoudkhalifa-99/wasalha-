// نسخة Dart من utils.ts
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// جلب قائمة إحداثيات المسار الفعلي (Road Geometry) بين نقطتين عبر OSRM
/// تُرجع قائمة [lat, lng].
Future<List<List<double>>> getRouteGeometry(
    double lat1, double lon1, double lat2, double lon2) async {
  if (lat1 == 0 || lon1 == 0 || lat2 == 0 || lon2 == 0) return [];
  try {
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson');
    final response =
        await http.get(url).timeout(const Duration(milliseconds: 2500));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map &&
          data['code'] == 'Ok' &&
          (data['routes'] as List).isNotEmpty &&
          data['routes'][0]['geometry']?['coordinates'] != null) {
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        return coords
            .map<List<double>>((c) =>
                [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
            .toList();
      }
    }
  } catch (_) {
    // Fallback quietly to direct trajectory
  }
  return [
    [lat1, lon1],
    [lat2, lon2]
  ];
}

class RoadDistance {
  final double distance; // كم
  final int duration; // دقيقة
  const RoadDistance(this.distance, this.duration);
}

/// حساب المسافة الفعلية والزمن التقديري للطرق
Future<RoadDistance> getRoadDistance(
    double lat1, double lon1, double lat2, double lon2) async {
  if (lat1 == 0 || lon1 == 0 || lat2 == 0 || lon2 == 0) {
    return const RoadDistance(0, 0);
  }
  try {
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=false');
    final response =
        await http.get(url).timeout(const Duration(milliseconds: 2500));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
        final r = data['routes'][0];
        return RoadDistance(
          double.parse(((r['distance'] as num) / 1000).toStringAsFixed(1)),
          ((r['duration'] as num) / 60).ceil(),
        );
      }
    }
  } catch (_) {
    // Fallback quietly to calculated straight distance
  }
  final straight = calculateDistance(lat1, lon1, lat2, lon2);
  return RoadDistance(
    double.parse((straight * 1.3).toStringAsFixed(1)),
    (straight * 3).ceil(),
  );
}

double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * (math.pi / 180);
  final dLon = (lon2 - lon1) * (math.pi / 180);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180)) *
          math.cos(lat2 * (math.pi / 180)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return double.parse((r * c).toStringAsFixed(1));
}

/// ضغط الصور لتقليل استهلاك الذاكرة وحجم المستندات في Firestore
/// (نفس المنطق: أقصى أبعاد 800x800، JPEG بجودة 60%).
Future<String> compressImage(String base64Str,
    {int maxWidth = 800, int maxHeight = 800}) async {
  if (base64Str.isEmpty || !base64Str.startsWith('data:image')) {
    return base64Str;
  }
  try {
    final comma = base64Str.indexOf(',');
    final Uint8List bytes = base64Decode(base64Str.substring(comma + 1));
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return base64Str;

    var width = decoded.width.toDouble();
    var height = decoded.height.toDouble();
    if (width > height) {
      if (width > maxWidth) {
        height *= maxWidth / width;
        width = maxWidth.toDouble();
      }
    } else {
      if (height > maxHeight) {
        width *= maxHeight / height;
        height = maxHeight.toDouble();
      }
    }
    final resized = img.copyResize(decoded,
        width: width.round(), height: height.round());
    final jpg = img.encodeJpg(resized, quality: 60);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  } catch (_) {
    return base64Str;
  }
}
