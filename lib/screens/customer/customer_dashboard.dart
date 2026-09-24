import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import 'food/restaurants_list_screen.dart';
import 'new_quick_order_screen.dart';
import 'new_taxi_order_screen.dart';
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

class _HomeTab extends StatelessWidget {
  final AppUser user;
  const _HomeTab({required this.user});

  static const _categories = [
    (OrderCategory.TAXI, 'مشوار', Icons.local_taxi),
    (OrderCategory.FOOD, 'مطاعم', Icons.restaurant),
    (OrderCategory.PHARMACY, 'صيدلية', Icons.local_pharmacy),
    (OrderCategory.GROCERY, 'سوبر ماركت', Icons.local_grocery_store),
    (OrderCategory.PARCEL, 'طرد', Icons.local_shipping),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: FirebaseService.instance.activeOrdersForCustomer(user.id),
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
                ...active.map((o) => _ActiveOrderCard(order: o, user: user)),
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
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.3,
                children: _categories
                    .map((c) => _CategoryCard(
                          category: c.$1,
                          label: c.$2,
                          icon: c.$3,
                          user: user,
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final OrderCategory category;
  final String label;
  final IconData icon;
  final AppUser user;
  const _CategoryCard(
      {required this.category, required this.label, required this.icon, required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (category == OrderCategory.TAXI) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewTaxiOrderScreen(user: user)),
            );
          } else if (category == OrderCategory.FOOD) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RestaurantsListScreen(user: user)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NewQuickOrderScreen(user: user, category: category)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 34),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
