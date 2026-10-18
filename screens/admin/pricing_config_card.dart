import 'package:flutter/material.dart';

import '../../config_constants.dart';
import '../../services/pricing_config_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';

/// تعديل التسعير والعمولة من التطبيق (من غير نشر نسخة جديدة). الحدود نفس حدود القواعد:
/// أجرة بين 25 و900، عمولة 0–40%. الأوردرات القديمة بتفضل بسعرها.
class PricingConfigCard extends StatefulWidget {
  final String userId;
  const PricingConfigCard({super.key, required this.userId});

  @override
  State<PricingConfigCard> createState() => _PricingConfigCardState();
}

class _PricingConfigCardState extends State<PricingConfigCard> {
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  static const _labels = {
    'basePrice': 'السعر الأساسي (ج.م)',
    'pricePerKm': 'سعر الكيلو للمشاوير',
    'foodOutsidePricePerKm': 'سعر كيلو توصيل الطلبات',
    'sameVillagePrice': 'سعر داخل نفس القرية',
    'maxPrice': 'أقصى أجرة (حتى 900)',
    'commissionPercent': 'عمولة التطبيق %',
  };

  @override
  void initState() {
    super.initState();
    final p = activePricing;
    final vals = {
      'basePrice': p.basePrice,
      'pricePerKm': p.pricePerKm,
      'foodOutsidePricePerKm': p.foodOutsidePricePerKm,
      'sameVillagePrice': p.sameVillagePrice,
      'maxPrice': p.maxPrice,
      'commissionPercent': activeCommissionRate * 100,
    };
    _c = {
      for (final e in vals.entries)
        e.key: TextEditingController(text: e.value.toStringAsFixed(e.value % 1 == 0 ? 0 : 2))
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final v = <String, dynamic>{};
    for (final e in _c.entries) {
      final n = double.tryParse(e.value.text.trim());
      if (n == null || n < 0) {
        showAppAlert(context, 'رقم غير صالح في: ${_labels[e.key]}');
        return;
      }
      v[e.key] = n;
    }
    if ((v['maxPrice'] as double) < 25 || (v['maxPrice'] as double) > 900) {
      showAppAlert(context, 'أقصى أجرة لازم تكون بين 25 و900');
      return;
    }
    if ((v['sameVillagePrice'] as double) < 25 || (v['sameVillagePrice'] as double) > 900) {
      showAppAlert(context, 'سعر نفس القرية لازم يكون بين 25 و900');
      return;
    }
    if ((v['commissionPercent'] as double) > 40) {
      showAppAlert(context, 'العمولة لازم تكون 40% أو أقل');
      return;
    }
    setState(() => _saving = true);
    try {
      await savePricingConfig(v, widget.userId);
      if (mounted) showAppAlert(context, 'تم حفظ التسعير');
    } catch (e) {
      if (mounted) showAppAlert(context, 'تعذر الحفظ: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: C.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('التسعير والعمولة', style: T.s(15, T.w900, C.slate900)),
          const SizedBox(height: 10),
          for (final e in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _c[e.key],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: e.value, isDense: true),
              ),
            ),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ')),
        ],
      ),
    );
  }
}
