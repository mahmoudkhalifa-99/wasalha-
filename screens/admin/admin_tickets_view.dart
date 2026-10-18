import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';

const _typeLabels = {
  'SUPPORT': 'دعم',
  'DISPUTE': 'نزاع',
  'REFUND': 'استرجاع',
  'SAFETY': 'أمان',
};
const _statusLabels = {
  'OPEN': 'مفتوحة',
  'IN_PROGRESS': 'قيد المراجعة',
  'RESOLVED': 'تم الحل',
  'REJECTED': 'مرفوضة',
};

/// تذاكر الدعم والنزاعات والاسترجاع: الإدارة تراجع وتكتب القرار، والمستخدم بيتبلّغ.
class AdminTicketsView extends StatefulWidget {
  final AppUser user;
  const AdminTicketsView({super.key, required this.user});

  @override
  State<AdminTicketsView> createState() => _AdminTicketsViewState();
}

class _AdminTicketsViewState extends State<AdminTicketsView> {
  List<Map<String, dynamic>> _tickets = [];
  String _filter = 'OPEN';
  bool _loading = true;
  Object? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = db.collection('tickets').limit(300).snapshots().listen((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList()
        ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
      if (mounted) setState(() {
        _tickets = list;
        _loading = false;
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

  Future<void> _resolve(Map<String, dynamic> t) async {
    final ctrl = TextEditingController(text: (t['resolution'] as String?) ?? '');
    String status = (t['status'] as String?) ?? 'OPEN';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('${_typeLabels[t['type']] ?? ''} — ${t['userName'] ?? ''}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t['message']}', style: T.s(12, T.w500, C.slate700)),
                if (t['orderId'] != null) Text('الطلب: ${t['orderId']}', style: T.s(10, T.w700, C.slate500)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  items: [
                    for (final e in _statusLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setS(() => status = v ?? status),
                ),
                TextField(
                  controller: ctrl,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'القرار / الرد للمستخدم'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    final resolution = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.collection('tickets').doc(t['id'] as String).update({
        'status': status,
        'resolution': resolution,
        'resolvedBy': widget.user.id,
        'resolvedAt': now,
        'updatedAt': now,
      });
      await NotificationService.notifyUser(
        userId: t['userId'] as String,
        title: 'ردّ على رسالتك',
        body: resolution.isEmpty ? 'حالة رسالتك: ${_statusLabels[status]}' : resolution,
        type: 'INFO',
        key: 'ticket_${t['id']}',
      );
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر الحفظ: ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == 'ALL'
        ? _tickets
        : _tickets.where((t) => t['status'] == _filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 8, children: [
          for (final e in {'ALL': 'الكل', ..._statusLabels}.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _filter == e.key,
              onSelected: (_) => setState(() => _filter = e.key),
            ),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Text('تعذر تحميل التذاكر', style: T.s(12, T.w700, C.rose500))
        else if (shown.isEmpty)
          Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('لا توجد تذاكر', style: T.s(13, T.w700, C.slate400))))
        else
          for (final t in shown)
            GestureDetector(
              onTap: () => _resolve(t),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${_typeLabels[t['type']] ?? t['type']} • ${_statusLabels[t['status']] ?? t['status']} • ${t['userName'] ?? ''} (${t['userPhone'] ?? ''})',
                        style: T.s(11, T.w900, C.emerald700)),
                    const SizedBox(height: 4),
                    Text('${t['message']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: T.s(12, T.w500, C.slate700)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
