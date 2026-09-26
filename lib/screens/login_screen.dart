import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/village_picker.dart';
import 'onboarding_screen.dart';

enum _AuthStep { input, otp }

/// شاشة الدخول والتسجيل الكاملة - مقابلة لملف pages/Login.tsx في نسخة الويب
/// (تشمل: التعريف بالتطبيق Onboarding، تسجيل الدخول، إنشاء حساب مع تأكيد OTP
/// وهمي، تسجيل الدخول بجوجل، وإكمال البيانات لمستخدمي جوجل الجدد)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool showOnboarding = true;
  bool isRegistering = false;
  bool isCompletingProfile = false;
  _AuthStep step = _AuthStep.input;

  UserRole role = UserRole.CUSTOMER;
  VehicleType vehicleType = VehicleType.TOKTOK;

  // بيانات التسجيل
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  VillageData? selectedVillage;
  String? selectedZoneId;
  bool showPassword = false;
  bool showConfirmPassword = false;

  // بيانات تسجيل الدخول
  final loginEmailCtrl = TextEditingController();
  final loginPasswordCtrl = TextEditingController();
  bool rememberMe = false;

  // OTP وهمي (نفس فكرة نسخة الويب - مفيش SMS حقيقي، بس خطوة تأكيد شكلية)
  final List<TextEditingController> otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> otpNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int resendSeconds = 60;
  bool canResend = false;

  // إكمال بيانات جوجل
  fb_auth.User? pendingGoogleUser;

  bool loading = false;
  String? errorMsg;

  final _formKey = GlobalKey<FormState>();

  static const List<String> centers = [
    'شبين الكوم',
    'منوف',
    'أشمون',
    'الباجور',
    'قويسنا',
    'بركة السبع',
    'تلا',
    'السادات',
    'الشهداء',
  ];

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in otpCtrls) {
      c.dispose();
    }
    for (final n in otpNodes) {
      n.dispose();
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    loginEmailCtrl.dispose();
    loginPasswordCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    resendSeconds = 60;
    canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (resendSeconds > 0) {
          resendSeconds -= 1;
        } else {
          canResend = true;
          t.cancel();
        }
      });
    });
  }

  void _resendOtp() {
    if (!canResend) return;
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إعادة إرسال كود التفعيل إلى رقمك')),
    );
  }

  Future<void> _pickLocation() async {
    final v = await pickVillage(context);
    if (v == null) return;
    setState(() {
      selectedVillage = v;
      selectedZoneId = districtIdOfVillage(v.id);
    });
  }

  bool _validateSignUp() {
    final parts = nameCtrl.text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.length < 4) {
      setState(() => errorMsg = 'برجاء إدخال الاسم رباعي لضمان التوثيق');
      return false;
    }
    final phoneRegex = RegExp(r'^(010|011|012|015)[0-9]{8}$');
    if (!phoneRegex.hasMatch(phoneCtrl.text.trim())) {
      setState(() => errorMsg = 'رقم الهاتف غير صحيح (010, 011, 012, 015)');
      return false;
    }
    if (!emailCtrl.text.contains('@')) {
      setState(() => errorMsg = 'البريد الإلكتروني غير صحيح');
      return false;
    }
    if (passwordCtrl.text.length < 8) {
      setState(() => errorMsg = 'كلمة المرور يجب ألا تقل عن 8 رموز');
      return false;
    }
    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      setState(() => errorMsg = 'كلمة المرور غير متطابقة');
      return false;
    }
    if (selectedVillage == null) {
      setState(() => errorMsg = 'يرجى اختيار المركز والقرية');
      return false;
    }
    return true;
  }

  Future<void> _handleAuth() async {
    setState(() => errorMsg = null);

    if (isRegistering && step == _AuthStep.input) {
      if (!_validateSignUp()) return;
      setState(() => step = _AuthStep.otp);
      _startResendTimer();
      return;
    }

    setState(() => loading = true);
    final fb = FirebaseService.instance;
    try {
      if (isRegistering) {
        final code = otpCtrls.map((c) => c.text).join();
        if (code.length < 6) {
          setState(() => errorMsg = 'الكود غير مكتمل');
          return;
        }
        fb.isCreatingUserProfile = true;
        final cred = await fb.register(emailCtrl.text.trim(), passwordCtrl.text.trim());
        final user = AppUser(
          id: cred.user!.uid,
          email: emailCtrl.text.trim(),
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          role: role,
          status: role == UserRole.DRIVER ? UserStatus.PENDING_APPROVAL : UserStatus.APPROVED,
          vehicleType: role == UserRole.DRIVER ? vehicleType : null,
          zoneId: selectedZoneId,
          wallet: const Wallet(),
        );
        await fb.createUserDoc(cred.user!.uid, user);
      } else {
        await fb.signIn(loginEmailCtrl.text.trim(), loginPasswordCtrl.text.trim());
      }
      // التوجيه للوحة المناسبة بيحصل تلقائيًا عبر AuthGate اللي بيستمع لحالة الدخول
    } on fb_auth.FirebaseAuthException catch (e) {
      setState(() => errorMsg = _mapAuthError(e.code));
    } catch (e) {
      setState(() => errorMsg = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      fb.isCreatingUserProfile = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    final fb = FirebaseService.instance;
    try {
      final cred = await fb.signInWithGoogle();
      if (cred == null) {
        setState(() => loading = false);
        return; // المستخدم لغى تسجيل الدخول
      }
      final fbUser = cred.user!;
      final existing = await fb.getUser(fbUser.uid);
      if (existing != null && existing.phone.isNotEmpty && existing.phone != '01000000000') {
        // مستخدم موجود بالفعل وبياناته مكتملة - الـ AuthGate هيوجهه تلقائيًا
        return;
      }
      // مستخدم جديد أو ناقص بياناته - نطلب منه إكمالها
      fb.isCreatingUserProfile = true;
      setState(() {
        pendingGoogleUser = fbUser;
        nameCtrl.text = existing?.name ?? fbUser.displayName ?? '';
        emailCtrl.text = existing?.email ?? fbUser.email ?? '';
        isCompletingProfile = true;
      });
    } catch (e) {
      setState(() => errorMsg = 'فشل تسجيل الدخول عبر جوجل، يرجى المحاولة مرة أخرى.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleCompleteGoogleProfile() async {
    if (pendingGoogleUser == null) return;
    if (phoneCtrl.text.trim().length < 11) {
      setState(() => errorMsg = 'يرجى إدخال رقم هاتف صحيح');
      return;
    }
    if (selectedVillage == null) {
      setState(() => errorMsg = 'يرجى اختيار المركز والقرية');
      return;
    }
    setState(() {
      loading = true;
      errorMsg = null;
    });
    final fb = FirebaseService.instance;
    try {
      final user = AppUser(
        id: pendingGoogleUser!.uid,
        email: emailCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        role: role,
        status: role == UserRole.DRIVER ? UserStatus.PENDING_APPROVAL : UserStatus.APPROVED,
        vehicleType: role == UserRole.DRIVER ? vehicleType : null,
        zoneId: selectedZoneId,
        wallet: const Wallet(),
      );
      await fb.createUserDoc(pendingGoogleUser!.uid, user);
      // الـ AuthGate هيلتقط المستند الجديد ويوجّه تلقائيًا للوحة المناسبة
    } catch (e) {
      setState(() => errorMsg = 'حدث خطأ أثناء حفظ البيانات');
    } finally {
      fb.isCreatingUserProfile = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    const adminWhatsApp = '201065019364';
    const message = 'أهلاً إدارة وصلها، نسيت كلمة المرور الخاصة بحسابي وأحتاج للمساعدة في استعادتها.';
    final uri = Uri.parse('https://wa.me/$adminWhatsApp?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة السر ضعيفة، استخدم 8 أحرف على الأقل';
      default:
        return 'حدث خطأ: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showOnboarding) {
      return OnboardingScreen(onComplete: () => setState(() => showOnboarding = false));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _Header(),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          if (errorMsg != null) _ErrorBanner(message: errorMsg!),
                          if (errorMsg != null) const SizedBox(height: 16),
                          if (isCompletingProfile)
                            _buildCompleteProfileForm()
                          else
                            _buildAuthForm(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'جميع الحقوق محفوظة © تطبيق وصلها المنوفية • خدمة ذكية على مدار 24 ساعة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('إكمال بياناتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('خطوة أخيرة للبدء: أضف هاتفك ومنطقتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
        const SizedBox(height: 18),
        _SegmentedTwo(
          leftLabel: 'أنا عميل 👤',
          rightLabel: 'أنا كابتن 🛵',
          leftSelected: role == UserRole.CUSTOMER,
          onLeft: () => setState(() => role = UserRole.CUSTOMER),
          onRight: () => setState(() => role = UserRole.DRIVER),
        ),
        const SizedBox(height: 14),
        _FieldBox(
          icon: Icons.smartphone,
          hint: 'رقم الهاتف (010...)',
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          ltr: true,
        ),
        const SizedBox(height: 14),
        _LocationPickerField(
          village: selectedVillage,
          zoneId: selectedZoneId,
          onTap: _pickLocation,
        ),
        if (role == UserRole.DRIVER) ...[
          const SizedBox(height: 14),
          _VehiclePicker(selected: vehicleType, onSelect: (v) => setState(() => vehicleType = v)),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          loading: loading,
          label: 'حفظ البيانات والدخول',
          onPressed: _handleCompleteGoogleProfile,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () async {
                    FirebaseService.instance.isCreatingUserProfile = false;
                    await FirebaseService.instance.signOut();
                    if (mounted) {
                      setState(() {
                        isCompletingProfile = false;
                        pendingGoogleUser = null;
                      });
                    }
                  },
            child: const Text('إلغاء والعودة لتسجيل الدخول',
                style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SegmentedTwo(
            leftLabel: 'تسجيل الدخول',
            rightLabel: 'إنشاء حساب جديد',
            leftSelected: !isRegistering,
            onLeft: () => setState(() {
              isRegistering = false;
              errorMsg = null;
            }),
            onRight: () => setState(() {
              isRegistering = true;
              step = _AuthStep.input;
              errorMsg = null;
            }),
          ),
          const SizedBox(height: 18),
          if (isRegistering)
            step == _AuthStep.input ? _buildRegisterInputs() : _buildOtpStep()
          else
            _buildLoginInputs(),
        ],
      ),
    );
  }

  Widget _buildRegisterInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SegmentedTwo(
          leftLabel: '👤 عميل (طلب رحلات)',
          rightLabel: '🛵 كابتن (توصيل طلبات)',
          leftSelected: role == UserRole.CUSTOMER,
          onLeft: () => setState(() => role = UserRole.CUSTOMER),
          onRight: () => setState(() => role = UserRole.DRIVER),
          compact: true,
        ),
        const SizedBox(height: 14),
        _FieldBox(icon: Icons.person_outline, hint: 'الاسم ثلاثي أو رباعي', controller: nameCtrl),
        const SizedBox(height: 14),
        _FieldBox(
          icon: Icons.smartphone,
          hint: 'رقم الهاتف (010...)',
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          ltr: true,
        ),
        const SizedBox(height: 14),
        _FieldBox(
          icon: Icons.mail_outline,
          hint: 'البريد الإلكتروني',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          ltr: true,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FieldBox(
                icon: Icons.lock_outline,
                hint: 'كلمة المرور',
                controller: passwordCtrl,
                obscure: !showPassword,
                ltr: true,
                suffix: IconButton(
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FieldBox(
                icon: Icons.lock_outline,
                hint: 'تأكيد الكلمة',
                controller: confirmPasswordCtrl,
                obscure: !showConfirmPassword,
                ltr: true,
                suffix: IconButton(
                  icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LocationPickerField(
          village: selectedVillage,
          zoneId: selectedZoneId,
          onTap: _pickLocation,
        ),
        if (role == UserRole.DRIVER) ...[
          const SizedBox(height: 14),
          _VehiclePicker(selected: vehicleType, onSelect: (v) => setState(() => vehicleType = v)),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(loading: loading, label: 'إنشاء الحساب والمتابعة', onPressed: _handleAuth),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تأكيد رقم الهاتف',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'أدخل الرمز المكون من 6 أرقام المرسل إلى\n',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38),
              ),
              TextSpan(
                text: phoneCtrl.text,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 42,
                  height: 56,
                  child: TextField(
                    controller: otpCtrls[i],
                    focusNode: otpNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: otpCtrls[i].text.isNotEmpty ? AppColors.primary : Colors.black12,
                            width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {});
                      if (v.isNotEmpty && i < 5) {
                        otpNodes[i + 1].requestFocus();
                      }
                    },
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(loading: loading, label: 'تأكيد الرمز', onPressed: _handleAuth),
        const SizedBox(height: 12),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _resendOtp,
                  child: const Text('إعادة إرسال الكود',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
                )
              : Text('إعادة الإرسال خلال $resendSeconds ثانية',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
        ),
        TextButton(
          onPressed: () => setState(() => step = _AuthStep.input),
          child: const Text('تعديل رقم الهاتف',
              style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildLoginInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldBox(
          icon: Icons.mail_outline,
          hint: 'البريد الإلكتروني',
          controller: loginEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          ltr: true,
        ),
        const SizedBox(height: 14),
        _FieldBox(
          icon: Icons.lock_outline,
          hint: 'كلمة المرور',
          controller: loginPasswordCtrl,
          obscure: !showPassword,
          ltr: true,
          suffix: IconButton(
            icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => setState(() => rememberMe = !rememberMe),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (v) => setState(() => rememberMe = v ?? false),
                    visualDensity: VisualDensity.compact,
                    activeColor: AppColors.primary,
                  ),
                  const Text('تذكرني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            TextButton(
              onPressed: _handleForgotPassword,
              child: const Text('نسيت كلمة المرور؟',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PrimaryButton(loading: loading, label: 'تسجيل الدخول', onPressed: _handleAuth, big: true),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('أو المتابعة السريعة عبر',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: loading ? null : _handleGoogleLogin,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.black12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.g_mobiledata, size: 26, color: Colors.black87),
          label: const Text('المتابعة باستخدام Google',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF0F766E)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
          const Text('وصـــلــهــا',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('خدمة التوصيل الذكية الأولى بمحافظة المنوفية',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Pill(emoji: '🛺', label: 'توكتوك'),
              _Pill(emoji: '🚗', label: 'سيارة'),
              _Pill(emoji: '🏍️', label: 'دليفري'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String emoji;
  final String label;
  const _Pill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text('$emoji $label',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE4E6)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTwo extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final bool compact;
  const _SegmentedTwo({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _segBtn(leftLabel, leftSelected, onLeft)),
          const SizedBox(width: 4),
          Expanded(child: _segBtn(rightLabel, !leftSelected, onRight)),
        ],
      ),
    );
  }

  Widget _segBtn(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w900,
            color: selected ? AppColors.primaryDark : Colors.black45,
          ),
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final bool ltr;
  final TextInputType? keyboardType;
  final Widget? suffix;
  const _FieldBox({
    required this.icon,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.ltr = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      textAlign: ltr ? TextAlign.left : TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.bg,
        prefixIcon: Icon(icon, size: 20, color: Colors.black38),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
    return field;
  }
}

class _LocationPickerField extends StatelessWidget {
  final VillageData? village;
  final String? zoneId;
  final VoidCallback onTap;
  const _LocationPickerField({required this.village, required this.zoneId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 20, color: Colors.black38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                village == null ? 'اختر المركز والقرية' : '${village!.name} • ${zoneId ?? ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: village == null ? Colors.black38 : AppColors.primaryDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_left, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  final VehicleType selected;
  final ValueChanged<VehicleType> onSelect;
  const _VehiclePicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      (VehicleType.TOKTOK, 'توك توك', '🛺', 'أصفر • اقتصادي', const Color(0xFFF59E0B)),
      (VehicleType.CAR, 'سيارة', '🚗', 'مريح وسريع', const Color(0xFF0F172A)),
      (VehicleType.MOTORCYCLE, 'دليفري', '🏍️', 'أخضر • سريع', AppColors.primary),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('حدد مركبتك (كما تظهر في شعار وصلها)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: options.map((o) {
              final active = selected == o.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => onSelect(o.$1),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? o.$5.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: active ? o.$5 : Colors.black12, width: active ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Text(o.$3, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(o.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          Text(o.$4,
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  final bool big;
  const _PrimaryButton({required this.loading, required this.label, required this.onPressed, this.big = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: big ? 18 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: loading
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 15 : 13)),
      ),
    );
  }
}
