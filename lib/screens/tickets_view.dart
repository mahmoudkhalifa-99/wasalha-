import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';

const _typeLabels = {
  'SUPPORT': 'استفسار / دعم',
  'DISPUTE': 'مشكلة في طلب',
  'REFUND': 'طلب استرجاع',
  'SAFETY': 'بلاغ أمان',
};
const _statusLabels = {
  'OPEN': 'مفتوحة',
  'IN_PROGRESS': 'قيد المراجعة',
  'RESOLVED': 'تم الحل',
  'REJECTED': 'مرفوضة',
};

/// الدعم والشكاوى: المستخدم (عميل/كابتن) يفتح تذكرة، ومعاها رقم الطلب لو جاي من طلب،
/// ويتابع ردّ الإدارة. الإدارة بتشوفها من لوحة التحكم.
class TicketsView extends StatefulWidget {
  final AppUser user;
  final String? orderId;
  final String initialType;
  const TicketsView({super.key, required this.user, this.orderId, this.initialType = 'SUPPORT'});

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView> {
  final _msg = TextEditingController();
  late String _type = widget.initialType;
  bool _sending = false;
  List<Map<String, dynamic>> _tickets = [];
  Object? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = db
        .collection('tickets')
        .where('userId', isEqualTo: widget.user.id)
        .snapshots()
        .listen((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList()
        ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
      if (mounted) setState(() => _tickets = list);
    }, onError: (e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msg.text.trim();
    if (text.length < 5) {
      showAppAlert(context, 'اكتب تفاصيل المشكلة (5 حروف على الأقل)');
      return;
    }
    setState(() => _sending = true);
    try {
      await db.collection('tickets').add({
        'userId': widget.user.id,
        'userName': widget.user.name,
        'userPhone': widget.user.phone,
        'userRole': widget.user.role.value,
        if (widget.orderId != null) 'orderId': widget.orderId,
        'type': _type,
        'message': text,
        'status': 'OPEN',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      _msg.clear();
      if (mounted) showAppAlert(context, 'وصلتنا رسالتك وهنرد عليك في أقرب وقت');
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر الإرسال: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: C.slate50,
        appBar: AppBar(
          backgroundColor: C.white,
          foregroundColor: C.slate900,
          title: Text('الدعم والشكاوى', style: T.s(16, T.w900, C.slate900)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.orderId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('مرتبطة بالطلب: ${widget.orderId!.substring(0, widget.orderId!.length < 6 ? widget.orderId!.length : 6)}',
                    style: T.s(11, T.w700, C.slate500)),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _typeLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() => _type = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msg,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                  hintText: 'اشرح المشكلة بالتفصيل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: Text(_sending ? 'جاري الإرسال...' : 'إرسال'),
            ),
            const SizedBox(height: 24),
            Text('رسائلي السابقة', style: T.s(14, T.w900, C.slate900)),
            const SizedBox(height: 8),
            if (_error != null)
              Text('تعذر تحميل الرسائل', style: T.s(12, T.w700, C.rose500))
            else if (_tickets.isEmpty)
              Text('لا توجد رسائل', style: T.s(12, T.w500, C.slate400))
            else
              for (final t in _tickets)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_typeLabels[t['type']] ?? t['type']} • ${_statusLabels[t['status']] ?? t['status']}',
                          style: T.s(11, T.w900, C.emerald700)),
                      const SizedBox(height: 4),
                      Text('${t['message']}', style: T.s(12, T.w500, C.slate700)),
                      if ((t['resolution'] as String?)?.isNotEmpty ?? false) ...[
                        const Divider(height: 16),
                        Text('رد الإدارة: ${t['resolution']}', style: T.s(12, T.w700, C.slate900)),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
