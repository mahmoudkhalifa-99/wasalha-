import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';

/// بتظهر لكل المستخدمين (غير السوبر أدمن) لما التطبيق يتعطّل من الإدارة.
class AppDisabledScreen extends StatelessWidget {
  final String message;
  final Future<void> Function() onLogout;
  const AppDisabledScreen(
      {super.key, required this.message, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.slate50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: C.slate200),
                  boxShadow: Sh.lg(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                            color: C.rose50, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.shieldAlert,
                            size: 36, color: C.rose500),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('التطبيق متوقف مؤقتاً',
                        textAlign: TextAlign.center,
                        style: T.s(24, T.w900, C.slate900, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: T.s(12, T.w700, C.slate500, height: 1.7)),
                    const SizedBox(height: 22),
                    PressScale(
                      onTap: onLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.slate100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('تسجيل الخروج',
                            style: T.s(14, T.w900, C.slate700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
