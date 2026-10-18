import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';

class _Tx {
  final String id, kind, description;
  final double amount;
  final int createdAt;
  const _Tx(this.id, this.kind, this.amount, this.description, this.createdAt);
}

/// أرباح الكابتن: صافي الأرباح، العمولة المستحقة للتطبيق، اللي اتسدّد، وسجل
/// المعاملات (الأرقام بتتكتب من السيرفر عند التسليم، مش من التطبيق).
class CourierEarningsView extends StatefulWidget {
  final AppUser user;
  final VoidCallback onBack;
  const CourierEarningsView({super.key, required this.user, required this.onBack});

  @override
  State<CourierEarningsView> createState() => _CourierEarningsViewState();
}

class _CourierEarningsViewState extends State<CourierEarningsView> {
  List<_Tx> _txs = [];
  bool _loading = true;
  Object? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = db
        .collection('transactions')
        .where('userId', isEqualTo: widget.user.id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _txs = snap.docs.map((d) {
          final m = stripFirestore(d.data()) as Map<String, dynamic>;
          return _Tx(
            d.id,
            (m['kind'] as String?) ?? '',
            (m['amount'] as num?)?.toDouble() ?? 0,
            (m['description'] as String?) ?? '',
            (m['createdAt'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        _loading = false;
        _error = null;
      });
    }, onError: (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _money(double v) => v.toStringAsFixed(2);

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: Sh.sm(),
          ),
          child: Column(
            children: [
              Text(value, style: T.s(18, T.w900, color)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center, style: T.s(10, T.w700, C.slate500)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget.user.wallet;
    final df = intl.DateFormat('yyyy/MM/dd HH:mm');
    return Container(
      color: C.slate50,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 128),
          children: [
            Row(
              children: [
                PressScale(
                  scale: 0.9,
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Sh.sm(),
                    ),
                    child: const Icon(LucideIcons.chevronRight, size: 20, color: C.slate700),
                  ),
                ),
                const SizedBox(width: 14),
                Text('أرباحي', style: T.s(24, T.w900, C.slate900)),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              _stat('صافي أرباحك', '${_money(w.totalEarnings)} ج.م', C.emerald700),
              const SizedBox(width: 10),
              _stat('عمولة مستحقة للتطبيق', '${_money(w.commissionDue)} ج.م', C.rose500),
              const SizedBox(width: 10),
              _stat('اتسدّد', '${_money(w.commissionPaid)} ج.م', C.slate700),
            ]),
            const SizedBox(height: 8),
            Text(
                'الأوردرات كاش: بتاخد الإجمالي من العميل وتدفع تمن الطلبات للمحل، والعمولة المستحقة بتسدّدها للإدارة وبتتسجّل هنا.',
                style: T.s(11, T.w500, C.slate500)),
            const SizedBox(height: 20),
            Text('سجل المعاملات', style: T.s(15, T.w900, C.slate900)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text('تعذر تحميل المعاملات: ${friendlyError(_error!)}',
                  style: T.s(12, T.w700, C.rose500))
            else if (_txs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('لا توجد معاملات بعد', style: T.s(13, T.w700, C.slate400))),
              )
            else
              for (final t in _txs)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: C.white, borderRadius: BorderRadius.circular(16), boxShadow: Sh.sm()),
                  child: Row(
                    children: [
                      Text(
                          '${t.kind == 'COMMISSION' ? '-' : '+'}${_money(t.amount)}',
                          style: T.s(15, T.w900,
                              t.kind == 'COMMISSION' ? C.rose500 : C.emerald700)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t.description, style: T.s(12, T.w700, C.slate900)),
                            Text(df.format(DateTime.fromMillisecondsSinceEpoch(t.createdAt)),
                                style: T.s(10, T.w500, C.slate400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
