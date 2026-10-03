import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wasalha/core/map/routing_service.dart';
import 'package:wasalha/features/tracking/controllers/tracking_controller.dart';
import 'package:wasalha/features/tracking/models/tracking_models.dart';
import 'package:wasalha/features/tracking/services/driver_location_source.dart';
import 'package:wasalha/features/tracking/services/location_service.dart';

class FakeLocation implements LocationService {
  FakeLocation({this.issue});
  LocationIssue? issue;
  LatLng? current = const LatLng(30.55, 31.0);
  final StreamController<GeoFix> ctrl = StreamController<GeoFix>.broadcast();
  int watchCalls = 0;

  @override
  Future<LocationIssue?> ensureReady() async => issue;

  @override
  Future<LatLng?> currentLatLng() async => current;

  @override
  Stream<GeoFix> watch({int distanceFilter = 5}) {
    watchCalls++;
    return ctrl.stream;
  }

  @override
  Future<void> openSettings(LocationIssue issue) async {}
}

class FakeRouting implements RoutingService {
  int calls = 0;
  RoutingException? failWith;

  @override
  Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    calls++;
    final f = failWith;
    if (f != null) throw f;
    return RouteResult(
      points: [start, destination],
      distanceMeters: 1000,
      durationSeconds: 120,
    );
  }
}

class FakeSource implements DriverLocationSource {
  final StreamController<GeoFix> ctrl = StreamController<GeoFix>.broadcast();
  @override
  Stream<GeoFix> watch() => ctrl.stream;
}

GeoFix fix(double lat, double lng) =>
    GeoFix(position: LatLng(lat, lng), updatedAt: DateTime.now());

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

const _customer = LatLng(30.56, 31.01);

void main() {
  late FakeLocation location;
  late FakeRouting routing;
  late FakeSource source;
  late TrackingController c;

  setUp(() {
    location = FakeLocation();
    routing = FakeRouting();
    source = FakeSource();
    c = TrackingController(
      location: location,
      routing: routing,
      driverSource: source,
      customerLocation: _customer,
      minRouteInterval: Duration.zero,
    );
  });

  tearDown(() => c.dispose());

  test('بيحسب المسار مرة واحدة ولا يعيد الطلب مع تحركات صغيرة', () async {
    await c.start();
    for (var i = 0; i < 5; i++) {
      source.ctrl.add(fix(30.55 + i * 0.00002, 31.0)); // ~2 متر كل مرة
      await pump();
    }
    expect(routing.calls, 1);
    expect(c.route.value, isNotNull);
    expect(c.status.value, TrackingStatus.live);
  });

  test('بيعيد حساب المسار بعد تحرك أكبر من 75 متر', () async {
    await c.start();
    source.ctrl.add(fix(30.55, 31.0));
    await pump();
    source.ctrl.add(fix(30.552, 31.0)); // ~222 متر
    await pump();
    expect(routing.calls, 2);
  });

  test('بيعيد الحساب لما السائق يخرج عن خط المسار (حتى لو تحرك أقل من 75 متر)',
      () async {
    await c.start();
    source.ctrl.add(fix(30.55, 31.0));
    await pump();
    // المسار خط قطري ناحية الشمال الشرقي. التحرك ناحية الجنوب الشرقي ~70 متر
    // (أقل من 75) لكنه عمودي تقريبًا على الخط → بعد ~69 متر عنه (> 60).
    source.ctrl.add(fix(30.55 - 0.00035, 31.0 + 0.0006));
    await pump();
    expect(routing.calls, 2);
  });

  test('فشل الشبكة: بنحتفظ بآخر مسار ونعلّم الاتصال مقطوع، وبيرجع بعد النجاح',
      () async {
    await c.start();
    source.ctrl.add(fix(30.55, 31.0));
    await pump();
    final firstRoute = c.route.value;
    expect(firstRoute, isNotNull);

    routing.failWith = const RoutingException(RoutingFailure.network);
    source.ctrl.add(fix(30.553, 31.0));
    await pump();
    expect(c.networkOk.value, isFalse);
    expect(c.routeUnavailable.value, isTrue);
    expect(identical(c.route.value, firstRoute), isTrue);

    routing.failWith = null;
    source.ctrl.add(fix(30.556, 31.0));
    await pump();
    expect(c.networkOk.value, isTrue);
    expect(c.routeUnavailable.value, isFalse);
    expect(identical(c.route.value, firstRoute), isFalse);
  });

  test('وضع السائق: صلاحية مرفوضة نهائيًا = locationBlocked ومفيش stream', () async {
    final driverLoc = FakeLocation(issue: LocationIssue.deniedForever);
    final d = TrackingController(
      location: driverLoc,
      routing: routing,
      customerLocation: _customer,
    );
    await d.start();
    expect(d.locationIssue.value, LocationIssue.deniedForever);
    expect(d.status.value, TrackingStatus.locationBlocked);
    expect(driverLoc.watchCalls, 0);
    d.dispose();
  });

  test('وضع السائق: موقع الجهاز يتحول لموقع السائق ويتحسب المسار', () async {
    final driverLoc = FakeLocation();
    final d = TrackingController(
      location: driverLoc,
      routing: routing,
      customerLocation: _customer,
      minRouteInterval: Duration.zero,
    );
    await d.start();
    await pump();
    expect(d.isDriverMode, isTrue);
    expect(d.driver.value, isNotNull);
    expect(d.status.value, TrackingStatus.live);
    expect(routing.calls, 1);
    d.dispose();
  });

  test('retryLocation ما بيفتحش أكتر من stream واحد', () async {
    await c.start();
    await c.retryLocation();
    await c.retryLocation();
    expect(location.ctrl.hasListener, isTrue);
    expect(location.watchCalls, 3); // كل استدعاء بيلغي القديم قبل الجديد
  });

  test('dispose بيقفل كل الاشتراكات', () async {
    await c.start();
    expect(source.ctrl.hasListener, isTrue);
    expect(location.ctrl.hasListener, isTrue);
    c.dispose();
    await pump();
    expect(source.ctrl.hasListener, isFalse);
    expect(location.ctrl.hasListener, isFalse);
  });
}
