import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

/// التعديل الشامل لعضو - مقابلة لملف pages/AdminEditUser.tsx بنسخة الويب
/// (بدون حقل تعديل كلمة المرور مباشرة، للحفاظ على أمان البيانات - غيّرها
/// المستخدم بنفسه أو عبر إعادة تعيين رسمية من Firebase Auth)
class AdminEditUserScreen extends StatefulWidget {
  final AppUser user;
  const AdminEditUserScreen({super.key, required this.user});

  @override
  State<AdminEditUserScreen> createState() => _AdminEditUserScreenState();
}

class _AdminEditUserScreenState extends State<AdminEditUserScreen> {
  late final nameCtrl = TextEditingController(text: widget.user.name);
  late final phoneCtrl = TextEditingController(text: widget.user.phone);
  late final emailCtrl = TextEditingController(text: widget.user.email);
  late final balanceCtrl =
      TextEditingController(text: widget.user.wallet.balance.toStringAsFixed(1));

  late UserRole role = widget.user.role;
  late UserStatus status = widget.user.status;
  late VehicleType vehicleType = widget.user.vehicleType ?? VehicleType.TOKTOK;
  bool saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FirebaseService.instance.updateUserFull(
        userId: widget.user.id,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        role: role,
        status: status,
        vehicleType: role == UserRole.DRIVER ? vehicleType : null,
        walletBalance: double.tryParse(balanceCtrl.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ كافة التعديلات الشاملة بنجاح')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل حفظ التعديلات، يرجى التحقق من الاتصال')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('التعديل الشامل: ${widget.user.name}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _Section(
            title: 'المعلومات الشخصية',
            icon: Icons.person_outline,
            children: [
              _labeled('الاسم الرباعي', TextField(controller: nameCtrl, decoration: _dec())),
              const SizedBox(height: 14),
              _labeled(
                  'رقم الهاتف',
                  TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: _dec())),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'بيانات الدخول',
            icon: Icons.lock_outline,
            children: [
              _labeled(
                  'البريد الإلكتروني',
                  TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: _dec())),
            ],
          ),
          if (role == UserRole.DRIVER) ...[
            const SizedBox(height: 16),
            _DarkSection(
              title: 'تفاصيل المركبة',
              icon: Icons.directions_car_outlined,
              child: Row(
                children: [
                  Expanded(child: _vehicleBtn(VehicleType.TOKTOK, '🛺 توك توك')),
                  const SizedBox(width: 10),
                  Expanded(child: _vehicleBtn(VehicleType.MOTORCYCLE, '🏍️ موتوسيكل')),
                  const SizedBox(width: 10),
                  Expanded(child: _vehicleBtn(VehicleType.CAR, '🚗 سيارة')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            title: 'إدارة الرصيد',
            icon: Icons.credit_card,
            children: [
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                decoration: _dec(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'الصلاحيات وحالة التفعيل',
            icon: Icons.settings_outlined,
            children: [
              _labeled(
                'رتبة العضو',
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: _dec(),
                  items: const [
                    DropdownMenuItem(value: UserRole.CUSTOMER, child: Text('عميل (Customer)')),
                    DropdownMenuItem(value: UserRole.DRIVER, child: Text('كابتن (Driver)')),
                    DropdownMenuItem(value: UserRole.OPERATOR, child: Text('مشغل (Operator)')),
                    DropdownMenuItem(value: UserRole.ADMIN, child: Text('مدير (Admin)')),
                  ],
                  onChanged: (v) => setState(() => role = v ?? UserRole.CUSTOMER),
                ),
              ),
              const SizedBox(height: 14),
              _labeled(
                'حالة الحساب',
                DropdownButtonFormField<UserStatus>(
                  initialValue: status,
                  decoration: _dec(),
                  items: const [
                    DropdownMenuItem(value: UserStatus.APPROVED, child: Text('مفعل (نشط الآن)')),
                    DropdownMenuItem(
                        value: UserStatus.PENDING_APPROVAL, child: Text('معلق (بانتظار مراجعة)')),
                    DropdownMenuItem(value: UserStatus.SUSPENDED, child: Text('محظور (موقوف مؤقتاً)')),
                  ],
                  onChanged: (v) => setState(() => status = v ?? UserStatus.APPROVED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('حفظ التعديلات الشاملة',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تنبيه أمان للمسؤول: تغيير البريد الإلكتروني أو الهاتف قد يؤثر على تجربة دخول العضو. تأكد من صحة البيانات قبل الحفظ.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleBtn(VehicleType v, String label) {
    final active = vehicleType == v;
    return InkWell(
      onTap: () => setState(() => vehicleType = v),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? Colors.white : Colors.transparent, width: 2),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45)),
        ),
        field,
      ],
    );
  }

  InputDecoration _dec() => InputDecoration(
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DarkSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _DarkSection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF34D399), size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
