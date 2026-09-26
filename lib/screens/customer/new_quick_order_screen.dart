import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/village_picker.dart';
import '../../widgets/map_location_picker.dart';
import 'order_tracking_screen.dart';

/// شاشة طلب موحّدة للفئات اللي معندهاش كتالوج منتجات (صيدلية / سوبر ماركت / طرد).
/// العميل بيكتب طلبه بالتفصيل، وسعر التوصيل بيتحدد كرسوم ثابتة، وتكلفة
/// المنتجات نفسها بتتدفع كاش للمحل وقت الاستلام - زي أغلب تطبيقات التوصيل المشابهة.
class NewQuickOrderScreen extends StatefulWidget {
  final AppUser user;
  final OrderCategory category;
  const NewQuickOrderScreen({super.key, required this.user, required this.category});

  @override
  State<NewQuickOrderScreen> createState() => _NewQuickOrderScreenState();
}

class _NewQuickOrderScreenState extends State<NewQuickOrderScreen> {
  final storeCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final detailsCtrl = TextEditingController();
  VillageData? dropoffVillage;
  PickedLocation? dropoffMapLocation;
  PaymentMethod payment = PaymentMethod.CASH;
  bool loading = false;

  _CategoryCopy get _copy {
    switch (widget.category) {
      case OrderCategory.PHARMACY:
        return const _CategoryCopy(
          title: 'طلب من الصيدلية',
          storeLabel: 'اسم الصيدلية أو مكانها',
          detailsLabel: 'اكتب الأدوية أو المنتجات المطلوبة بالتفصيل',
          icon: Icons.local_pharmacy,
          deliveryFee: 12,
        );
      case OrderCategory.GROCERY:
        return const _CategoryCopy(
          title: 'طلب من السوبر ماركت',
          storeLabel: 'اسم السوبر ماركت أو مكانه',
          detailsLabel: 'اكتب المنتجات المطلوبة بالتفصيل',
          icon: Icons.local_grocery_store,
          deliveryFee: 15,
        );
      case OrderCategory.PARCEL:
        return const _CategoryCopy(
          title: 'إرسال طرد',
          storeLabel: 'من (مكان استلام الطرد)',
          detailsLabel: 'وصف الطرد (حجمه، نوعه، أي تعليمات)',
          icon: Icons.local_shipping,
          deliveryFee: 18,
        );
      default:
        return const _CategoryCopy(
          title: 'طلب جديد',
          storeLabel: 'من',
          detailsLabel: 'تفاصيل الطلب',
          icon: Icons.shopping_bag,
          deliveryFee: 12,
        );
    }
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

  Future<void> _confirm() async {
    final copy = _copy;
    if (storeCtrl.text.trim().isEmpty ||
        addressCtrl.text.trim().isEmpty ||
        detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('من فضلك املأ كل الحقول')));
      return;
    }
    if (payment == PaymentMethod.WALLET && widget.user.wallet.balance < copy.deliveryFee) {
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
        category: widget.category,
        pickup: OrderLocation(address: storeCtrl.text.trim(), lat: 0, lng: 0),
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
        price: copy.deliveryFee,
        distance: 3,
        commission: copy.deliveryFee * 0.15,
        createdAt: now,
        paymentMethod: payment,
        requestedVehicleType: VehicleType.MOTORCYCLE,
        specialRequest: detailsCtrl.text.trim(),
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
    final copy = _copy;
    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(copy.icon, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هنبعتلك كابتن يستلم طلبك ويوصله لحد عندك. تكلفة المنتجات بتتدفع كاش وقت الاستلام.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: storeCtrl,
              decoration: InputDecoration(
                labelText: copy.storeLabel,
                prefixIcon: const Icon(Icons.storefront, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                labelText: 'إلى (عنوان التسليم)',
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
            const SizedBox(height: 14),
            TextField(
              controller: detailsCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: copy.detailsLabel, alignLabelWithHint: true),
            ),
            const SizedBox(height: 20),
            Text('طريقة دفع رسوم التوصيل', style: Theme.of(context).textTheme.titleSmall),
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
                    const Text('رسوم التوصيل', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${copy.deliveryFee.toStringAsFixed(0)} ج.م',
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

class _CategoryCopy {
  final String title;
  final String storeLabel;
  final String detailsLabel;
  final IconData icon;
  final double deliveryFee;
  const _CategoryCopy({
    required this.title,
    required this.storeLabel,
    required this.detailsLabel,
    required this.icon,
    required this.deliveryFee,
  });
}
