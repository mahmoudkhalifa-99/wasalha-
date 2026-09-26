import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../chat_screen.dart';
import '../notifications_screen.dart';
import '../../services/push_service.dart';
import '../../widgets/profile_avatar.dart';
import '../support_screen.dart';

class DriverDashboard extends StatefulWidget {
  final AppUser user;
  const DriverDashboard({super.key, required this.user});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int tab = 0;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    PushService.instance.init(widget.user.id);
  }

  void _toggleOnline() {
    setState(() => isOnline = !isOnline);
    FirebaseService.instance.setDriverOnline(widget.user.id, isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DriverHomeTab(user: widget.user, isOnline: isOnline, onToggleOnline: _toggleOnline),
      _DriverActivityTab(user: widget.user),
      _DriverWalletTab(user: widget.user),
      _DriverProfileTab(user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الكابتن'),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.history), label: 'النشاط'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined), label: 'المحفظة'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _DriverHomeTab extends StatelessWidget {
  final AppUser user;
  final bool isOnline;
  final VoidCallback onToggleOnline;
  const _DriverHomeTab(
      {required this.user, required this.isOnline, required this.onToggleOnline});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: FirebaseService.instance.activeOrderForDriver(user.id),
      builder: (context, activeSnap) {
        final activeOrder = activeSnap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة أونلاين/أوفلاين
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: isOnline
                      ? [AppColors.primary, AppColors.primaryDark]
                      : [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    onPressed: onToggleOnline,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: Icon(Icons.power_settings_new,
                        color: isOnline ? AppColors.primary : Colors.blueGrey.shade900, size: 26),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(isOnline ? 'نشط ومستعد' : 'أوفلاين حاليًا',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(999)),
                                child: const Text('كابتن توكتوك',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 6),
                              const Text('وصلها المنوفية',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (activeOrder != null)
              _ActiveOrderPanel(order: activeOrder, driver: user)
            else if (!isOnline)
              const _EmptyState(text: 'أنت أوفلاين حاليًا، فعّل الاتصال لاستقبال الطلبات')
            else
              _AvailableOrdersList(driver: user),
          ],
        );
      },
    );
  }
}

class _AvailableOrdersList extends StatelessWidget {
  final AppUser driver;
  const _AvailableOrdersList({required this.driver});

  IconData _iconFor(OrderCategory c) {
    switch (c) {
      case OrderCategory.TAXI:
        return Icons.local_taxi;
      case OrderCategory.FOOD:
        return Icons.restaurant;
      case OrderCategory.PHARMACY:
        return Icons.local_pharmacy;
      case OrderCategory.GROCERY:
        return Icons.local_grocery_store;
      case OrderCategory.PARCEL:
        return Icons.local_shipping;
    }
  }

  Future<void> _accept(BuildContext context, Order order) async {
    try {
      await FirebaseService.instance.acceptOrder(order.id, driver);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('الطلب اتقبل من كابتن تاني: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: FirebaseService.instance.pendingOrdersStream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const _EmptyState(text: 'مفيش طلبات متاحة دلوقتي، هنبلغك أول ما يجي طلب');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('طلبات متاحة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ...orders.map((o) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.12),
                              child: Icon(_iconFor(o.category), color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${o.pickup.address} ← ${o.dropoff.address}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${o.price.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: AppColors.primaryDark)),
                            ElevatedButton(
                              onPressed: () => _accept(context, o),
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                              child: const Text('قبول الطلب'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _ActiveOrderPanel extends StatefulWidget {
  final Order order;
  final AppUser driver;
  const _ActiveOrderPanel({required this.order, required this.driver});

  @override
  State<_ActiveOrderPanel> createState() => _ActiveOrderPanelState();
}

class _ActiveOrderPanelState extends State<_ActiveOrderPanel> {
  bool loading = false;

  OrderStatus? get _nextStatus {
    switch (widget.order.status) {
      case OrderStatus.ASSIGNED:
        return OrderStatus.PICKED;
      case OrderStatus.PICKED:
        return OrderStatus.IN_DELIVERY;
      case OrderStatus.IN_DELIVERY:
        return OrderStatus.DELIVERED;
      default:
        return null;
    }
  }

  String get _nextLabel {
    switch (widget.order.status) {
      case OrderStatus.ASSIGNED:
        return 'تأكيد استلام الطلب';
      case OrderStatus.PICKED:
        return 'بدء التوصيل';
      case OrderStatus.IN_DELIVERY:
        return 'تأكيد التوصيل والتحصيل';
      default:
        return '';
    }
  }

  Future<void> _advance() async {
    final next = _nextStatus;
    if (next == null || loading) return;
    setState(() => loading = true);
    try {
      await FirebaseService.instance.updateOrderStatus(widget.order.id, next, widget.driver.id);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${widget.order.customerPhone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNavigation() async {
    // بنفتح تطبيق خرائط خارجي (Google Maps) للملاحة لحد نقطة الاستلام أو
    // التسليم حسب حالة الطلب الحالية - مقابلة عملية لخريطة الملاحة الحية بالويب
    final o = widget.order;
    final target = o.status == OrderStatus.ASSIGNED ? o.pickup : o.dropoff;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${target.lat},${target.lng}&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String get _statusLabel {
    switch (widget.order.status) {
      case OrderStatus.ASSIGNED:
        return 'في الطريق للاستلام';
      case OrderStatus.PICKED:
        return 'تم الاستلام';
      case OrderStatus.IN_DELIVERY:
        return 'جاري التوصيل';
      case OrderStatus.DELIVERED:
        return 'تم التوصيل';
      default:
        return enumToStr(widget.order.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(_statusLabel,
                    style: const TextStyle(
                        color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${o.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30)),
                  const Padding(
                    padding: EdgeInsets.only(right: 4, bottom: 4),
                    child: Text('ج.م', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PointRow(
            color: AppColors.primary,
            icon: Icons.location_on,
            caption: 'المطعم / نقطة الاستلام',
            value: o.pickup.address,
          ),
          const SizedBox(height: 14),
          _PointRow(
            color: Colors.redAccent,
            icon: Icons.navigation,
            caption: 'وجهة التوصيل',
            value: o.dropoff.address,
          ),
          if (o.notes != null && o.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('ملاحظات: ${o.notes}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openNavigation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('الخريطة ومتابعة العميل'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(order: widget.order, user: widget.driver)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('دردشة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _call,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('اتصال'),
                ),
              ),
            ],
          ),
          if (_nextStatus != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _advance,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_nextLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// صف نقطة استلام/تسليم داخل كارت الطلب النشط
class _PointRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String caption;
  final String value;
  const _PointRow({required this.color, required this.icon, required this.caption, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: const TextStyle(fontSize: 11, color: Colors.black45)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _DriverActivityTab extends StatefulWidget {
  final AppUser user;
  const _DriverActivityTab({required this.user});

  @override
  State<_DriverActivityTab> createState() => _DriverActivityTabState();
}

class _DriverActivityTabState extends State<_DriverActivityTab> {
  int dateFilterDays = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: FirebaseService.instance.orderHistoryForDriver(widget.user.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var orders = snap.data!
            .where((o) =>
                o.status == OrderStatus.DELIVERED || o.status == OrderStatus.CANCELLED)
            .toList();
        if (dateFilterDays > 0) {
          final cutoff = DateTime.now()
              .subtract(Duration(days: dateFilterDays))
              .millisecondsSinceEpoch;
          orders = orders.where((o) => o.createdAt >= cutoff).toList();
        }
        final totalEarnings = orders
            .where((o) => o.status == OrderStatus.DELIVERED)
            .fold<double>(0, (sum, o) => sum + (o.price - o.commission));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _dateChip('كل الوقت', 0),
                  _dateChip('آخر 7 أيام', 7),
                  _dateChip('آخر 30 يوم', 30),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: AppColors.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي أرباحك', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${totalEarnings.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('مفيش رحلات في الفترة دي', style: TextStyle(color: Colors.grey))),
              ),
            ...orders.map((o) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: Icon(
                      o.status == OrderStatus.DELIVERED ? Icons.check_circle : Icons.cancel,
                      color: o.status == OrderStatus.DELIVERED ? AppColors.primary : Colors.red,
                    ),
                    title: Text('${o.pickup.address} ← ${o.dropoff.address}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${o.price.toStringAsFixed(0)} ج.م'),
                  ),
                )),
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

class _DriverWalletTab extends StatelessWidget {
  final AppUser user;
  const _DriverWalletTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: FirebaseService.instance.userStream(user.id),
      builder: (context, snap) {
        final live = snap.data ?? user;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('رصيدك الحالي', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('${live.wallet.balance.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                leading: const Icon(Icons.trending_up, color: AppColors.primary),
                title: const Text('إجمالي الأرباح'),
                trailing: Text('${live.wallet.totalEarnings.toStringAsFixed(0)} ج.م'),
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.orange),
                title: const Text('المسحوب'),
                trailing: Text('${live.wallet.withdrawn.toStringAsFixed(0)} ج.م'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: live.wallet.balance <= 0
                    ? null
                    : () => _openWithdrawSheet(context, live),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('طلب سحب الأرباح'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('طلبات السحب السابقة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 10),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService.instance.driverWithdrawalsStream(user.id),
              builder: (context, wSnap) {
                final items = wSnap.data ?? [];
                if (items.isEmpty) {
                  return const Text('مفيش طلبات سحب لسه', style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: items.map((w) {
                    final status = w['status'] as String? ?? 'PENDING';
                    Color color;
                    String label;
                    switch (status) {
                      case 'PAID':
                        color = AppColors.primary;
                        label = 'تم التحويل';
                        break;
                      case 'REJECTED':
                        color = Colors.red;
                        label = 'مرفوض';
                        break;
                      default:
                        color = Colors.amber.shade700;
                        label = 'قيد المراجعة';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Icon(Icons.receipt_long, color: color),
                        title: Text('${(w['amount'] as num).toStringAsFixed(0)} ج.م'),
                        trailing: Chip(
                          label: Text(label, style: const TextStyle(fontSize: 10)),
                          backgroundColor: color.withOpacity(0.12),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openWithdrawSheet(BuildContext context, AppUser live) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طلب سحب أرباح', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('الرصيد المتاح: ${live.wallet.balance.toStringAsFixed(0)} ج.م',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المطلوب سحبه'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0 || amount > live.wallet.balance) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('المبلغ غير صحيح أو أكبر من رصيدك')));
                  return;
                }
                await FirebaseService.instance.requestWithdrawal(live, amount);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProfileTab extends StatelessWidget {
  final AppUser user;
  const _DriverProfileTab({required this.user});

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
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.two_wheeler),
            title: const Text('نوع المركبة'),
            trailing: Text(user.vehicleType != null ? enumToStr(user.vehicleType!) : '-'),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('رقم اللوحة'),
            trailing: Text(user.plateNumber ?? '-'),
          ),
        ),
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
