import 'dart:math';

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/village_picker.dart';
import '../../widgets/map_location_picker.dart';
import 'order_tracking_screen.dart';

/// شاشة طلب مشوار تاكسي جديد.
/// ملحوظة: اختيار الموقع من على الخريطة هيتضاف في مرحلة لاحقة (flutter_map)؛
/// حاليًا بندخل العنوان كتابةً زي نموذج مبسّط، وبنحسب سعر تقريبي محلي.
class NewTaxiOrderScreen extends StatefulWidget {
  final AppUser user;
  const NewTaxiOrderScreen({super.key, required this.user});

  @override
  State<NewTaxiOrderScreen> createState() => _NewTaxiOrderScreenState();
}

class _NewTaxiOrderScreenState extends State<NewTaxiOrderScreen> {
  final pickupCtrl = TextEditingController();
  final dropoffCtrl = TextEditingController();
  VillageData? pickupVillage;
  VillageData? dropoffVillage;
  PickedLocation? pickupMapLocation;
  PickedLocation? dropoffMapLocation;
  VehicleType vehicle = VehicleType.TOKTOK;
  PaymentMethod payment = PaymentMethod.CASH;
  bool loading = false;

  // نفس منطق التسعير الأساسي من constants.ts (سعر أساسي + سعر لكل كم)
  double get _distanceKm {
    if ((_pickupLat == 0 && _pickupLng == 0) || (_dropoffLat == 0 && _dropoffLng == 0)) {
      return 3; // تقدير افتراضي لحد ما يتحدد الموقعين
    }
    const r = 6371.0; // نصف قطر الأرض بالكيلومتر
    final dLat = _deg2rad(_dropoffLat - _pickupLat);
    final dLng = _deg2rad(_dropoffLng - _pickupLng);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(_pickupLat)) * cos(_deg2rad(_dropoffLat)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final dist = r * c;
    return dist < 1 ? 1 : dist;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  double get estimatedPrice {
    const base = 10.0;
    const perKm = 3.0;
    const multiplier = {
      VehicleType.TOKTOK: 1.0,
      VehicleType.MOTORCYCLE: 0.8,
      VehicleType.CAR: 1.6,
    };
    return (base + perKm * _distanceKm) * (multiplier[vehicle] ?? 1.0);
  }

  Future<void> _pickPickupVillage() async {
    final v = await pickVillage(context);
    if (v != null) {
      setState(() {
        pickupVillage = v;
        pickupMapLocation = null;
        pickupCtrl.text = v.name;
      });
    }
  }

  Future<void> _pickDropoffVillage() async {
    final v = await pickVillage(context);
    if (v != null) {
      setState(() {
        dropoffVillage = v;
        dropoffMapLocation = null;
        dropoffCtrl.text = v.name;
      });
    }
  }

  Future<void> _pickPickupOnMap() async {
    final loc = await pickLocationOnMap(context, initialAddress: pickupCtrl.text);
    if (loc != null) {
      setState(() {
        pickupMapLocation = loc;
        pickupVillage = null;
        pickupCtrl.text = loc.address;
      });
    }
  }

  Future<void> _pickDropoffOnMap() async {
    final loc = await pickLocationOnMap(context, initialAddress: dropoffCtrl.text);
    if (loc != null) {
      setState(() {
        dropoffMapLocation = loc;
        dropoffVillage = null;
        dropoffCtrl.text = loc.address;
      });
    }
  }

  double get _pickupLat => pickupMapLocation?.lat ?? pickupVillage?.lat ?? 0;
  double get _pickupLng => pickupMapLocation?.lng ?? pickupVillage?.lng ?? 0;
  double get _dropoffLat => dropoffMapLocation?.lat ?? dropoffVillage?.lat ?? 0;
  double get _dropoffLng => dropoffMapLocation?.lng ?? dropoffVillage?.lng ?? 0;

  Future<void> _confirm() async {
    if (pickupCtrl.text.trim().isEmpty || dropoffCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('من فضلك اكتب نقطة الانطلاق والوجهة')));
      return;
    }
    if (payment == PaymentMethod.WALLET && widget.user.wallet.balance < estimatedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('رصيد محفظتك غير كافٍ لإتمام هذا الطلب، اختر الدفع كاش أو اشحن رصيدك')));
      return;
    }
    setState(() => loading = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final order = Order(
        id: '',
        customerId: widget.user.id,
        customerPhone: widget.user.phone,
        operatorId: widget.user.operatorId ?? '',
        zoneId: dropoffVillage != null
            ? districtIdOfVillage(dropoffVillage!.id)
            : (widget.user.zoneId ?? ''),
        category: OrderCategory.TAXI,
        pickup: OrderLocation(
          address: pickupCtrl.text.trim(),
          lat: _pickupLat,
          lng: _pickupLng,
          villageName: pickupVillage?.name,
        ),
        dropoff: OrderLocation(
          address: dropoffCtrl.text.trim(),
          lat: _dropoffLat,
          lng: _dropoffLng,
          villageName: dropoffVillage?.name,
        ),
        status: OrderStatus.PENDING,
        statusHistory: [
          StatusHistoryItem(status: OrderStatus.PENDING, changedAt: now, changedBy: widget.user.id)
        ],
        updatedAt: now,
        price: estimatedPrice,
        distance: _distanceKm,
        commission: estimatedPrice * 0.15,
        createdAt: now,
        paymentMethod: payment,
        requestedVehicleType: vehicle,
      );
      final ref = await FirebaseService.instance.createOrder(order);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: ref.id, user: widget.user)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حصل خطأ أثناء إرسال الطلب: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب مشوار')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: pickupCtrl,
              decoration: InputDecoration(
                labelText: 'من (نقطة الانطلاق)',
                prefixIcon: const Icon(Icons.my_location, color: AppColors.primary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                      tooltip: 'حدد على الخريطة',
                      onPressed: _pickPickupOnMap,
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt, color: AppColors.primary),
                      tooltip: 'اختر من القرى',
                      onPressed: _pickPickupVillage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: dropoffCtrl,
              decoration: InputDecoration(
                labelText: 'إلى (الوجهة)',
                prefixIcon: const Icon(Icons.location_on, color: Colors.redAccent),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                      tooltip: 'حدد على الخريطة',
                      onPressed: _pickDropoffOnMap,
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt, color: AppColors.primary),
                      tooltip: 'اختر من القرى',
                      onPressed: _pickDropoffVillage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('نوع المركبة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: VehicleType.values.map((v) {
                final labels = {
                  VehicleType.TOKTOK: 'توكتوك',
                  VehicleType.MOTORCYCLE: 'موتوسيكل',
                  VehicleType.CAR: 'عربية',
                };
                return ChoiceChip(
                  label: Text(labels[v]!),
                  selected: vehicle == v,
                  onSelected: (_) => setState(() => vehicle = v),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: vehicle == v ? Colors.white : Colors.black87),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('طريقة الدفع', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<PaymentMethod>(
                    value: PaymentMethod.CASH,
                    groupValue: payment,
                    title: const Text('كاش'),
                    onChanged: (v) => setState(() => payment = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<PaymentMethod>(
                    value: PaymentMethod.WALLET,
                    groupValue: payment,
                    title: const Text('المحفظة'),
                    onChanged: (v) => setState(() => payment = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              color: AppColors.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('السعر التقريبي', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${estimatedPrice.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.primaryDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _confirm,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('اطلب الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
