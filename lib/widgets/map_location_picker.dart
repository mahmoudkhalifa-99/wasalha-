import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config_constants.dart';
import '../core/map/geo_utils.dart';
import '../features/tracking/models/selected_location.dart';
import '../features/tracking/models/tracking_models.dart';
import '../features/tracking/screens/tracking_screen.dart';
import '../features/tracking/services/geocoding_service.dart';
import '../features/tracking/services/location_service.dart';
import '../models/models.dart';

/// فتح الخريطة بوضع "اختيار موقع" (Pin ثابت في المنتصف). بيرجّع الموقع
/// المعتمد أو null لو المستخدم رجع من غير اختيار.
Future<SelectedLocation?> pickLocationOnMap(BuildContext context) {
  return Navigator.of(context).push<SelectedLocation>(
    MaterialPageRoute(
      builder: (ctx) => TrackingScreen(
        role: TrackingRole.customerWatchingDriver,
        title: 'اختر الموقع من الخريطة',
        initialMode: TrackingScreenMode.pickLocation,
        allowLocationPicking: false,
        applySelectionAsDestination: false,
        onLocationSelected: (sel) => Navigator.of(ctx).pop(sel),
      ),
    ),
  );
}

/// نتيجة "موقعي الحالي": الموقع، أو سبب الفشل بعبارة مفهومة للمستخدم.
class CurrentLocationResult {
  const CurrentLocationResult.ok(this.location) : error = null;
  const CurrentLocationResult.failed(this.error) : location = null;
  final SelectedLocation? location;
  final String? error;
}

Future<CurrentLocationResult> fetchCurrentLocation() async {
  const service = GeolocatorLocationService();
  final issue = await service.ensureReady();
  if (issue != null) {
    return const CurrentLocationResult.failed(
        'مش قادر أحدد موقعك. فعّل الـ GPS واسمح للتطبيق بالوصول للموقع.');
  }
  final p = await service.currentLatLng();
  if (p == null) {
    return const CurrentLocationResult.failed(
        'تعذّر تحديد موقعك الآن، جرّب تاني أو اختر من الخريطة.');
  }
  // العنوان اختياري: لو فشل بنكمّل بالإحداثيات (الطلب مش بيتعطّل بسببه).
  final geocoder = NominatimGeocodingService();
  String? address;
  try {
    address = await geocoder.reverseGeocode(p);
  } catch (_) {
    address = null;
  } finally {
    geocoder.close();
  }
  return CurrentLocationResult.ok(SelectedLocation(
    latitude: p.latitude,
    longitude: p.longitude,
    address: (address == null || address.trim().isEmpty)
        ? 'موقعي الحالي'
        : address,
  ));
}

/// أقرب قرية (ومركزها) لنقطة، عشان التسعير والمسافة يفضلوا شغالين.
({District district, Village village})? nearestVillage(LatLng p) {
  District? bestD;
  Village? bestV;
  var best = double.infinity;
  for (final d in menofiaData) {
    for (final v in d.villages) {
      final m = distanceMeters(p, LatLng(v.center.lat, v.center.lng));
      if (m < best) {
        best = m;
        bestD = d;
        bestV = v;
      }
    }
  }
  if (bestD == null || bestV == null) return null;
  return (district: bestD, village: bestV);
}
