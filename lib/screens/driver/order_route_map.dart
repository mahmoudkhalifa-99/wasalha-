import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// معاينة خريطة مصغّرة لموقعي الاستلام والتسليم + موقع الكابتن الحالي -
/// مقابلة مبسّطة لخريطة Leaflet الحيّة في CourierDashboard.tsx بنسخة الويب
/// (بدون بث موقع لحظي عبر Firestore حاليًا، اكتفاءً بموقع الكابتن الآني + زر ملاحة خارجي)
class OrderRouteMap extends StatefulWidget {
  final Order order;
  const OrderRouteMap({super.key, required this.order});

  @override
  State<OrderRouteMap> createState() => _OrderRouteMapState();
}

class _OrderRouteMapState extends State<OrderRouteMap> {
  ll.LatLng? driverPos;
  bool loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadDriverLocation();
  }

  Future<void> _loadDriverLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        driverPos = ll.LatLng(pos.latitude, pos.longitude);
        loadingLocation = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = ll.LatLng(widget.order.pickup.lat, widget.order.pickup.lng);
    final dropoff = ll.LatLng(widget.order.dropoff.lat, widget.order.dropoff.lng);
    final centerLat = (pickup.latitude + dropoff.latitude) / 2;
    final centerLng = (pickup.longitude + dropoff.longitude) / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: ll.LatLng(centerLat, centerLng),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wasalah.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(points: [pickup, dropoff], strokeWidth: 4, color: AppColors.primary),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: pickup,
                    width: 40,
                    height: 40,
                    child: const _PinIcon(emoji: '🏪', color: Color(0xFFE11D48)),
                  ),
                  Marker(
                    point: dropoff,
                    width: 40,
                    height: 40,
                    child: const _PinIcon(emoji: '🏁', color: AppColors.primary),
                  ),
                  if (driverPos != null)
                    Marker(
                      point: driverPos!,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(emoji: '🛵', color: Color(0xFF2563EB)),
                    ),
                ]),
              ],
            ),
            if (loadingLocation)
              const Positioned(
                top: 8,
                left: 8,
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  final String emoji;
  final Color color;
  const _PinIcon({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}
