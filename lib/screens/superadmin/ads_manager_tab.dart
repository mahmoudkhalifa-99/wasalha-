import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

/// إدارة الإعلانات - مقابلة لملف pages/AdminAdsManager.tsx بنسخة الويب
/// (ملحوظة: بترفع رابط صورة بدل رفع صورة من الجهاز مباشرة، للحفاظ على البساطة)
class AdsManagerTab extends StatefulWidget {
  const AdsManagerTab({super.key});

  @override
  State<AdsManagerTab> createState() => _AdsManagerTabState();
}

class _AdsManagerTabState extends State<AdsManagerTab> {
  bool isAdding = false;
  String? editingId;

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imageCtrl = TextEditingController();
  final ctaCtrl = TextEditingController(text: 'استفد من العرض الآن');
  final whatsappCtrl = TextEditingController();
  final orderCtrl = TextEditingController(text: '0');
  AdType type = AdType.special_offer;
  bool isActive = true;
  bool saving = false;

  void _startAdd() {
    setState(() {
      isAdding = true;
      editingId = null;
      titleCtrl.clear();
      descCtrl.clear();
      imageCtrl.clear();
      ctaCtrl.text = 'استفد من العرض الآن';
      whatsappCtrl.clear();
      orderCtrl.text = '0';
      type = AdType.special_offer;
      isActive = true;
    });
  }

  void _startEdit(Ad ad) {
    setState(() {
      isAdding = true;
      editingId = ad.id;
      titleCtrl.text = ad.title;
      descCtrl.text = ad.description;
      imageCtrl.text = ad.imageUrl;
      ctaCtrl.text = ad.ctaText;
      whatsappCtrl.text = ad.whatsappNumber ?? '';
      orderCtrl.text = '${ad.displayOrder}';
      type = ad.type;
      isActive = ad.isActive;
    });
  }

  void _cancelForm() => setState(() => isAdding = false);

  Future<void> _save() async {
    if (titleCtrl.text.trim().isEmpty || imageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى ملء العنوان ورابط صورة الإعلان')));
      return;
    }
    setState(() => saving = true);
    try {
      final id = editingId ?? 'ad_${DateTime.now().millisecondsSinceEpoch}';
      final ad = Ad(
        id: id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        imageUrl: imageCtrl.text.trim(),
        ctaText: ctaCtrl.text.trim(),
        type: type,
        whatsappNumber: whatsappCtrl.text.trim().replaceAll(' ', ''),
        isActive: isActive,
        displayOrder: int.tryParse(orderCtrl.text.trim()) ?? 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await FirebaseService.instance.saveAd(ad);
      if (!mounted) return;
      setState(() => isAdding = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ الإعلان بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الحفظ')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: const Text('هذا الإجراء لا يمكن التراجع عنه'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.deleteAd(id);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    imageCtrl.dispose();
    ctaCtrl.dispose();
    whatsappCtrl.dispose();
    orderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isAdding
          ? null
          : FloatingActionButton.extended(
              onPressed: _startAdd,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.campaign),
              label: const Text('إعلان جديد'),
            ),
      body: isAdding ? _buildForm() : _buildList(),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Ad>>(
      stream: FirebaseService.instance.allAdsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final ads = snap.data!;
        if (ads.isEmpty) {
          return const Center(
              child: Text('لا توجد إعلانات بعد، أضف أول إعلان ترويجي',
                  style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700)));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          itemCount: ads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final ad = ads[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: ad.imageUrl.isNotEmpty
                        ? Image.network(ad.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppColors.cardDark))
                        : Container(color: AppColors.cardDark),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ad.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.visibility, size: 12, color: Colors.black38),
                              const SizedBox(width: 3),
                              Text('${ad.views}', style: const TextStyle(fontSize: 10, color: Colors.black45)),
                              const SizedBox(width: 10),
                              const Icon(Icons.touch_app, size: 12, color: Colors.black38),
                              const SizedBox(width: 3),
                              Text('${ad.clicks}', style: const TextStyle(fontSize: 10, color: Colors.black45)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Switch(
                    value: ad.isActive,
                    activeColor: AppColors.primary,
                    onChanged: (v) => FirebaseService.instance.toggleAdActive(ad.id, v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _startEdit(ad),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _delete(ad.id),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.close), onPressed: _cancelForm),
            Text(editingId == null ? 'إعلان جديد' : 'تعديل الإعلان',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        _label('عنوان الإعلان'),
        TextField(controller: titleCtrl, decoration: _dec('مثال: عرض خصم 20% على التوصيل')),
        const SizedBox(height: 12),
        _label('الوصف'),
        TextField(controller: descCtrl, maxLines: 3, decoration: _dec('تفاصيل العرض...')),
        const SizedBox(height: 12),
        _label('رابط صورة الإعلان'),
        TextField(controller: imageCtrl, decoration: _dec('https://...')),
        const SizedBox(height: 12),
        _label('نص زر الدعوة للعمل'),
        TextField(controller: ctaCtrl, decoration: _dec('اطلب الآن')),
        const SizedBox(height: 12),
        _label('رقم واتساب (اختياري)'),
        TextField(controller: whatsappCtrl, keyboardType: TextInputType.phone, decoration: _dec('20xxxxxxxxxx')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<AdType>(
                initialValue: type,
                decoration: _dec(''),
                items: AdType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(enumToStr(t))))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? AdType.general),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: TextField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec('الترتيب'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: isActive,
          onChanged: (v) => setState(() => isActive = v),
          activeThumbColor: AppColors.primary,
          title: const Text('إعلان فعّال ويظهر للمستخدمين'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('حفظ الإعلان', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black12)),
      );
}
