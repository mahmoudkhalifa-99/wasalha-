import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../data/menofia_data.dart';
import 'food/restaurants_list_screen.dart';
import 'new_quick_order_screen.dart';
import '../notifications_screen.dart';
import '../ai_assistant_screen.dart';
import '../../services/push_service.dart';
import '../../widgets/profile_avatar.dart';
import '../support_screen.dart';
import 'order_tracking_screen.dart';
import 'wallet_screen.dart';

class CustomerDashboard extends StatefulWidget {
  final AppUser user;
  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    PushService.instance.init(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(user: widget.user),
      _ActivityTab(user: widget.user),
      _ProfileTab(user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلًا، ${widget.user.name}'),
        actions: [
          StreamBuilder<int>(
            stream: FirebaseService.instance.unreadNotificationsCount(widget.user.id, role: widget.user.role),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotificationsScreen(userId: widget.user.id, role: widget.user.role)),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text('$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: pages[tab],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
        ),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.auto_awesome, color: AppColors.primary),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'نشاطي'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final AppUser user;
  const _HomeTab({required this.user});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const _categories = [
    (OrderCategory.PHARMACY, 'صيدلية', 'روشتة وعلاج', Icons.local_pharmacy),
    (OrderCategory.FOOD, 'مطاعم', 'أكل جاهز', Icons.restaurant),
    (OrderCategory.TAXI, 'مشوار', 'توصيل ركاب', Icons.two_wheeler),
    (OrderCategory.GROCERY, 'سوبر ماركت', 'بقالة ومنتجات', Icons.local_grocery_store),
    (OrderCategory.PARCEL, 'طرد', 'استلام وتسليم', Icons.local_shipping),
  ];

  OrderCategory selected = OrderCategory.TAXI;

  // -- نموذج طلب المشوار المدمج في الرئيسية --
  DistrictData? pickupDistrict;
  VillageData? pickupVillage;
  DistrictData? dropoffDistrict;
  VillageData? dropoffVillage;
  final pickupDetailCtrl = TextEditingController();
  final dropoffDetailCtrl = TextEditingController();
  VehicleType vehicle = VehicleType.MOTORCYCLE;
  bool loading = false;

  @override
  void dispose() {
    pickupDetailCtrl.dispose();
    dropoffDetailCtrl.dispose();
    super.dispose();
  }

  double get _distanceKm {
    final pLat = pickupVillage?.lat ?? 0, pLng = pickupVillage?.lng ?? 0;
    final dLatV = dropoffVillage?.lat ?? 0, dLngV = dropoffVillage?.lng ?? 0;
    if ((pLat == 0 && pLng == 0) || (dLatV == 0 && dLngV == 0)) return 3;
    const r = 6371.0;
    final dLat = (dLatV - pLat) * (pi / 180);
    final dLng = (dLngV - pLng) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(pLat * pi / 180) * cos(dLatV * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final dist = r * c;
    return dist < 1 ? 1 : dist;
  }

  double get _estimatedPrice {
    const base = 10.0, perKm = 3.0;
    const multiplier = {VehicleType.TOKTOK: 1.0, VehicleType.MOTORCYCLE: 0.8, VehicleType.CAR: 1.6};
    return (base + perKm * _distanceKm) * (multiplier[vehicle] ?? 1.0);
  }

  Future<void> _confirmTaxiOrder() async {
    if (pickupVillage == null || dropoffVillage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('من فضلك اختر نقطة الانطلاق والوصول')));
      return;
    }
    setState(() => loading = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pickupAddress =
          [pickupVillage!.name, pickupDetailCtrl.text.trim()].where((s) => s.isNotEmpty).join(' - ');
      final dropoffAddress = [dropoffVillage!.name, dropoffDetailCtrl.text.trim()]
          .where((s) => s.isNotEmpty)
          .join(' - ');
      final order = Order(
        id: '',
        customerId: widget.user.id,
        customerPhone: widget.user.phone,
        operatorId: widget.user.operatorId ?? '',
        zoneId: dropoffDistrict?.id ?? widget.user.zoneId ?? '',
        category: OrderCategory.TAXI,
        pickup: OrderLocation(
          address: pickupAddress,
          lat: pickupVillage!.lat,
          lng: pickupVillage!.lng,
          villageName: pickupVillage!.name,
        ),
        dropoff: OrderLocation(
          address: dropoffAddress,
          lat: dropoffVillage!.lat,
          lng: dropoffVillage!.lng,
          villageName: dropoffVillage!.name,
        ),
        status: OrderStatus.PENDING,
        statusHistory: [
          StatusHistoryItem(status: OrderStatus.PENDING, changedAt: now, changedBy: widget.user.id)
        ],
        updatedAt: now,
        price: _estimatedPrice,
        distance: _distanceKm,
        commission: _estimatedPrice * 0.15,
        createdAt: now,
        paymentMethod: PaymentMethod.CASH,
        requestedVehicleType: vehicle,
      );
      final ref = await FirebaseService.instance.createOrder(order);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: ref.id, user: widget.user)),
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

  void _onCategoryTap(OrderCategory category) {
    if (category == OrderCategory.TAXI) {
      setState(() => selected = category);
      return;
    }
    setState(() => selected = category);
    if (category == OrderCategory.FOOD) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantsListScreen(user: widget.user)));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewQuickOrderScreen(user: widget.user, category: category)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: FirebaseService.instance.activeOrdersForCustomer(widget.user.id),
      builder: (context, snap) {
        final active = snap.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active.isNotEmpty) ...[
                Text('طلب جاري حاليًا',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...active.map((o) => _ActiveOrderCard(order: o, user: widget.user)),
                const SizedBox(height: 20),
              ],
              StreamBuilder<List<Ad>>(
                stream: FirebaseService.instance.activeAdsStream(),
                builder: (context, adsSnap) {
                  final ads = adsSnap.data ?? const [];
                  if (ads.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _AdsSlider(ads: ads),
                  );
                },
              ),
              Text('إيه اللي محتاجه دلوقتي؟',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final c = _categories[i];
                    return _ServiceCard(
                      selected: selected == c.$1,
                      label: c.$2,
                      subtitle: c.$3,
                      icon: c.$4,
                      onTap: () => _onCategoryTap(c.$1),
                    );
                  },
                ),
              ),
              if (selected == OrderCategory.TAXI) ...[
                const SizedBox(height: 20),
                _LocationSection(
                  color: AppColors.primary,
                  icon: Icons.location_on,
                  title: 'نقطة الانطلاق (الركوب)',
                  subtitle: 'من أين ستبدأ الرحلة؟',
                  district: pickupDistrict,
                  village: pickupVillage,
                  detailCtrl: pickupDetailCtrl,
                  onDistrictChanged: (d) => setState(() {
                    pickupDistrict = d;
                    pickupVillage = null;
                  }),
                  onVillageChanged: (v) => setState(() => pickupVillage = v),
                ),
                const SizedBox(height: 14),
                _LocationSection(
                  color: Colors.redAccent,
                  icon: Icons.flag,
                  title: 'نقطة الوصول (النزول)',
                  subtitle: 'إلى أين تريد الذهاب؟',
                  district: dropoffDistrict,
                  village: dropoffVillage,
                  detailCtrl: dropoffDetailCtrl,
                  onDistrictChanged: (d) => setState(() {
                    dropoffDistrict = d;
                    dropoffVillage = null;
                  }),
                  onVillageChanged: (v) => setState(() => dropoffVillage = v),
                ),
                const SizedBox(height: 18),
                Text('نوع المركبة المفضلة (أسطول وصلها)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _VehicleCard(
                        selected: vehicle == VehicleType.MOTORCYCLE,
                        icon: Icons.two_wheeler,
                        label: 'موتوسيكل',
                        subtitle: 'فرد واحد فوري',
                        onTap: () => setState(() => vehicle = VehicleType.MOTORCYCLE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _VehicleCard(
                        selected: vehicle == VehicleType.CAR,
                        icon: Icons.directions_car,
                        label: 'سيارة',
                        subtitle: 'عالي ومريح',
                        onTap: () => setState(() => vehicle = VehicleType.CAR),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _VehicleCard(
                        selected: vehicle == VehicleType.TOKTOK,
                        icon: Icons.electric_rickshaw,
                        label: 'توكتوك',
                        subtitle: 'اقتصادي وسريع',
                        onTap: () => setState(() => vehicle = VehicleType.TOKTOK),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : _confirmTaxiOrder,
                    icon: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('تأكيد وطلب المشوار الآن'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// كارت الخدمة العلوي (صيدلية / مطاعم / مشوار / سوبر ماركت / طرد)
class _ServiceCard extends StatelessWidget {
  final bool selected;
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ServiceCard({
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected ? Colors.white : Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white70 : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}

/// قسم اختيار نقطة (انطلاق أو وصول): مركز + قرية + تفاصيل العنوان
class _LocationSection extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final DistrictData? district;
  final VillageData? village;
  final TextEditingController detailCtrl;
  final ValueChanged<DistrictData?> onDistrictChanged;
  final ValueChanged<VillageData?> onVillageChanged;
  const _LocationSection({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.district,
    required this.village,
    required this.detailCtrl,
    required this.onDistrictChanged,
    required this.onVillageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<VillageData>(
                  value: village,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اختر القرية',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: (district?.villages ?? const <VillageData>[])
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: district == null ? null : onVillageChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<DistrictData>(
                  value: district,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اختر المركز',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: menofiaDistricts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: onDistrictChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: detailCtrl,
            decoration: const InputDecoration(
              hintText: 'رقم المنزل، الشارع، علامة مميزة...',
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// كارت اختيار نوع المركبة (موتوسيكل / سيارة / توكتوك)
class _VehicleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.primary, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: selected ? Colors.white : Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Order order;
  final AppUser user;
  const _ActiveOrderCard({required this.order, required this.user});

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.PENDING:
        return 'بنبحث عن كابتن قريب منك...';
      case OrderStatus.ASSIGNED:
        return 'الكابتن في الطريق إليك';
      case OrderStatus.PICKED:
        return 'الكابتن استلم الطلب';
      case OrderStatus.IN_DELIVERY:
        return 'جاري التوصيل الآن';
      default:
        return enumToStr(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.directions_car, color: Colors.white),
        ),
        title: Text(_statusLabel(order.status),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${order.pickup.address} ← ${order.dropoff.address}'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id, user: user)),
        ),
      ),
    );
  }
}

class _ActivityTab extends StatefulWidget {
  final AppUser user;
  const _ActivityTab({required this.user});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  OrderCategory? filter;
  int dateFilterDays = 0; // 0 = كل الوقت

  static const _labels = {
    OrderCategory.TAXI: 'تاكسي',
    OrderCategory.FOOD: 'طعام',
    OrderCategory.PHARMACY: 'صيدلية',
    OrderCategory.GROCERY: 'سوبر ماركت',
    OrderCategory.PARCEL: 'طرد',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: FirebaseService.instance.orderHistoryForCustomer(widget.user.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var orders = snap.data!;
        if (filter != null) orders = orders.where((o) => o.category == filter).toList();
        if (dateFilterDays > 0) {
          final cutoff = DateTime.now()
              .subtract(Duration(days: dateFilterDays))
              .millisecondsSinceEpoch;
          orders = orders.where((o) => o.createdAt >= cutoff).toList();
        }
        return Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: const Text('الكل'),
                      selected: filter == null,
                      onSelected: (_) => setState(() => filter = null),
                    ),
                  ),
                  ..._labels.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: filter == e.key,
                          onSelected: (_) => setState(() => filter = e.key),
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _dateChip('كل الوقت', 0),
                  _dateChip('آخر 7 أيام', 7),
                  _dateChip('آخر 30 يوم', 30),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: orders.isEmpty
                  ? const Center(child: Text('مفيش طلبات في القسم ده'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final o = orders[i];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          child: ListTile(
                            title: Text(
                                '${_labels[o.category] ?? enumToStr(o.category)} - ${o.price.toStringAsFixed(0)} ج.م'),
                            subtitle: Text('${o.pickup.address} ← ${o.dropoff.address}'),
                            trailing: Chip(label: Text(enumToStr(o.status))),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      OrderTrackingScreen(orderId: o.id, user: widget.user)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _dateChip(String label, int days) {
    final selected = dateFilterDays == days;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => dateFilterDays = days),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final AppUser user;
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: ProfileAvatar(user: user, radius: 40)),
        const SizedBox(height: 12),
        Center(
            child: Text(user.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        Center(child: Text(user.phone, style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('محفظتي الرقمية'),
            subtitle: Text('${user.wallet.balance.toStringAsFixed(0)} ج.م'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WalletScreen(user: user)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('الدعم والملاحظات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SupportScreen(user: user)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            PushService.instance.unregister(user.id);
            FirebaseService.instance.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}

/// شريط إعلانات أفقي أعلى الرئيسية - مقابلة لمكوّن AdsSlider في CustomerDashboard.tsx
class _AdsSlider extends StatelessWidget {
  final List<Ad> ads;
  const _AdsSlider({required this.ads});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ads.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final ad = ads[i];
          return GestureDetector(
            onTap: () => _showAdDetails(context, ad),
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(28),
                image: ad.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(ad.imageUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.25), BlendMode.darken),
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ad.title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                            child: Text(ad.ctaText.isEmpty ? 'اطلب الآن' : ad.ctaText,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAdDetails(BuildContext context, Ad ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdDetailsSheet(ad: ad),
    );
  }
}

/// تفاصيل الإعلان في شيت سفلي - مقابلة لمكوّن AdDetailsView في نسخة الويب
class _AdDetailsSheet extends StatelessWidget {
  final Ad ad;
  const _AdDetailsSheet({required this.ad});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.zero,
            children: [
              AspectRatio(
                aspectRatio: 21 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (ad.imageUrl.isNotEmpty)
                      Image.network(ad.imageUrl, fit: BoxFit.cover)
                    else
                      Container(color: AppColors.cardDark),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Container(width: 56, height: 5, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999))),
                    const SizedBox(height: 16),
                    Text(ad.description,
                        style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black54, fontWeight: FontWeight.w600)),
                    if (ad.whatsappNumber != null && ad.whatsappNumber!.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            FirebaseService.instance.incrementAdClicks(ad.id);
                            final uri = Uri.parse('https://wa.me/${ad.whatsappNumber}');
                            if (await canLaunchUrl(uri)) {
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.chat),
                          label: Text(ad.ctaText.isEmpty ? 'اطلب عبر واتساب' : ad.ctaText,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
