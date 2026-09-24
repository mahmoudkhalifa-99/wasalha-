import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

/// صوتك مسموع - مقابلة لملف pages/SupportView.tsx بنسخة الويب
class SupportScreen extends StatefulWidget {
  final AppUser user;
  const SupportScreen({super.key, required this.user});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  int rating = 5;
  final opinionCtrl = TextEditingController();
  bool submitting = false;
  bool submitted = false;

  @override
  void dispose() {
    opinionCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/201065019364');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    if (opinionCtrl.text.trim().isEmpty) return;
    setState(() => submitting = true);
    try {
      await FirebaseService.instance.submitFeedback(
        user: widget.user,
        rating: rating,
        opinion: opinionCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        submitted = true;
        opinionCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء إرسال رأيك، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('صوتك مسموع')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('تواصل مباشر مع الإدارة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                const Text('فريقنا متاح لمساعدتك وحل أي مشكلة تواجهك فوراً',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _openWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('واتساب الدعم الفني',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.black12),
            ),
            child: submitted ? _buildThanks() : _buildForm(),
          ),
          const SizedBox(height: 24),
          Opacity(
            opacity: 0.35,
            child: Column(
              children: const [
                Icon(Icons.pedal_bike, size: 48, color: Colors.black),
                SizedBox(height: 6),
                Text('وصـــلــهــا',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThanks() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          const Text('شكراً لرسالتك الصادقة!',
              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          const Text('تم استلام رأيك بنجاح، وسيكون الدافع لنا للتطوير الدائم',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => submitted = false),
            child: const Text('إرسال تعليق آخر',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.auto_awesome, color: Color(0xFFD97706), size: 32),
        ),
        const SizedBox(height: 14),
        const Text('رأيك يهمنا لنطور "وصـــلــهــا"',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 6),
        const Text('كل تعليق ترسله يصل مباشرة للمسؤولين',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const Text('تقييمك لتجربة التطبيق',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final s = i + 1;
              final active = rating >= s;
              return IconButton(
                onPressed: () => setState(() => rating = s),
                icon: Icon(active ? Icons.star : Icons.star_border,
                    color: active ? Colors.amber : Colors.black26, size: 30),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: Text('اكتب ملاحظاتك أو اقتراحاتك',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: opinionCtrl,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'هل لديك فكرة تطوير؟ أو مشكلة واجهتك؟ اكتبها هنا بكل صراحة...',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (submitting || opinionCtrl.text.trim().isEmpty) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            icon: submitting
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('إرسال رسالتك الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
