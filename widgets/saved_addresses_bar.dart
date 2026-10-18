import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'common.dart';

/// عنوان محفوظ للعميل (البيت، الشغل...). بنخزّن النقطة (لو متحددة بالخريطة) و/أو القرية
/// المعروفة والملاحظة، عشان يرجّعه بضغطة بدل ما يحدده من الأول كل مرة.
class SavedAddress {
  final String id, label, placeName, displayText, note;
  final String? area, villageId;
  final double? lat, lng;
  const SavedAddress({
    required this.id,
    required this.label,
    this.placeName = '',
    this.displayText = '',
    this.note = '',
    this.area,
    this.villageId,
    this.lat,
    this.lng,
  });

  factory SavedAddress.fromMap(Map<String, dynamic> m, String id) => SavedAddress(
        id: id,
        label: (m['label'] as String?) ?? '',
        placeName: (m['placeName'] as String?) ?? '',
        displayText: (m['displayText'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        area: m['area'] as String?,
        villageId: m['villageId'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

/// شريط العناوين المحفوظة فوق اختيار نقطة الوصول.
/// [currentData] بترجّع بيانات الوجهة الحالية (placeName/displayText/area/lat/lng/villageId/note)
/// أو null لو لسه مفيش وجهة متحددة.
class SavedAddressesBar extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? Function() currentData;
  final void Function(SavedAddress) onSelect;
  const SavedAddressesBar(
      {super.key, required this.userId, required this.currentData, required this.onSelect});

  @override
  State<SavedAddressesBar> createState() => _SavedAddressesBarState();
}

class _SavedAddressesBarState extends State<SavedAddressesBar> {
  List<SavedAddress> _items = [];
  StreamSubscription? _sub;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sub = db
        .collection('saved_addresses')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((d) => SavedAddress.fromMap(stripFirestore(d.data()) as Map<String, dynamic>, d.id))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
      if (mounted) setState(() => _items = list);
    }, onError: (e) => debugPrint('saved addresses unavailable: $e'));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    final data = widget.currentData();
    if (data == null) {
      showAppAlert(context, 'حدّد نقطة الوصول الأول وبعدين احفظها');
      return;
    }
    if (_items.length >= 10) {
      showAppAlert(context, 'وصلت للحد الأقصى (10 عناوين). امسح عنوان قبل ما تضيف جديد');
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حفظ العنوان'),
          content: TextField(
            controller: ctrl,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'اسم العنوان (البيت، الشغل...)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final label = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || label.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      await db.collection('saved_addresses').add({
        ...stripFirestore(data) as Map<String, dynamic>,
        'userId': widget.userId,
        'label': label,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر حفظ العنوان: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SavedAddress a) async {
    try {
      await db.collection('saved_addresses').doc(a.id).delete();
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر مسح العنوان');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('عناويني المحفوظة', style: T.s(11, T.w900, C.slate500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final a in _items)
              InputChip(
                avatar: const Icon(LucideIcons.mapPin, size: 14),
                label: Text(a.label),
                onPressed: () => widget.onSelect(a),
                onDeleted: () => _delete(a),
              ),
            ActionChip(
              avatar: const Icon(LucideIcons.plusCircle, size: 14),
              label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الوجهة الحالية'),
              onPressed: _saving ? null : _saveCurrent,
            ),
          ],
        ),
      ],
    );
  }
}
