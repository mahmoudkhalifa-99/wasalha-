import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/osrm_routing_service.dart';
import '../../../core/map/routing_service.dart';
import '../../../theme/app_colors.dart';
import '../controllers/tracking_controller.dart';
import '../models/tracking_models.dart';
import '../services/driver_location_source.dart';
import '../services/location_service.dart';
import '../widgets/tracking_info_card.dart';
import '../widgets/tracking_map.dart';

/// شاشة "الخريطة والتتبع". مستقلة تمامًا: بتاخد بياناتها من الـ constructor
/// وبتنشئ Controller خاص بيها وتقفله في dispose (GPS، Timers، Streams).
///
/// مثال الاستخدام (مش متوصّل بأي شاشة حالية لحد دلوقتي):
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => TrackingScreen(
///     role: TrackingRole.customerWatchingDriver,
///     driverId: order.driverId,
///     customerLocation: LatLng(order.dropoff.lat, order.dropoff.lng),
///   ),
/// ));
/// ```
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.role,
    this.driverId,
    this.customerLocation,
    this.title = 'الخريطة والتتبع',
    this.routingService,
    this.locationService,
    this.controller,
  });

  final TrackingRole role;

  /// العميل: id السائق المراد تتبعه (users/{driverId}). مطلوب في وضع العميل.
  /// السائق: id حسابه عشان يبث موقعه (اختياري؛ null = عرض بدون بث).
  final String? driverId;

  /// موقع العميل/الوجهة.
  final LatLng? customerLocation;
  final String title;

  /// للاستبدال (اختبارات أو مزوّد طرق آخر).
  final RoutingService? routingService;
  final LocationService? locationService;

  /// لو اتمرر Controller جاهز، الشاشة ما بتقفلوش (صاحبه هو المسؤول).
  final TrackingController? controller;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  late final TrackingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
    } else {
      _ownsController = true;
      _controller = _buildController();
    }
    _controller.start();
  }

  TrackingController _buildController() {
    final isDriver = widget.role == TrackingRole.driverSharing;
    final id = widget.driverId;
    return TrackingController(
      location: widget.locationService ?? const GeolocatorLocationService(),
      routing: widget.routingService ?? OsrmRoutingService(),
      customerLocation: widget.customerLocation,
      driverSource: (!isDriver && id != null)
          ? FirestoreDriverLocationSource(id)
          : (!isDriver ? _EmptyDriverSource() : null),
      publisher: (isDriver && id != null) ? DriverLocationPublisher(id) : null,
    );
  }

  // لما المستخدم يرجع من إعدادات الموقع/الصلاحيات، نعيد المحاولة تلقائيًا.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _controller.locationIssue.value != null) {
      _controller.retryLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgLight,
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: C.slate800)),
        backgroundColor: C.white,
        surfaceTintColor: C.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: C.slate800),
      ),
      body: Column(
        children: [
          Expanded(child: TrackingMap(controller: _controller)),
          TrackingInfoCard(controller: _controller),
        ],
      ),
    );
  }
}

/// وضع العميل بدون driverId: مفيش سائق نتابعه لسه (الخريطة بتشتغل عادي).
class _EmptyDriverSource implements DriverLocationSource {
  @override
  Stream<GeoFix> watch() => const Stream<GeoFix>.empty();
}
