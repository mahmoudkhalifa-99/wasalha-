import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import 'villages_tab.dart';
import 'ads_manager_tab.dart';
import 'admin_edit_user_screen.dart';
import '../../widgets/village_picker.dart';
import '../notifications_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  final AppUser user;
  const SuperAdminDashboard({super.key, required this.user});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    PushService.instance.init(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const ['الإحصائيات', 'المستخدمين', 'المطاعم', 'إدارة المنوفية', 'الإعلانات'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة العليا'),
        actions: [
          StreamBuilder<int>(
            stream: FirebaseService.instance
                .unreadNotificationsCount(widget.user.id, role: widget.user.role),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                              userId: widget.user.id, role: widget.user.role)),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => FirebaseService.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final selected = tab == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Colors.black87 : AppColors.bg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(tabs[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : Colors.black54)),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [_StatsTab(), _UsersTab(), _RestaurantsTab(), VillagesTab(), AdsManagerTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirebaseService.instance.allUsersStream(),
      builder: (context, usersSnap) {
        return StreamBuilder<List<Order>>(
          stream: FirebaseService.instance.allOrdersStream(),
          builder: (context, ordersSnap) {
            final users = usersSnap.data ?? [];
            final orders = ordersSnap.data ?? [];
            final systemBalance =
                users.fold<double>(0, (sum, u) => sum + u.wallet.balance);
            final driversCount = users
                .where((u) => u.role == UserRole.DRIVER && u.status == UserStatus.APPROVED)
                .length;
            final customersCount = users.where((u) => u.role == UserRole.CUSTOMER).length;
            final activeOrders = orders
                .where((o) =>
                    o.status != OrderStatus.DELIVERED && o.status != OrderStatus.CANCELLED)
                .length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.3,
                  children: [
                    _StatCard(
                      label: 'رصيد المنظومة',
                      value: '${systemBalance.toStringAsFixed(1)} ج.م',
                      color: AppColors.primary,
                      textColor: Colors.white,
                    ),
                    _StatCard(
                      label: 'كباتن معتمدين',
                      value: '$driversCount',
                      color: const Color(0xFF020617),
                      textColor: Colors.white,
                    ),
                    _StatCard(
                      label: 'إجمالي العملاء',
                      value: '$customersCount',
                      color: Colors.white,
                      textColor: Colors.black87,
                    ),
                    _StatCard(
                      label: 'رحلات نشطة',
                      value: '$activeOrders',
                      color: Colors.white,
                      textColor: Colors.black87,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('طلبات سحب الأرباح المعلّقة',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                const _PendingWithdrawalsList(),
                const SizedBox(height: 28),
                _LiveActivityFeed(orders: orders),
              ],
            );
          },
        );
      },
    );
  }
}

class _PendingWithdrawalsList extends StatelessWidget {
  const _PendingWithdrawalsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.pendingWithdrawalsStream(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Text('لا توجد طلبات سحب معلّقة', style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: items.map((w) {
            final amount = (w['amount'] as num).toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w['driverName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${amount.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                  color: AppColors.primaryDark, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => FirebaseService.instance.rejectWithdrawal(w['id']),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                    ElevatedButton(
                      onPressed: () => FirebaseService.instance
                          .approveWithdrawal(w['id'], w['driverId'], amount),
                      child: const Text('تحويل'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;
  const _StatCard(
      {required this.label, required this.value, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textColor.withOpacity(0.7))),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String search = '';
  UserRole? roleFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirebaseService.instance.allUsersStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final users = snap.data!
            .where((u) =>
                (u.name.toLowerCase().contains(search.toLowerCase()) || u.phone.contains(search)) &&
                (roleFilter == null || u.role == roleFilter))
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  hintText: 'بحث عن اسم أو موبايل...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _roleChip(null, 'الكل'),
                  _roleChip(UserRole.CUSTOMER, 'عملاء'),
                  _roleChip(UserRole.DRIVER, 'كباتن'),
                  _roleChip(UserRole.OPERATOR, 'مشغّلين'),
                  _roleChip(UserRole.ADMIN, 'مديرين'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _UserCard(user: users[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _roleChip(UserRole? role, String label) {
    final selected = roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        selected: selected,
        selectedColor: AppColors.primary.withOpacity(0.18),
        onSelected: (_) => setState(() => roleFilter = role),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final approved = user.status == UserStatus.APPROVED;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Text(user.name.isNotEmpty ? user.name[0] : '؟'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(user.phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              Chip(
                label: Text(enumToStr(user.role), style: const TextStyle(fontSize: 10)),
                backgroundColor:
                    user.role == UserRole.DRIVER ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade200,
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(enumToStr(user.status), style: const TextStyle(fontSize: 10)),
                backgroundColor: approved ? Colors.blue.withOpacity(0.12) : Colors.amber.withOpacity(0.2),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (user.role == UserRole.DRIVER && !approved)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => FirebaseService.instance
                        .updateUserStatus(user.id, UserStatus.APPROVED),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: const Text('موافقة', style: TextStyle(fontSize: 12)),
                  ),
                ),
              if (user.role == UserRole.DRIVER && !approved) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminEditUserScreen(user: user)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('تعديل شامل', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('حذف نهائي؟'),
                      content: Text('هيتم حذف ${user.name} نهائيًا من المنظومة'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('حذف', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) await FirebaseService.instance.deleteUser(user.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestaurantsTab extends StatefulWidget {
  const _RestaurantsTab();

  @override
  State<_RestaurantsTab> createState() => _RestaurantsTabState();
}

class _RestaurantsTabState extends State<_RestaurantsTab> {
  final nameCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  bool adding = false;
  String? editingId;
  VillageData? selectedVillage;
  bool saving = false;

  void _startAdd() {
    setState(() {
      adding = true;
      editingId = null;
      nameCtrl.clear();
      categoryCtrl.text = 'مشويات';
      selectedVillage = null;
    });
  }

  void _startEdit(Restaurant r) {
    setState(() {
      adding = true;
      editingId = r.id;
      nameCtrl.text = r.name;
      categoryCtrl.text = r.category;
      selectedVillage = null; // المستخدم لازم يعيد اختيار الموقع لو حابب يغيّره
      _editingLat = r.lat;
      _editingLng = r.lng;
      _editingAddress = r.address;
    });
  }

  Future<void> _pickLocation() async {
    final v = await pickVillage(context);
    if (v != null) setState(() => selectedVillage = v);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    if (editingId == null && selectedVillage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى اختيار موقع المطعم (المركز والقرية)')));
      return;
    }
    setState(() => saving = true);
    try {
      if (editingId != null) {
        // لو معدّلش الموقع، سيب الإحداثيات القديمة زي ما هي
        await FirebaseService.instance.updateRestaurant(
          editingId!,
          name: nameCtrl.text.trim(),
          category: categoryCtrl.text.trim(),
          address: selectedVillage?.name ?? _editingAddress ?? '',
          lat: selectedVillage?.lat ?? _editingLat ?? 30.298,
          lng: selectedVillage?.lng ?? _editingLng ?? 30.975,
        );
      } else {
        await FirebaseService.instance.createRestaurant(
          nameCtrl.text.trim(),
          categoryCtrl.text.trim(),
          selectedVillage!.name,
          selectedVillage!.lat,
          selectedVillage!.lng,
        );
      }
      nameCtrl.clear();
      categoryCtrl.clear();
      setState(() {
        adding = false;
        editingId = null;
        selectedVillage = null;
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  double? _editingLat;
  double? _editingLng;
  String? _editingAddress;

  @override
  void dispose() {
    nameCtrl.dispose();
    categoryCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Restaurant>>(
      stream: FirebaseService.instance.allRestaurantsStream(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final restaurants =
            all.where((r) => r.name.toLowerCase().contains(searchCtrl.text.toLowerCase())).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إدارة المطاعم',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    if (adding) {
                      adding = false;
                    } else {
                      _startAdd();
                    }
                  }),
                  icon: Icon(adding ? Icons.close : Icons.add),
                  label: Text(adding ? 'إلغاء' : 'إضافة مطعم'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'بحث عن مطعم...', prefixIcon: Icon(Icons.search)),
            ),
            if (adding) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(editingId == null ? 'مطعم جديد' : 'تعديل مطعم',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'اسم المطعم'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'التصنيف (بيتزا، مشويات...)'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickLocation,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration:
                            BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18, color: Colors.black38),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedVillage?.name ??
                                    (editingId != null ? 'اترك بدون تغيير للموقع الحالي' : 'اختر المركز والقرية'),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: saving ? null : _save,
                      child: saving
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ البيانات'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!snap.hasData)
              const Center(child: CircularProgressIndicator())
            else if (restaurants.isEmpty)
              const Center(child: Text('لا يوجد مطاعم مضافة لسه'))
            else
              ...restaurants.map((r) => _RestaurantCard(restaurant: r, onEdit: () => _startEdit(r))),
          ],
        );
      },
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onEdit;
  const _RestaurantCard({required this.restaurant, required this.onEdit});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  final itemNameCtrl = TextEditingController();
  final itemPriceCtrl = TextEditingController();

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المطعم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.deleteRestaurant(widget.restaurant.id);
  }

  Future<void> _addItem() async {
    final price = double.tryParse(itemPriceCtrl.text.trim());
    if (itemNameCtrl.text.trim().isEmpty || price == null || price <= 0) return;
    await FirebaseService.instance.addMenuItem(
        widget.restaurant.id, widget.restaurant.menu, itemNameCtrl.text.trim(), price);
    itemNameCtrl.clear();
    itemPriceCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.08)),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, color: AppColors.primaryDark),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.08)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    Text(r.category, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    Text(r.address, style: const TextStyle(color: Colors.black38, fontSize: 10)),
                  ],
                ),
              ),
              Switch(
                value: r.isOpen,
                activeColor: AppColors.primary,
                onChanged: (v) => FirebaseService.instance.toggleRestaurantOpen(r.id, v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('الوجبات (${r.menu.length})',
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...r.menu.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => FirebaseService.instance
                          .removeMenuItem(r.id, r.menu, item.id),
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${item.price.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: itemNameCtrl,
                  decoration: const InputDecoration(
                      hintText: 'اسم الوجبة', isDense: true, contentPadding: EdgeInsets.all(10)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: itemPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      hintText: 'السعر', isDense: true, contentPadding: EdgeInsets.all(10)),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: const Text('إضافة', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بث النشاط المباشر - آخر الطلبات في المنظومة، مقابلة لقسم "Live Feed" في
/// نسخة الويب من SuperAdminDashboard.tsx
class _LiveActivityFeed extends StatelessWidget {
  final List<Order> orders;
  const _LiveActivityFeed({required this.orders});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.DELIVERED:
        return const Color(0xFF34D399);
      case OrderStatus.CANCELLED:
        return const Color(0xFFFB7185);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = orders.take(20).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Text('Live Activity',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900)),
              ),
              const Row(
                children: [
                  Text('آخر العمليات',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(width: 8),
                  Icon(Icons.bolt, color: AppColors.primary, size: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('لا يوجد نشاط حتى الآن', style: TextStyle(color: Colors.white38, fontSize: 12))),
            )
          else
            ...recent.map((o) {
              final time = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${o.pickup.villageName ?? o.pickup.address} ← ${o.dropoff.villageName ?? o.dropoff.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} • ${enumToStr(o.category)}',
                              style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${o.price.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(o.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(enumToStr(o.status),
                              style: TextStyle(
                                  color: _statusColor(o.status), fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
