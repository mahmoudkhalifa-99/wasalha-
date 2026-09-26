import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

/// شاشة مؤقتة للأدوار اللي لسه هتتبني (كابتن / أوبريتور / أدمن).
/// هتتستبدل بالتفصيل الكامل في المرحلة الجاية.
class ComingSoonDashboard extends StatelessWidget {
  final AppUser user;
  final String roleLabel;
  const ComingSoonDashboard({super.key, required this.user, required this.roleLabel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('لوحة $roleLabel')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('أهلًا ${user.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('لوحة $roleLabel قيد التطوير حاليًا', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => FirebaseService.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة انتظار الموافقة للسائقين الجدد (status = PENDING_APPROVAL)
class PendingApprovalScreen extends StatelessWidget {
  final AppUser user;
  const PendingApprovalScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('حسابك قيد المراجعة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('هيتم تفعيل حسابك بمجرد موافقة الإدارة، غالبًا خلال ساعات قليلة',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => FirebaseService.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
