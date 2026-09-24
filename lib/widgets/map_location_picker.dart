import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String address;
  const PickedLocation({required this.lat, required this.lng, required this.address});
}

/// يفتح خريطة تفاعلية (OpenStreetMap) عشان المستخدم يحدد نقطة بالظبط
/// بتحريك الخريطة تحت دبوس ثابت في النص، بدل ما يكتب العنوان يدويًا بس.
Future<PickedLocation?> pickLocationOnMap(BuildContext context, {String? initialAddress}) {
  return Navigator.push<PickedLocation>(
    context,
    MaterialPageRoute(builder: (_) => MapLocationPickerScreen(initialAddress: initialAddress)),
  );
}

class MapLocationPickerScreen extends StatefulWidget {
  final String? initialAddress;
  const MapLocationPickerScreen({super.key, this.initialAddress});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final mapController = MapController();
  // مركز أشمون كنقطة بداية افتراضية
  ll.LatLng center = const ll.LatLng(30.2931, 30.9863);
  final addressCtrl = TextEditingController();
  bool locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) addressCtrl.text = widget.initialAddress!;
  }

  Future<void> _useMyLocation() async {
    setState(() => locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final newCenter = ll.LatLng(pos.latitude, pos.longitude);
      setState(() => center = newCenter);
      mapController.move(newCenter, 16);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر تحديد موقعك الحالي')));
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _confirm() {
    final addr = addressCtrl.text.trim().isEmpty
        ? 'موقع محدد على الخريطة (${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)})'
        : addressCtrl.text.trim();
    Navigator.pop(
      context,
      PickedLocation(lat: center.latitude, lng: center.longitude, address: addr),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حدد الموقع على الخريطة')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) center = pos.center!;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wasalah.app',
              ),
            ],
          ),
          // دبوس ثابت في نص الشاشة - المستخدم بيحرك الخريطة تحته
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on, size: 46, color: AppColors.primary),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: FloatingActionButton.small(
              heroTag: 'locate-me',
              onPressed: locating ? null : _useMyLocation,
              backgroundColor: Colors.white,
              child: locating
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      hintText: 'وصف العنوان (اختياري - رقم عمارة، علامة مميزة...)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد هذا الموقع'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
