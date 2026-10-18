import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../pricing.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';

/// شاشة المطعم: بتعرض الأوردرات الجارية على مطعمه (من غير تليفون العميل)، والمطعم
/// يقبل/يرفض ويحدّث حالة التحضير (جاري التحضير ← جاهز). حالة التحضير بتتكتب في
/// الأوردر (restaurantStatus) والعميل بيتبلّغ بإشعار.
class RestaurantDashboard extends StatefulWidget {
  final AppUser user;
  final Future<void> Function() onLogout;
  const RestaurantDashboard({super.key, required this.user, required this.onLogout});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  List<Order> _orders = [];
  bool _loading = true;
  Object? _error;
  StreamSubscription? _sub;
  final Set<String> _busy = {};

  static const _labels = {
    'ACCEPTED': 'تم القبول',
    'PREPARING': 'جاري التحضير',
    'READY': 'جاهز للاستلام',
    'REJECTED': 'مرفوض',
  };

  @override
  void initState() {
    super.initState();
    final rid = widget.user.restaurantId;
    if (rid == null || rid.isEmpty) {
      _loading = false;
      return;
    }
    _sub = db
        .collection('orders')
        .where('restaurantId', isEqualTo: rid)
        .where('status', whereIn: ['PENDING', 'ASSIGNED', 'PICKED', 'IN_DELIVERY'])
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((d) => Order.fromMap(
              stripFirestore(d.data()) as Map<String, dynamic>, d.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() {
        _orders = list;
        _loading = false;
        _error = null;
      });
    }, onError: (e) {
      if (mounted) setState(() {
        _error = e;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _setStatus(Order o, String status, {String? note}) async {
    if (_busy.contains(o.id)) return;
    setState(() => _busy.add(o.id));
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.collection('orders').doc(o.id).update({
        'restaurantStatus': status,
        if (note != null && note.isNotEmpty) 'restaurantNote': note,
        'restaurantUpdatedAt': now,
        'updatedAt': now,
      });
      await NotificationService.notifyUser(
        userId: o.customerId,
        title: status == 'READY'
            ? 'طلبك جاهز من المطعم'
            : status == 'REJECTED'
                ? 'المطعم اعتذر عن طلبك'
                : 'المطعم ${_labels[status]}',
        body: status == 'REJECTED' && (note ?? '').isNotEmpty
            ? 'السبب: $note'
            : '${o.restaurantName ?? "المطعم"} — ${_labels[status]}',
        type: status == 'REJECTED' ? 'ALERT' : 'INFO',
        key: 'rest_${o.id}_$status',
        orderId: o.id,
      );
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر التحديث: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  Future<void> _reject(Order o) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الطلب'),
          content: TextField(
              controller: ctrl,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'السبب (يوصل للعميل)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض')),
          ],
        ),
      ),
    );
    final note = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true) await _setStatus(o, 'REJECTED', note: note);
  }

  Widget _action(String label, VoidCallback? onTap, {Color color = C.emerald600}) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: C.white),
          onPressed: onTap,
          child: Text(label),
        ),
      );

  Widget _card(Order o) {
    final st = o.restaurantStatus;
    final busy = _busy.contains(o.id);
    final items = o.foodItems ?? const <CartItem>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(st == null ? 'طلب جديد' : (_labels[st] ?? st),
                  style: T.s(12, T.w900, st == null ? C.amber600 : C.emerald700)),
              Text('#${o.id.length >= 6 ? o.id.substring(o.id.length - 6).toUpperCase() : o.id}',
                  style: T.s(11, T.w700, C.slate400)),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isNotEmpty)
            for (final i in items)
              Text('${i.quantity} × ${i.name}', style: T.s(13, T.w800, C.slate900))
          else if ((o.specialRequest ?? '').isNotEmpty)
            Text(o.specialRequest!, style: T.s(13, T.w800, C.slate900)),
          const SizedBox(height: 6),
          Text('تمن الطلبات: ${goodsTotalOf(o).toStringAsFixed(0)} ج.م',
              style: T.s(12, T.w700, C.slate600)),
          Text('التوصيل إلى: ${o.dropoff.villageName ?? o.dropoff.address}',
              style: T.s(11, T.w500, C.slate500)),
          if ((o.dropoffNotes ?? '').isNotEmpty)
            Text('ملاحظات: ${o.dropoffNotes}', style: T.s(11, T.w500, C.slate500)),
          Text(
              o.driverName != null
                  ? 'الكابتن: ${o.driverName}'
                  : 'لسه ما اتعيّنش كابتن',
              style: T.s(11, T.w700, C.slate700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (st == null) ...[
                _action('رفض', busy ? null : () => _reject(o), color: C.rose500),
                _action('قبول', busy ? null : () => _setStatus(o, 'ACCEPTED')),
              ] else if (st == 'ACCEPTED')
                _action('بدأ التحضير', busy ? null : () => _setStatus(o, 'PREPARING'))
              else if (st == 'PREPARING')
                _action('جاهز للاستلام', busy ? null : () => _setStatus(o, 'READY')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRestaurant = (widget.user.restaurantId ?? '').isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: C.slate50,
        appBar: AppBar(
          backgroundColor: C.white,
          foregroundColor: C.slate900,
          title: Text(widget.user.name, style: T.s(16, T.w900, C.slate900)),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(LucideIcons.logOut, size: 20),
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: !hasRestaurant
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('حسابك لسه مش مربوط بمطعم. كلّم الإدارة.',
                      textAlign: TextAlign.center, style: T.s(14, T.w800, C.slate700)),
                ),
              )
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text('تعذر تحميل الطلبات: ${friendlyError(_error!)}',
                            style: T.s(12, T.w700, C.rose500)))
                    : _orders.isEmpty
                        ? Center(
                            child: Text('مفيش طلبات جارية دلوقتي',
                                style: T.s(13, T.w700, C.slate400)))
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [for (final o in _orders) _card(o)],
                          ),
      ),
    );
  }
}
