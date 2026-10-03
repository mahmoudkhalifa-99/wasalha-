import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/geo_utils.dart';
import '../../../core/map/routing_service.dart';
import '../models/tracking_models.dart';
import '../services/driver_location_source.dart';
import '../services/location_service.dart';

/// منسّق التتبع. كل حالة معروضة في [ValueNotifier] مستقل، فالـ Widgets
/// بتسمع للجزء اللي محتاجاه بس — الخريطة نفسها ما بتتعملهاش rebuild مع كل GPS.
///
/// الوضعين:
///  • العميل: [driverSource] != null → موقع السائق جاي من المصدر.
///  • السائق: [driverSource] == null → الجهاز هو السائق (GPS) ولو فيه
///    [publisher] بيبث الموقع.
class TrackingController {
  TrackingController({
    required this.location,
    required this.routing,
    this.driverSource,
    this.publisher,
    this.customerLocation,
    this.minRouteInterval = const Duration(seconds: 10),
    this.rerouteDistanceMeters = 75,
    this.offRouteMeters = 60,
    this.tick = const Duration(seconds: 10),
    this.retryBackoffBase = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocationService location;
  final RoutingService routing;
  final DriverLocationSource? driverSource;
  final DriverLocationPublisher? publisher;
  final LatLng? customerLocation;

  /// أقل فاصل بين طلبين لـ Routing API.
  final Duration minRouteInterval;

  /// إعادة حساب المسار لما السائق يتحرك المسافة دي من نقطة آخر حساب.
  final double rerouteDistanceMeters;

  /// أو لما يبعد عن خط المسار بالمسافة دي.
  final double offRouteMeters;

  /// فاصل مؤقّت المحاولات (إعادة المحاولة بعد فشل / إعادة الاشتراك).
  final Duration tick;

  /// أساس الـ backoff التصاعدي بعد فشل Routing / اشتراك السائق
  /// (×2 لكل فشل متتالي، بحد أقصى ×16؛ و429 بيزوّد مرحلة).
  final Duration retryBackoffBase;

  final DateTime Function() _clock;

  bool get isDriverMode => driverSource == null;

  // ---------------- الحالة (كل واحدة مستقلة) ----------------
  final ValueNotifier<TrackingStatus> status =
      ValueNotifier<TrackingStatus>(TrackingStatus.starting);
  final ValueNotifier<GeoFix?> driver = ValueNotifier<GeoFix?>(null);
  final ValueNotifier<LatLng?> me = ValueNotifier<LatLng?>(null);
  final ValueNotifier<RouteResult?> route = ValueNotifier<RouteResult?>(null);
  final ValueNotifier<LocationIssue?> locationIssue =
      ValueNotifier<LocationIssue?>(null);

  /// false لما آخر طلب شبكة فشل بسبب الاتصال. بيرجع true أول نجاح.
  final ValueNotifier<bool> networkOk = ValueNotifier<bool>(true);

  /// true لما حساب المسار فشل (نحتفظ بآخر مسار معروف إن وُجد).
  final ValueNotifier<bool> routeUnavailable = ValueNotifier<bool>(false);
  final ValueNotifier<bool> routeLoading = ValueNotifier<bool>(false);

  // ---------------- داخلي ----------------
  StreamSubscription<GeoFix>? _posSub;
  StreamSubscription<GeoFix>? _driverSub;
  Timer? _ticker;
  Timer? _pendingTimer;

  bool _started = false;
  bool _disposed = false;
  bool _locationStarting = false;
  bool _inFlight = false;
  bool _routeFailed = false;
  bool _driverNeedsResubscribe = false;
  bool _posDead = false; // اشتراك GPS اتقفل (خطأ) ومحتاج إعادة اشتراك
  int _routeFailures = 0;
  DateTime? _routeRetryAt;
  int _driverFailures = 0;
  DateTime? _driverRetryAt;
  DateTime? _lastRequestAt;
  LatLng? _routeOrigin;

  /// مسافة خط مستقيم بين السائق والعميل (للعرض التقريبي لو المسار مش متاح).
  double? get straightDistanceMeters {
    final d = driver.value?.position;
    final c = customerLocation;
    if (d == null || c == null) return null;
    return distanceMeters(d, c);
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _ticker = Timer.periodic(tick, (_) => _onTick());
    if (!isDriverMode) {
      status.value = TrackingStatus.waitingForDriver;
      _listenDriver();
    }
    await _startLocation();
  }

  /// يعيد محاولة تحديد الموقع (بعد رفض صلاحية أو قفل GPS).
  Future<void> retryLocation() => _startLocation();

  /// لزر "موقعي": يرجّع الموقع الحالي (ويحاول يجهّز الصلاحية لو ناقصة).
  Future<LatLng?> locateMe() async {
    if (_disposed) return null;
    if (locationIssue.value != null || _posSub == null) {
      await _startLocation();
    }
    if (_disposed) return null;
    if (me.value == null) {
      final cur = await location.currentLatLng();
      if (_disposed) return null;
      if (cur != null) {
        _applyMyFix(GeoFix(position: cur, updatedAt: _clock()), publish: false);
      }
    }
    return me.value;
  }

  Future<void> openLocationSettings() async {
    final issue = locationIssue.value;
    if (issue == null) return;
    if (issue == LocationIssue.denied || issue == LocationIssue.unavailable) {
      await retryLocation();
    } else {
      await location.openSettings(issue);
    }
  }

  // ---------------- الموقع ----------------
  Future<void> _startLocation() async {
    if (_locationStarting || _disposed) return;
    _locationStarting = true;
    try {
      final issue = await location.ensureReady();
      if (_disposed) return;
      locationIssue.value = issue;
      if (issue != null) {
        await _posSub?.cancel();
        _posSub = null;
        _posDead = true; // الـ tick يعيد المحاولة لو المشكلة GPS مقفول/مؤقتة
        if (isDriverMode) status.value = TrackingStatus.locationBlocked;
        return;
      }
      if (isDriverMode && status.value == TrackingStatus.locationBlocked) {
        status.value = TrackingStatus.starting;
      }
      // اشتراك واحد فقط: بنلغي القديم قبل ما نعمل جديد.
      await _posSub?.cancel();
      if (_disposed) return;
      _posSub = location.watch().listen(
        _applyMyFix,
        onError: (Object e) {
          debugPrint('location stream error: $e');
          if (_disposed) return;
          _posDead = true; // cancelOnError: الاشتراك اتقفل — الـ tick يعيده
          locationIssue.value =
              e is LocationIssueException ? e.issue : LocationIssue.unavailable;
          if (isDriverMode) status.value = TrackingStatus.locationBlocked;
        },
        cancelOnError: true,
      );
      _posDead = false;
      final cur = await location.currentLatLng();
      if (_disposed) return;
      if (cur != null && me.value == null) {
        // أول نقطة للعرض بس: ممكن تكون last-known قديمة، فما بنبثهاش لـ Firestore.
        _applyMyFix(GeoFix(position: cur, updatedAt: _clock()), publish: false);
      }
    } finally {
      _locationStarting = false;
    }
  }

  void _applyMyFix(GeoFix f, {bool publish = true}) {
    if (_disposed) return;
    me.value = f.position;
    if (locationIssue.value != null) locationIssue.value = null;
    if (isDriverMode) {
      _onDriverFix(f);
      if (publish) publisher?.publish(f);
    }
  }

  // ---------------- السائق ----------------
  void _listenDriver() {
    final src = driverSource;
    if (src == null || _disposed) return;
    _driverSub?.cancel();
    _driverNeedsResubscribe = false;
    _driverSub = src.watch().listen(
      _onDriverFix,
      onError: (Object e) {
        debugPrint('driver stream error: $e');
        _driverFailures++;
        _driverRetryAt = _clock().add(_backoff(_driverFailures));
        _driverNeedsResubscribe = true; // هنعيد الاشتراك في أول tick بعد الـ backoff
      },
      cancelOnError: true,
    );
  }

  void _onDriverFix(GeoFix f) {
    if (_disposed) return;
    _driverFailures = 0;
    _driverRetryAt = null;
    final prev = driver.value;
    double? bearing = f.bearing;
    if (bearing == null &&
        prev != null &&
        distanceMeters(prev.position, f.position) >= 3) {
      bearing = bearingDegrees(prev.position, f.position);
    }
    bearing ??= prev?.bearing;
    driver.value = GeoFix(
      position: f.position,
      updatedAt: f.updatedAt,
      bearing: bearing,
    );
    status.value = TrackingStatus.live;
    _maybeReroute();
  }

  // ---------------- المسار ----------------
  void _onTick() {
    if (_disposed) return;
    final now = _clock();
    if (_driverNeedsResubscribe) {
      final at = _driverRetryAt;
      if (at == null || !now.isBefore(at)) _listenDriver();
    }
    // GPS اتقفل بسبب خطأ مؤقت أو GPS مقفول: نعيد الاشتراك تلقائيًا.
    // (الصلاحية المرفوضة محتاجة المستخدم، فمش بنكرر طلبها كل tick.)
    if (_posDead && !_locationStarting) {
      final i = locationIssue.value;
      if (i == LocationIssue.unavailable || i == LocationIssue.serviceDisabled) {
        _startLocation();
      }
    }
    if (_routeFailed) _maybeReroute(force: true);
  }

  Duration _backoff(int failures, {int extra = 0}) {
    final e = failures + extra - 1;
    final capped = e < 0 ? 0 : (e > 4 ? 4 : e);
    return retryBackoffBase * (1 << capped);
  }

  void _maybeReroute({bool force = false}) {
    if (_disposed) return;
    final d = driver.value;
    final dest = customerLocation;
    if (d == null || dest == null) return;

    final current = route.value;
    var need = force || current == null;
    if (!need) {
      final origin = _routeOrigin;
      final moved = origin == null ||
          distanceMeters(origin, d.position) >= rerouteDistanceMeters;
      final off =
          distanceToPolylineMeters(d.position, current!.points) > offRouteMeters;
      need = moved || off;
    }
    if (!need || _inFlight) return;
    final retryAt = _routeRetryAt;
    if (retryAt != null && _clock().isBefore(retryAt)) return; // backoff

    // Throttle: لو لسه بدري، نأجّل لطلب واحد في آخر الفترة.
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = _clock().difference(last);
      if (elapsed < minRouteInterval) {
        _pendingTimer ??= Timer(minRouteInterval - elapsed, () {
          _pendingTimer = null;
          _maybeReroute(force: force);
        });
        return;
      }
    }
    _requestRoute(d.position, dest);
  }

  Future<void> _requestRoute(LatLng from, LatLng to) async {
    _inFlight = true;
    _lastRequestAt = _clock();
    routeLoading.value = true;
    var succeeded = false;
    try {
      final res = await routing.getRoute(start: from, destination: to);
      if (_disposed) return;
      _routeOrigin = from;
      route.value = res;
      networkOk.value = true;
      routeUnavailable.value = false;
      _routeFailed = false;
      _routeFailures = 0;
      _routeRetryAt = null;
      succeeded = true;
    } on RoutingException catch (e) {
      debugPrint('routing failed: $e');
      if (_disposed) return;
      if (e.isConnectivity) networkOk.value = false;
      routeUnavailable.value = true; // آخر مسار معروف يفضل معروض
      _routeFailed = true;
      _routeFailures++;
      _routeRetryAt = _clock().add(_backoff(_routeFailures,
          extra: e.kind == RoutingFailure.rateLimited ? 1 : 0));
    } catch (e) {
      debugPrint('routing unexpected error: $e');
      if (_disposed) return;
      routeUnavailable.value = true;
      _routeFailed = true;
      _routeFailures++;
      _routeRetryAt = _clock().add(_backoff(_routeFailures));
    } finally {
      _inFlight = false;
      if (!_disposed) routeLoading.value = false;
    }
    // السائق ممكن يكون اتحرك أثناء انتظار الرد: الرد اتحسب من نقطة قديمة.
    // نفحص تاني بعد ما _inFlight اتقفل (الـ throttle بيحكم التوقيت).
    if (succeeded && !_disposed) _maybeReroute();
  }

  // ---------------- التنظيف ----------------
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _pendingTimer?.cancel();
    _posSub?.cancel();
    _driverSub?.cancel();
    publisher?.close();
    _ticker = null;
    _pendingTimer = null;
    _posSub = null;
    _driverSub = null;
    status.dispose();
    driver.dispose();
    me.dispose();
    route.dispose();
    locationIssue.dispose();
    networkOk.dispose();
    routeUnavailable.dispose();
    routeLoading.dispose();
  }
}
