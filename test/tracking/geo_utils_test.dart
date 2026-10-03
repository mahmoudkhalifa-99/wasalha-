import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wasalha/core/map/geo_utils.dart';

void main() {
  group('distanceMeters', () {
    test('نفس النقطة = صفر', () {
      expect(distanceMeters(const LatLng(30, 31), const LatLng(30, 31)), 0);
    });

    test('0.001 درجة طول عند خط عرض 30 ≈ 96 متر', () {
      final d = distanceMeters(const LatLng(30, 31), const LatLng(30, 31.001));
      expect(d, closeTo(96.3, 2));
    });
  });

  group('bearingDegrees', () {
    test('شمال ≈ 0', () {
      final b = bearingDegrees(const LatLng(30, 31), const LatLng(30.01, 31));
      expect(b, closeTo(0, 0.5));
    });

    test('شرق ≈ 90', () {
      final b = bearingDegrees(const LatLng(30, 31), const LatLng(30, 31.01));
      expect(b, closeTo(90, 0.5));
    });

    test('جنوب ≈ 180 وغرب ≈ 270', () {
      expect(bearingDegrees(const LatLng(30, 31), const LatLng(29.99, 31)),
          closeTo(180, 0.5));
      expect(bearingDegrees(const LatLng(30, 31), const LatLng(30, 30.99)),
          closeTo(270, 0.5));
    });
  });

  group('distanceToPolylineMeters', () {
    const line = [LatLng(30, 31), LatLng(30, 31.01)];

    test('نقطة على الخط ≈ 0', () {
      expect(distanceToPolylineMeters(const LatLng(30, 31.005), line),
          closeTo(0, 1));
    });

    test('نقطة بعيدة 0.001 درجة عرض ≈ 111 متر', () {
      expect(distanceToPolylineMeters(const LatLng(30.001, 31.005), line),
          closeTo(111, 3));
    });

    test('قبل بداية الخط: المسافة لأقرب طرف', () {
      final d = distanceToPolylineMeters(const LatLng(30, 30.999), line);
      expect(d, closeTo(96.3, 3));
    });

    test('خط فاضي = لانهاية', () {
      expect(distanceToPolylineMeters(const LatLng(30, 31), const []),
          double.infinity);
    });
  });

  group('formatters', () {
    test('formatDistance', () {
      expect(formatDistance(350), '350 م');
      expect(formatDistance(2400), '2.4 كم');
    });

    test('formatEta', () {
      expect(formatEta(20), 'أقل من دقيقة');
      expect(formatEta(61), '2 د');
      expect(formatEta(3600), '1 س');
      expect(formatEta(5400), '1 س 30 د');
    });
  });
}
