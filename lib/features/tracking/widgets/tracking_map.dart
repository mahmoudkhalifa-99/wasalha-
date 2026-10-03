import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map_config.dart';
import '../../../core/map/routing_service.dart';
import '../../../theme/app_colors.dart';
import '../controllers/tracking_controller.dart';
import '../models/tracking_models.dart';
import 'animated_driver_marker.dart';

/// خريطة التتبع. instance واحد من FlutterMap طول عمر الـ State، والتحديثات
/// بتوصل لطبقات صغيرة عن طريق ValueListenableBuilder (مفيش rebuild للخريطة).
class TrackingMap extends StatefulWidget {
  const TrackingMap({super.key, required this.controller});
  final TrackingController controller;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  final MapController _map = MapController();
  bool _ready = false;
  bool _autoDone = false;
  bool _centeredOnMe = false;

  TrackingController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.driver.addListener(_autoCamera);
    _c.me.addListener(_autoCamera);
  }

  @override
  void dispose() {
    _c.driver.removeListener(_autoCamera);
    _c.me.removeListener(_autoCamera);
    _map.dispose();
    super.dispose();
  }

  // الكاميرا بتتظبط أوتوماتيك مرة واحدة بس، بعدها المستخدم حر يحرّك الخريطة.
  void _autoCamera() {
    if (!_ready || _autoDone) return;
    final d = _c.driver.value?.position;
    final cu = _c.customerLocation;
    final m = _c.me.value;
    if (d != null && cu != null) {
      _fit([d, cu]);
      _autoDone = true;
    } else if (cu == null && (d ?? m) != null) {
      _move((d ?? m)!, 16);
      _autoDone = true;
    } else if (!_centeredOnMe && m != null && d == null) {
      _move(m, 15);
      _centeredOnMe = true;
    }
  }

  void _move(LatLng p, double zoom) {
    try {
      _map.move(p, zoom);
    } catch (_) {
      // الخريطة لسه مش جاهزة — هنحاول مع التحديث الجاي.
    }
  }

  void _fit(List<LatLng> pts) {
    if (pts.length < 2) return;
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(60),
          maxZoom: 17,
        ),
      );
    } catch (_) {}
  }

  Future<void> _onMyLocation() async {
    final p = await _c.locateMe();
    if (!mounted || p == null) return;
    _move(p, 16);
  }

  void _onFitAll() {
    final d = _c.driver.value?.position;
    final cu = _c.customerLocation;
    final m = _c.me.value;
    final pts = <LatLng>[];
    if (d != null) pts.add(d);
    if (cu != null) pts.add(cu);
    if (pts.length < 2 && m != null) pts.add(m);
    if (pts.length >= 2) {
      _fit(pts);
    } else if (pts.length == 1) {
      _move(pts.first, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _c.customerLocation;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: customer ?? MapConfig.defaultCenter,
            initialZoom: MapConfig.defaultZoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            onMapReady: () {
              _ready = true;
              _autoCamera();
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrlTemplate,
              subdomains: MapConfig.tileSubdomains,
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 19,
              userAgentPackageName: MapConfig.userAgentPackageName,
            ),
            ValueListenableBuilder<RouteResult?>(
              valueListenable: _c.route,
              builder: (context, r, _) {
                if (r == null || r.points.length < 2) {
                  return const SizedBox.shrink();
                }
                return PolylineLayer(polylines: [
                  Polyline(
                    points: r.points,
                    color: C.emerald500.withAlpha(200),
                    strokeWidth: 6,
                  ),
                ]);
              },
            ),
            if (customer != null)
              MarkerLayer(rotate: false, markers: [
                Marker(
                  point: customer,
                  width: 44,
                  height: 44,
                  child: const _PinIcon(icon: Icons.home_rounded, color: C.blue600),
                ),
              ]),
            if (!_c.isDriverMode)
              ValueListenableBuilder<LatLng?>(
                valueListenable: _c.me,
                builder: (context, p, _) {
                  if (p == null) return const SizedBox.shrink();
                  return MarkerLayer(rotate: false, markers: [
                    Marker(
                      point: p,
                      width: 24,
                      height: 24,
                      child: const _MyLocationDot(),
                    ),
                  ]);
                },
              ),
            ValueListenableBuilder<GeoFix?>(
              valueListenable: _c.driver,
              builder: (context, fix, _) => AnimatedDriverMarkerLayer(fix: fix),
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              showFlutterMapAttribution: false,
              attributions: [TextSourceAttribution(MapConfig.attribution)],
            ),
          ],
        ),
        PositionedDirectional(
          end: 12,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: Icons.fit_screen_rounded,
                tooltip: 'عرض الطريق كاملًا',
                onTap: _onFitAll,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'موقعي',
                onTap: _onMyLocation,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: C.white,
        elevation: 3,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: C.slate800),
          ),
        ),
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.blue600,
        shape: BoxShape.circle,
        border: Border.all(color: C.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}
