# موديول الخريطة والتتبع (Map + Live Tracking)

موديول مستقل: ما بيعتمدش على أي شاشة في التطبيق وما فيش شاشة حالية بتستخدمه
(لحد ما الـ build يتأكد). كل حاجة جوه `lib/features/tracking/` و`lib/core/map/`.

## الطبقات
- `core/map/routing_service.dart` — واجهة `RoutingService` (استبدل OSRM بأي مزوّد).
- `core/map/osrm_routing_service.dart` — OSRM (بدون API key).
- `core/map/map_config.dart` — التايلز والمركز الافتراضي.
- `services/location_service.dart` — الصلاحيات وGPS (geolocator).
- `services/driver_location_source.dart` — قراءة موقع السائق من Firestore، وبث موقع السائق.
- `controllers/tracking_controller.dart` — الحالة (ValueNotifiers) + throttle المسار.
- `widgets/` + `screens/tracking_screen.dart` — الواجهة.

## الاستخدام
```dart
// العميل بيتابع السائق
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => TrackingScreen(
    role: TrackingRole.customerWatchingDriver,
    driverId: order.driverId,
    customerLocation: LatLng(order.dropoff.lat, order.dropoff.lng),
  ),
));

// السائق (الجهاز بيبث موقعه) — ما تشغّلوش مع courier_dashboard لنفس السائق
TrackingScreen(role: TrackingRole.driverSharing, driverId: user.id,
    customerLocation: LatLng(...));
```

## القواعد المطبّقة
- المسار بيتحسب تاني بس لما السائق يتحرك ≥ 75 متر، أو يبعد ≥ 60 متر عن الخط،
  وبحد أدنى 10 ثواني بين الطلبات، وطلب واحد في نفس الوقت.
- عند فشل الشبكة بنحتفظ بآخر مسار، وبنعيد المحاولة تلقائيًا كل 10 ثواني.
- اشتراك GPS واحد، واشتراك سائق واحد، ومؤقت واحد — كلهم بيتقفلوا في `dispose()`.
- مفيش مفاتيح API. لو غيّرت لمزوّد بمفتاح، مرّره عبر `--dart-define` مش في الكود.

## الواجهة والمعمارية (v11)
```
TrackingScreen (UI)  →  TrackingController / LocationPickerController
                     →  Services: LocationService · RoutingService · GeocodingService · DriverLocationSource
```
- **الكاميرا:** الـ `TrackingController` بيصدر `CameraCommand` (fitBounds / centerOnDriver /
  centerOnMe / centerOnSelectedLocation) والـ `TrackingMap` بس هو اللي بينفّذها بـ `MapController`.
  fitBounds مرة واحدة عند الفتح، وبعد ما المستخدم يحرّك الخريطة مفيش تحريك أوتوماتيك.
- **اختيار موقع:** `TrackingScreenMode.pickLocation` أو زر الشريط العلوي. Pin ثابت، debounce 500ms،
  Reverse Geocoding بعد التوقف فقط، ورقم نسخة بيتجاهل أي رد قديم. الاعتماد بيستدعي
  `onLocationSelected(SelectedLocation)` وبعدها (لو `applySelectionAsDestination`) `setDestination`
  — ودي الحالة الوحيدة اللي اختيار موقع بيتحول فيها لطلب Routing.
- **الحداثة:** `Freshness` = LIVE / STALE / WAITING / UNAVAILABLE بعتبات في `TrackingConfig`
  (30 ثانية / 10 دقائق). **دقة GPS:** `maxAcceptedAccuracyMeters` (افتراضي 50 م) — النقطة السيئة بتتجاهل
  والتتبع بيكمّل.
- **إعدادات وقت البناء (`--dart-define`):** `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, `GEOCODER_URL`.
  الـ Geocoder الافتراضي (Nominatim العام) **للتجربة فقط**.

TODO BEFORE PRODUCTION:
Firestore location.updatedAt should use serverTimestamp rather than relying on driver device clock.
