import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import 'onboarding_screen.dart';

enum _OtpStep { input, otp }

const String _googleSvg = '''
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
<path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
<path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>
<path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
<path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>
</svg>
''';

/// نسخة Flutter من pages/Login.tsx — نفس المنطق والتصميم.
class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showOnboarding = true;
  bool _isRegistering = false;
  bool _isCompletingProfile = false;
  _OtpStep _step = _OtpStep.input;
  UserRole _role = UserRole.customer; // CUSTOMER | DRIVER
  VehicleType _vehicleType = VehicleType.toktok;

  // Profile data
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _village = TextEditingController();
  String _center = '';
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // OTP
  final List<String> _otp = List.filled(6, '');
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;

  // Login
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _rememberMe = false;

  // General
  bool _loading = false;
  String? _errorMsg;

  // بيانات مستخدم جوجل الضرورية فقط
  ({String uid, String email, String displayName})? _googleUserData;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_step == _OtpStep.otp && _resendTimer > 0) {
        setState(() => _resendTimer--);
      }
      if (_resendTimer == 0 && !_canResend) {
        setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _name, _phone, _email, _password, _confirmPassword, _village,
      _loginEmail, _loginPassword, ..._otpCtrls
    ]) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── المنطق ─────────────────────────

  void _handleResendOtp() {
    if (!_canResend) return;
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    // Logic to resend OTP via WhatsApp/SMS
    showAppAlert(context, 'تم إعادة إرسال كود التفعيل إلى رقمك');
  }

  Future<void> _handleForgotPassword() async {
    const adminWhatsApp = '201065019364';
    const message =
        'أهلاً إدارة وصلها، نسيت كلمة المرور الخاصة بحسابي وأحتاج للمساعدة في استعادتها.';
    final url = Uri.parse(
        'https://wa.me/$adminWhatsApp?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  bool _validateSignUp() {
    if (_name.text.trim().split(RegExp(r'\s+')).length < 4) {
      setState(() => _errorMsg = 'برجاء إدخال الاسم رباعي لضمان التوثيق');
      return false;
    }
    if (!RegExp(r'^(010|011|012|015)[0-9]{8}$').hasMatch(_phone.text)) {
      setState(() => _errorMsg = 'رقم الهاتف غير صحيح (010, 011, 012, 015)');
      return false;
    }
    if (!_email.text.contains('@')) {
      setState(() => _errorMsg = 'البريد الإلكتروني غير صحيح');
      return false;
    }
    if (_password.text.length < 8) {
      setState(() => _errorMsg = 'كلمة المرور يجب ألا تقل عن 8 رموز');
      return false;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _errorMsg = 'كلمة المرور غير متطابقة');
      return false;
    }
    if (_center.isEmpty || _village.text.isEmpty) {
      setState(() => _errorMsg = 'يرجى اختيار المركز والقرية');
      return false;
    }
    return true;
  }

  /// مكافئ رسالة المتصفح لحقول required الفارغة
  bool _requireFilled(List<String> values) {
    if (values.any((v) => v.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text('يُرجى ملء هذا الحقل',
                style: T.s(12, T.w700, C.white)),
          ),
          duration: const Duration(seconds: 2),
        ));
      return false;
    }
    return true;
  }

  AppUser _defaultUserFor(fb.User u) {
    final isAdminEmail = adminEmails.contains((u.email ?? '').toLowerCase());
    return AppUser(
      id: u.uid,
      email: u.email ?? '',
      name: isAdminEmail ? 'مدير المنظومة' : (u.displayName ?? 'مستخدم'),
      phone: '01000000000',
      role: isAdminEmail ? UserRole.admin : UserRole.customer,
      status: UserStatus.approved,
      zoneId: 'أشمون',
      wallet: const Wallet(balance: 1000, totalEarnings: 0, withdrawn: 0),
    );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final result = await signInWithGoogle();
      final u = result.user!;
      final userSnap = await db.collection('users').doc(u.uid).get();

      if (userSnap.exists) {
        final userData = AppUser.fromMap(
            stripFirestore(userSnap.data()) as Map<String, dynamic>, userSnap.id);
        if (userData.phone.isEmpty) {
          setState(() {
            _googleUserData = (
              uid: u.uid,
              email: u.email ?? '',
              displayName: u.displayName ?? ''
            );
            _name.text = userData.name.isNotEmpty
                ? userData.name
                : (u.displayName ?? '');
            _email.text =
                userData.email.isNotEmpty ? userData.email : (u.email ?? '');
            _isCompletingProfile = true;
          });
        } else {
          widget.onLogin(userData);
        }
      } else {
        setState(() {
          _googleUserData = (
            uid: u.uid,
            email: u.email ?? '',
            displayName: u.displayName ?? ''
          );
          _name.text = u.displayName ?? '';
          _email.text = u.email ?? '';
          _isCompletingProfile = true;
        });
      }
    } catch (error) {
      debugPrint('Google sign-in error: $error');
      // المستخدم لغى نافذة تسجيل الدخول بنفسه، مفيش داعي نظهر رسالة خطأ
      if (!isGoogleSignInCancelled(error)) {
        final code = error is fb.FirebaseAuthException ? error.code : error.runtimeType.toString();
        final hint = switch (code) {
          'invalid-cert-hash' || 'app-not-authorized' =>
            'بصمة SHA-1 للتطبيق مش مسجلة في Firebase',
          'operation-not-allowed' => 'تسجيل الدخول بجوجل مش مفعّل في Firebase',
          'network-request-failed' => 'تأكد من الاتصال بالإنترنت',
          _ => 'يرجى المحاولة مرة أخرى',
        };
        setState(() => _errorMsg = 'فشل تسجيل الدخول عبر جوجل: $hint ($code)');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCompleteGoogleProfile() async {
    final g = _googleUserData;
    if (g == null) return;
    if (!_requireFilled([_phone.text, _center, _village.text])) return;
    if (_phone.text.isEmpty || _phone.text.length < 11) {
      setState(() => _errorMsg = 'يرجى إدخال رقم هاتف صحيح');
      return;
    }
    if (_center.isEmpty || _village.text.isEmpty) {
      setState(() => _errorMsg = 'يرجى اختيار المركز والقرية');
      return;
    }

    setState(() => _loading = true);
    try {
      final userData = AppUser(
        id: g.uid,
        email: _email.text,
        name: _name.text,
        phone: _phone.text,
        role: _role,
        status: _role == UserRole.driver
            ? UserStatus.pendingApproval
            : UserStatus.approved,
        vehicleType: _role == UserRole.driver ? _vehicleType : null,
        zoneId: _center,
        wallet: const Wallet(balance: 0, totalEarnings: 0, withdrawn: 0),
      );
      // نستخدم stripFirestore للتأكد من نظافة الكائن تماماً
      await db.collection('users').doc(g.uid).set(userData.toMap());
      widget.onLogin(userData);
    } catch (e) {
      setState(() => _errorMsg = 'حدث خطأ أثناء حفظ البيانات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAuth() async {
    setState(() => _errorMsg = null);

    if (_isRegistering && _step == _OtpStep.input) {
      if (!_requireFilled([
        _name.text, _phone.text, _email.text, _password.text,
        _confirmPassword.text, _center, _village.text
      ])) return;
      if (!_validateSignUp()) return;
      setState(() => _step = _OtpStep.otp);
      return;
    }
    if (!_isRegistering) {
      if (!_requireFilled([_loginEmail.text, _loginPassword.text])) return;
    }

    setState(() => _loading = true);
    try {
      if (_isRegistering) {
        if (_otp.join().length < 6) {
          setState(() {
            _errorMsg = 'الكود غير مكتمل';
            _loading = false;
          });
          return;
        }

        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text, password: _password.text);
        final userData = AppUser(
          id: cred.user!.uid,
          email: _email.text,
          name: _name.text,
          phone: _phone.text,
          role: _role,
          status: _role == UserRole.driver
              ? UserStatus.pendingApproval
              : UserStatus.approved,
          vehicleType: _role == UserRole.driver ? _vehicleType : null,
          zoneId: _center,
          wallet: const Wallet(balance: 0, totalEarnings: 0, withdrawn: 0),
        );
        await db.collection('users').doc(cred.user!.uid).set(userData.toMap());
        widget.onLogin(userData);
      } else {
        final cred = await auth.signInWithEmailAndPassword(
            email: _loginEmail.text, password: _loginPassword.text);
        final userSnap = await db.collection('users').doc(cred.user!.uid).get();
        if (userSnap.exists) {
          widget.onLogin(AppUser.fromMap(
              stripFirestore(userSnap.data()) as Map<String, dynamic>,
              userSnap.id));
        } else {
          final defaultUser = _defaultUserFor(cred.user!);
          await db
              .collection('users')
              .doc(cred.user!.uid)
              .set(defaultUser.toMap());
          widget.onLogin(defaultUser);
        }
      }
    } catch (err) {
      setState(() => _errorMsg = 'البريد أو كلمة المرور غير صحيحة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleOtpChange(int index, String value) {
    if (value.isNotEmpty && int.tryParse(value) == null) return;
    final v = value.isEmpty ? '' : value.substring(value.length - 1);
    setState(() => _otp[index] = v);
    if (_otpCtrls[index].text != v) _otpCtrls[index].text = v;
    if (value.isNotEmpty && index < 5) _otpNodes[index + 1].requestFocus();
  }

  void _handleOtpKey(int index, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _otp[index].isEmpty &&
        index > 0) {
      _otpNodes[index - 1].requestFocus();
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(
          onComplete: () => setState(() => _showOnboarding = false));
    }

    final md = isMd(context);
    return Scaffold(
      backgroundColor: C.slate50,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── خلفية الزينة (مطابقة لشعار التطبيق) ──
          Positioned.fill(child: _ambientBackground()),

          SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: md ? 48 : 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: (box.maxHeight - (md ? 96 : 64))
                          .clamp(0.0, double.infinity)),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 512),
                            child: _card(context, md),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            'جميع الحقوق محفوظة © تطبيق وصلها المنوفية • خدمة ذكية على مدار 24 ساعة',
                            textAlign: TextAlign.center,
                            style: T.s(12, T.w700, C.slate400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _ambientBackground() {
    return LayoutBuilder(builder: (context, box) {
      final cx = box.maxWidth / 2, cy = box.maxHeight / 2;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // قوس الزمرد العلوي
          Positioned(
            top: -160,
            left: cx - 325,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ui_blur(64),
                child: Container(
                  width: 650,
                  height: 650,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        C.emerald500.withOpacity(0.15),
                        C.teal500.withOpacity(0.05),
                        const Color(0x0014B8A6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
              bottom: -144, left: -144,
              child: Blob(size: 450, color: C.emerald600.withOpacity(0.10))),
          Positioned(
              bottom: -144, right: -144,
              child: Blob(size: 450, color: C.amber500.withOpacity(0.05))),
          // الحلقات المتحدة المركز مثل دبوس الخريطة في الشعار
          Positioned(
              left: cx - 360, top: cy - 360,
              child: Ring(size: 720, color: C.emerald500.withOpacity(0.10))),
          Positioned(
              left: cx - 490, top: cy - 490,
              child: Ring(size: 980, color: C.emerald500.withOpacity(0.05))),
        ],
      );
    });
  }

  Widget _card(BuildContext context, bool md) {
    final radius = BorderRadius.circular(md ? 48 : 40);
    return Reveal(
      child: GlassBox(
        sigma: 24,
        color: C.white.withOpacity(0.95),
        borderRadius: radius,
        border: Border.all(color: C.emerald500.withOpacity(0.15)),
        shadows: [
          BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.18),
              offset: const Offset(0, 25),
              blurRadius: 60,
              spreadRadius: -15),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, md),
            Padding(
              padding: EdgeInsets.all(md ? 32 : 24),
              child: _body(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String emoji, String label, Color bg, Color border, Color fg) {
    return GlassBox(
      sigma: 12,
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
      shadows: Sh.sm(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11, height: 1.5)),
          const SizedBox(width: 6),
          Text(label, style: T.s(11, T.w900, fg)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, bool md) {
    final iconSize = md ? 112.0 : 96.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(md ? 32 : 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.emerald700, C.emerald600, C.teal700],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              top: -48 - (md ? 32 : 24), right: -48 - (md ? 32 : 24),
              child: Blob(size: 160, color: C.white.withOpacity(0.10), blur: 40)),
          Positioned(
              bottom: -40 - (md ? 32 : 24), left: -40 - (md ? 32 : 24),
              child: Blob(
                  size: 144, color: C.emerald400.withOpacity(0.20), blur: 24)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [...Sh.xxl(), Sh.ring(C.white.withOpacity(0.3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/icon-192.png',
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('وصـــلــهــا',
                      style: T.s(md ? 36 : 30, T.w900, C.white,
                          letterSpacing: md ? -0.9 : -0.75)),
                  const SizedBox(width: 8),
                  const PingDot(size: 10, color: C.emerald300),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'خدمة التوصيل الذكية الأولى بمحافظة المنوفية',
                textAlign: TextAlign.center,
                style: T.s(md ? 14 : 12, T.w700, C.emerald100),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('🛺', 'توكتوك', C.amber400.withOpacity(0.20),
                      C.amber300.withOpacity(0.30), C.amber200),
                  _pill('🚗', 'سيارة', C.slate900.withOpacity(0.40),
                      C.white.withOpacity(0.20), C.white),
                  _pill('🏍️', 'دليفري', C.emerald400.withOpacity(0.20),
                      C.emerald300.withOpacity(0.30), C.emerald100),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.rose50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.rose100),
      ),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(color: C.rose500, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMsg!,
                textAlign: TextAlign.right,
                style: T.s(12, T.w900, C.rose600)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMsg != null) _errorBox(),
        if (_isCompletingProfile) _completeProfileForm() else _mainForm(context),
      ],
    );
  }

  // ── مكونات مشتركة ──

  Widget _gap(double h) => SizedBox(height: h);

  Widget _vehiclePicker() {
    final items = [
      (VehicleType.toktok, 'توك توك', '🛺', 'أصفر • اقتصادي'),
      (VehicleType.car, 'سيارة', '🚗', 'مريح وسريع'),
      (VehicleType.motorcycle, 'دليفري', '🏍️', 'أخضر • سريع'),
    ];

    ({Color border, Color bg, Color text, Color ring}) active(VehicleType t) {
      switch (t) {
        case VehicleType.toktok:
          return (
            border: C.amber500,
            bg: C.amber50.withOpacity(0.9),
            text: C.amber950,
            ring: C.amber400.withOpacity(0.5)
          );
        case VehicleType.car:
          return (
            border: C.slate800,
            bg: C.slate900,
            text: C.white,
            ring: C.slate700
          );
        case VehicleType.motorcycle:
          return (
            border: C.emerald500,
            bg: C.emerald50.withOpacity(0.9),
            text: C.emerald950,
            ring: C.emerald400.withOpacity(0.5)
          );
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.slate50.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.slate200.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('حدد مركبتك (كما تظهر في شعار وصلها)',
              textAlign: TextAlign.right,
              style: T.s(10, T.w900, C.slate700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(builder: (context) {
                    final v = items[i];
                    final isActive = _vehicleType == v.$1;
                    final a = active(v.$1);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _vehicleType = v.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive ? a.bg : C.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isActive ? a.border : C.slate200),
                          boxShadow: isActive
                              ? [...Sh.sm(), Sh.ring(a.ring, width: 2)]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(v.$3,
                                style: const TextStyle(fontSize: 20, height: 1.4)),
                            const SizedBox(height: 4),
                            Text(v.$2,
                                style: T.s(12, T.w900,
                                    isActive ? a.text : C.slate600)),
                            const SizedBox(height: 4),
                            Opacity(
                              opacity: 0.75,
                              child: Text(v.$4,
                                  textAlign: TextAlign.center,
                                  style: T.s(8, T.w600,
                                      isActive ? a.text : C.slate600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _centerVillageRow(
      {required String centerPlaceholder, required String villageHint}) {
    return Row(
      children: [
        Expanded(
          child: SelectField(
            value: _center,
            placeholder: centerPlaceholder,
            options: centers,
            icon: LucideIcons.building,
            onChanged: (v) => setState(() => _center = v),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IconField(
            controller: _village,
            hint: villageHint,
            icon: LucideIcons.mapPin,
            fontSize: 12,
            weight: T.w900,
            rightPadding: 44,
          ),
        ),
      ],
    );
  }

  Widget _submitText(String text, {double size = 16}) =>
      Text(text, style: T.s(size, T.w900, C.white));

  // ── نموذج إكمال البيانات (مستخدم جوجل) ──

  Widget _completeProfileForm() {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Text('إكمال بياناتك',
                    textAlign: TextAlign.center,
                    style: T.s(20, T.w900, C.slate900, letterSpacing: -0.5)),
                Text('خطوة أخيرة للبدء: أضف هاتفك ومنطقتك',
                    textAlign: TextAlign.center,
                    style: T.s(12, T.w700, C.slate400)),
              ],
            ),
          ),
          SegmentedTabs(
            labels: const ['أنا عميل 👤', 'أنا كابتن 🛵'],
            selected: _role == UserRole.customer ? 0 : 1,
            onSelect: (i) => setState(
                () => _role = i == 0 ? UserRole.customer : UserRole.driver),
            background: C.slate100.withOpacity(0.8),
            border: Border.all(color: C.slate200.withOpacity(0.5)),
            gap: 8,
          ),
          _gap(16),
          IconField(
            controller: _phone,
            hint: 'رقم الهاتف (010...)',
            icon: LucideIcons.smartphone,
            ltr: true,
            keyboardType: TextInputType.phone,
          ),
          _gap(16),
          _centerVillageRow(
              centerPlaceholder: 'اختر المركز', villageHint: 'اسم القرية'),
          if (_role == UserRole.driver) ...[
            _gap(16),
            _vehiclePicker(),
          ],
          _gap(16),
          PrimaryButton(
            onTap: _loading ? null : _handleCompleteGoogleProfile,
            child: _loading
                ? const Spinner()
                : _submitText('حفظ البيانات والدخول'),
          ),
        ],
      ),
    );
  }

  // ── النموذج الرئيسي (دخول / تسجيل) ──

  Widget _mainForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(
          labels: const ['تسجيل الدخول', 'إنشاء حساب جديد'],
          selected: _isRegistering ? 1 : 0,
          onSelect: (i) => setState(() {
            if (i == 0) {
              _isRegistering = false;
              _errorMsg = null;
            } else {
              _isRegistering = true;
              _step = _OtpStep.input;
              _errorMsg = null;
            }
          }),
          background: C.slate100.withOpacity(0.9),
          border: Border.all(color: C.slate200.withOpacity(0.6)),
        ),
        _gap(20),
        if (_isRegistering)
          (_step == _OtpStep.input ? _registerInput(context) : _registerOtp())
        else
          _loginForm(),
      ],
    );
  }

  Widget _registerInput(BuildContext context) {
    final sm = isSm(context);
    final passwordField = IconField(
      controller: _password,
      hint: 'كلمة المرور',
      icon: LucideIcons.lock,
      ltr: true,
      obscure: !_showPassword,
      leftPadding: 40,
      suffix: EyeToggle(
          shown: _showPassword,
          onTap: () => setState(() => _showPassword = !_showPassword)),
    );
    final confirmField = IconField(
      controller: _confirmPassword,
      hint: 'تأكيد الكلمة',
      icon: LucideIcons.lock,
      ltr: true,
      obscure: !_showConfirmPassword,
      leftPadding: 40,
      suffix: EyeToggle(
          shown: _showConfirmPassword,
          onTap: () =>
              setState(() => _showConfirmPassword = !_showConfirmPassword)),
    );

    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedTabs(
            labels: const ['👤 عميل (طلب رحلات)', '🛵 كابتن (توصيل طلبات)'],
            selected: _role == UserRole.customer ? 0 : 1,
            onSelect: (i) => setState(
                () => _role = i == 0 ? UserRole.customer : UserRole.driver),
            background: C.slate100,
            verticalPadding: 10,
            gap: 8,
          ),
          _gap(16),
          IconField(
            controller: _name,
            hint: 'الاسم ثلاثي أو رباعي',
            icon: LucideIcons.user,
          ),
          _gap(16),
          IconField(
            controller: _phone,
            hint: 'رقم الهاتف (010...)',
            icon: LucideIcons.smartphone,
            ltr: true,
            keyboardType: TextInputType.phone,
          ),
          _gap(16),
          IconField(
            controller: _email,
            hint: 'البريد الإلكتروني',
            icon: LucideIcons.mail,
            ltr: true,
            keyboardType: TextInputType.emailAddress,
          ),
          _gap(16),
          if (sm)
            Row(children: [
              Expanded(child: passwordField),
              const SizedBox(width: 12),
              Expanded(child: confirmField),
            ])
          else ...[
            passwordField,
            _gap(12),
            confirmField,
          ],
          _gap(16),
          _centerVillageRow(
              centerPlaceholder: 'المركز', villageHint: 'القرية / الحي'),
          if (_role == UserRole.driver) ...[
            _gap(16),
            _vehiclePicker(),
          ],
          _gap(24), // space-y-4 + mt-2
          PrimaryButton(
            onTap: _handleAuth,
            child: _submitText('إنشاء الحساب والمتابعة'),
          ),
        ],
      ),
    );
  }

  Widget _registerOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Text('تأكيد رقم الهاتف',
                textAlign: TextAlign.center,
                style: T.s(24, T.w900, C.slate900, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            Text('أدخل الرمز المكون من 6 أرقام المرسل إلى',
                textAlign: TextAlign.center,
                style: T.s(12, T.w700, C.slate400, height: 1.625)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(_phone.text,
                  textAlign: TextAlign.center,
                  style: T.s(12, T.w700, C.emerald600, height: 1.625)),
            ),
          ],
        ),
        _gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var idx = 0; idx < 6; idx++)
                  Padding(
                    padding: EdgeInsets.only(left: idx == 0 ? 0 : 8),
                    child: _otpBox(idx),
                  ),
              ],
            ),
          ),
        ),
        _gap(16),
        PrimaryButton(
          onTap: _loading ? null : _handleAuth,
          child: _loading
              ? const Spinner()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.shieldCheck,
                        size: 20, color: C.white),
                    const SizedBox(width: 8),
                    _submitText('تأكيد الرمز'),
                  ],
                ),
        ),
        _gap(12),
        Center(
          child: _canResend
              ? GestureDetector(
                  onTap: _handleResendOtp,
                  child: Text('إعادة إرسال الكود',
                      style: T.s(12, T.w900, C.emerald600)),
                )
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'إعادة الإرسال خلال ',
                        style: T.s(12, T.w700, C.slate400)),
                    TextSpan(
                        text: '$_resendTimer',
                        style: T.s(12, T.w900, C.emerald600)),
                    TextSpan(
                        text: ' ثانية', style: T.s(12, T.w700, C.slate400)),
                  ]),
                ),
        ),
        _gap(16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _step = _OtpStep.input),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('تعديل رقم الهاتف',
                textAlign: TextAlign.center,
                style: T.s(12, T.w900, C.slate400)),
          ),
        ),
      ],
    );
  }

  Widget _otpBox(int idx) {
    final has = _otp[idx].isNotEmpty;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, e) {
        _handleOtpKey(idx, e);
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          color: has ? C.white : C.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: has ? C.emerald600 : C.slate200, width: 2),
        ),
        child: TextField(
          controller: _otpCtrls[idx],
          focusNode: _otpNodes[idx],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: otpInputFormatters,
          cursorColor: C.emerald600,
          style: T.s(20, T.w900, C.slate900),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) => _handleOtpChange(idx, v),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconField(
            controller: _loginEmail,
            hint: 'البريد الإلكتروني',
            icon: LucideIcons.mail,
            ltr: true,
            keyboardType: TextInputType.emailAddress,
          ),
          _gap(16),
          IconField(
            controller: _loginPassword,
            hint: 'كلمة المرور',
            icon: LucideIcons.lock,
            ltr: true,
            obscure: !_showPassword,
            leftPadding: 40,
            suffix: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: EyeToggle(
                  shown: _showPassword,
                  onTap: () => setState(() => _showPassword = !_showPassword)),
            ),
          ),
          _gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MiniCheckbox(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v)),
                      const SizedBox(width: 8),
                      Text('تذكرني', style: T.s(12, T.w700, C.slate500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _handleForgotPassword,
                  child: Text('نسيت كلمة المرور؟',
                      style: T.s(12, T.w900, C.emerald600)),
                ),
              ],
            ),
          ),
          _gap(16),
          // py-4.5 في الأصل = 18px
          PressScale(
            onTap: _loading ? null : _handleAuth,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.emerald600,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Sh.xl(color: C.emerald600.withOpacity(0.25)),
              ),
              child: _loading
                  ? const Spinner()
                  : _submitText('تسجيل الدخول', size: 18),
            ),
          ),
          _gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: C.slate200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('أو المتابعة السريعة عبر',
                      style: T.s(11, T.w700, C.slate400)),
                ),
                Expanded(child: Container(height: 1, color: C.slate200)),
              ],
            ),
          ),
          _gap(16),
          PressScale(
            onTap: _loading ? null : _handleGoogleLogin,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.slate200.withOpacity(0.9)),
                boxShadow: Sh.sm(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.string(_googleSvg, width: 20, height: 20),
                  const SizedBox(width: 12),
                  Text('المتابعة باستخدام Google',
                      style: T.s(14, T.w900, C.slate700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مساعد صغير لإنشاء فلتر blur
ImageFilter ui_blur(double sigma) =>
    ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
