import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'models/models.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/operator/operator_dashboard.dart';
import 'screens/placeholder_dashboards.dart';
import 'screens/superadmin/superadmin_dashboard.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

class WasalahApp extends StatelessWidget {
  const WasalahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصلها',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const AuthGate(),
    );
  }
}

/// بوابة المصادقة: بتستمع لحالة تسجيل الدخول، وبتجيب بيانات المستخدم من Firestore،
/// وبتوجّهه للوحة المناسبة حسب دوره وحالته - مقابلة لمنطق App.tsx في نسخة الويب
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb_auth.User?>(
      stream: FirebaseService.instance.authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }
        final authUser = authSnap.data;
        if (authUser == null) {
          return const LoginScreen();
        }
        return StreamBuilder<AppUser?>(
          stream: FirebaseService.instance.userStream(authUser.uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }
            final user = userSnap.data;
            if (user == null) {
              if (FirebaseService.instance.isCreatingUserProfile) {
                // شاشة تسجيل الدخول لسه بتجهّز ملف المستخدم بنفسها (مثلاً خطوة
                // إكمال البيانات بعد جوجل) - منستناها من غير ما نتدخل
                return const _SplashLoader();
              }
              // مفيش ملف بيانات لسه لهذا الحساب - ننشئه تلقائيًا (نفس سلوك نسخة الويب)
              return FutureBuilder<AppUser>(
                future: FirebaseService.instance.ensureUserDoc(authUser),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const _SplashLoader(message: 'جاري تجهيز حسابك...');
                  }
                  // بعد الإنشاء، الـ StreamBuilder هيلتقط المستند الجديد تلقائيًا
                  return const _SplashLoader(message: 'جاري تجهيز حسابك...');
                },
              );
            }
            if (user.role == UserRole.DRIVER &&
                user.status == UserStatus.PENDING_APPROVAL) {
              return PendingApprovalScreen(user: user);
            }
            if (user.status == UserStatus.SUSPENDED) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, size: 56, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('حسابك موقوف حاليًا، تواصل مع الدعم الفني'),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => FirebaseService.instance.signOut(),
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
              );
            }
            switch (user.role) {
              case UserRole.CUSTOMER:
                return CustomerDashboard(user: user);
              case UserRole.DRIVER:
                return DriverDashboard(user: user);
              case UserRole.OPERATOR:
                return OperatorDashboard(user: user);
              case UserRole.ADMIN:
                return SuperAdminDashboard(user: user);
            }
          },
        );
      },
    );
  }
}

class _SplashLoader extends StatelessWidget {
  final String? message;
  const _SplashLoader({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pedal_bike, color: Colors.white, size: 56),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}
