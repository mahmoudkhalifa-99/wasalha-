import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../pricing.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// تقارير الأدمن: آخر 7/30 يوم — عدد الأوردرات بالحالة، الإيراد والعمولة، نسبة الإلغاء،
/// وأعلى الكباتن. بتتحسب من آخر 2000 أوردر في الفترة (لو الفترة فيها أكتر بيظهر تنبيه).
class AdminReportsView extends StatefulWidget {
  final AppUser user;
  const AdminReportsView({super.key, required this.user});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  static const _cap = 2000;
  int _days = 30;
  bool _loading = true;
  Object? _error;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final since = DateTime.now()
          .subtract(Duration(days: _days))
          .millisecondsSinceEpoch;
      final snap = await db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: since)
          .orderBy('createdAt', descending: true)
          .limit(_cap)
          .get();
      final list = snap.docs
          .map((d) => Order.fromMap(
              stripFirestore(d.data()) as Map<String, dynamic>, d.id))
          .toList();
      if (mounted) setState(() => _orders = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stat(String label, String value, Color color) => Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration:
            BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(value, style: T.s(20, T.w900, color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: T.s(10, T.w700, C.slate500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final delivered =
        _orders.where((o) => o.status == OrderStatus.delivered).toList();
    final cancelled =
        _orders.where((o) => o.status == OrderStatus.cancelled).length;
    final pending =
        _orders.where((o) => o.status == OrderStatus.pending).length;
    final active = _orders.length - delivered.length - cancelled - pending;
    final revenue = delivered.fold<double>(0, (s, o) => s + o.price);
    final commission =
        delivered.fold<double>(0, (s, o) => s + platformCommissionOf(o));
    final cancelRate =
        _orders.isEmpty ? 0 : (cancelled / _orders.length * 100);

    final perDriver = <String, int>{};
    final names = <String, String>{};
    for (final o in delivered) {
      final id = o.driverId;
      if (id == null) continue;
      perDriver[id] = (perDriver[id] ?? 0) + 1;
      names[id] = o.driverName ?? id;
    }
    final top = perDriver.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 8, children: [
          for (final d in const [7, 30, 90])
            ChoiceChip(
              label: Text('آخر $d يوم'),
              selected: _days == d,
              onSelected: (_) {
                setState(() => _days = d);
                _load();
              },
            ),
        ]),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Text('تعذر تحميل التقرير: ${friendlyError(_error!)}',
              style: T.s(12, T.w700, C.rose500))
        else ...[
          if (_orders.length >= _cap)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('الفترة فيها أكتر من $_cap أوردر — الأرقام لأحدث $_cap بس.',
                  style: T.s(11, T.w700, C.amber600)),
            ),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _stat('إجمالي الأوردرات', '${_orders.length}', C.slate900),
            _stat('تم التوصيل', '${delivered.length}', C.emerald700),
            _stat('ملغي', '$cancelled (${cancelRate.toStringAsFixed(0)}%)', C.rose500),
            _stat('منتظر / جاري', '$pending / $active', C.slate700),
            _stat('إجمالي قيمة الأوردرات (ج.م)', revenue.toStringAsFixed(0), C.slate900),
            _stat('عمولة التطبيق (ج.م)', commission.toStringAsFixed(0), C.emerald700),
          ]),
          const SizedBox(height: 20),
          Text('أعلى الكباتن (توصيلات)', style: T.s(14, T.w900, C.slate900)),
          const SizedBox(height: 8),
          if (top.isEmpty)
            Text('لا توجد بيانات', style: T.s(12, T.w500, C.slate400))
          else
            for (final e in top.take(10))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: C.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(names[e.key] ?? e.key, style: T.s(12, T.w700, C.slate900)),
                    Text('${e.value}', style: T.s(13, T.w900, C.emerald700)),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}
