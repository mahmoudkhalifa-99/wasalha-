import 'dart:math';

import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/village_picker.dart';
import '../../../widgets/map_location_picker.dart';
import '../order_tracking_screen.dart';

class FoodCheckoutScreen extends StatefulWidget {
  final Restaurant restaurant;
  final List<CartItem> cart;
  final AppUser user;
  const FoodCheckoutScreen(
      {super.key, required this.restaurant, required this.cart, required this.user});

  @override
  State<FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<FoodCheckoutScreen> {
  final addressCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  VillageData? dropoffVillage;
  PickedLocation? dropoffMapLocation;
  PaymentMethod payment = PaymentMethod.CASH;
  bool loading = false;

  // نفس منطق تسعير توصيل الأكل بالويب: سعر ثابت لو جوه نفس القرية، وإلا
  // مسافة × سعر الكيلومتر بحد أدنى معيّن (constants.ts → DEFAULT_PRICING)
  static const double _sameVillagePrice = 15;
  static const double _perKmPrice = 3;
  static const double _minPrice = 20;

  double get _dropLat => dropoffMapLocation?.lat ?? dropoffVillage?.lat ?? 0;
  double get _dropLng => dropoffMapLocation?.lng ?? dropoffVillage?.lng ?? 0;

  double get _distanceKm {
    if (_dropLat == 0 && _dropLng == 0) return 0;
    const r = 6371.0;
    final dLat = _deg2rad(_dropLat - widget.restaurant.lat);
    final dLng = _deg2rad(_dropLng - widget.restaurant.lng);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(widget.restaurant.lat)) *
            cos(_deg2rad(_dropLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  double get deliveryFee {
    final isSameVillage = dropoffVillage != null && dropoffVillage!.name == widget.restaurant.address;
    if (isSameVillage) return _sameVillagePrice;
    if (_dropLat == 0 && _dropLng == 0) return _minPrice; // لسه محددش موقع
    final calc = (_distanceKm * _perKmPrice).roundToDouble();
    return calc < _minPrice ? _minPrice : calc;
  }

  Future<void> _pickDropoffVillage() async {
    final v = await pickVillage(context);
    if (v != null) {
      setState(() {
        dropoffVillage = v;
        dropoffMapLocation = null;
        addressCtrl.text = v.name;
      });
    }
  }

  Future<void> _pickDropoffOnMap() async {
    final loc = await pickLocationOnMap(context, initialAddress: addressCtrl.text);
    if (loc != null) {
      setState(() {
        dropoffMapLocation = loc;
        dropoffVillage = null;
        addressCtrl.text = loc.address;
      });
    }
  }

  double get subtotal => widget.cart.fold(0, (sum, i) => sum + i.price * i.quantity);
  double get total => subtotal + deliveryFee;

  Future<void> _placeOrder() async {
    if (addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('من فضلك اكتب عنوان التوصيل')));
      return;
    }
    if (payment == PaymentMethod.WALLET && widget.user.wallet.balance < total) {
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
        category: OrderCategory.FOOD,
        pickup: OrderLocation(address: widget.restaurant.name, lat: widget.restaurant.lat, lng: widget.restaurant.lng),
        dropoff: OrderLocation(
          address: addressCtrl.text.trim(),
          lat: dropoffMapLocation?.lat ?? dropoffVillage?.lat ?? 0,
          lng: dropoffMapLocation?.lng ?? dropoffVillage?.lng ?? 0,
          villageName: dropoffVillage?.name,
        ),
        status: OrderStatus.PENDING,
        statusHistory: [
          StatusHistoryItem(status: OrderStatus.PENDING, changedAt: now, changedBy: widget.user.id)
        ],
        updatedAt: now,
        price: total,
        distance: _dropLat == 0 ? 3 : _distanceKm,
        commission: total * 0.15,
        createdAt: now,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        paymentMethod: payment,
        requestedVehicleType: VehicleType.MOTORCYCLE,
        foodItems: widget.cart,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
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
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.restaurant.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const Divider(height: 20),
                ...widget.cart.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${i.name} × ${i.quantity}'),
                          Text('${(i.price * i.quantity).toStringAsFixed(0)} ج.م'),
                        ],
                      ),
                    )),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رسوم التوصيل'),
                    Text('${deliveryFee.toStringAsFixed(0)} ج.م'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('${total.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: addressCtrl,
            decoration: InputDecoration(
              labelText: 'عنوان التوصيل',
              prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
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
          const SizedBox(height: 14),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظات للطلب (اختياري)'),
          ),
          const SizedBox(height: 20),
          Text('طريقة الدفع', style: Theme.of(context).textTheme.titleSmall),
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
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : _placeOrder,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('تأكيد الطلب — ${total.toStringAsFixed(0)} ج.م'),
          ),
        ],
      ),
    );
  }
}
