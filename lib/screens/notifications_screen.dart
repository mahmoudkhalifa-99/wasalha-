import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

/// مركز التنبيهات - مقابلة لملف pages/NotificationsView.tsx بنسخة الويب
class NotificationsScreen extends StatelessWidget {
  final String userId;
  final UserRole? role;
  const NotificationsScreen({super.key, required this.userId, this.role});

  IconData _iconFor(String? type) {
    switch (type) {
      case 'SUCCESS':
        return Icons.check_circle;
      case 'ALERT':
      case 'WARNING':
        return Icons.notifications_active;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'SUCCESS':
        return const Color(0xFF059669);
      case 'ALERT':
        return const Color(0xFFE11D48);
      case 'WARNING':
        return const Color(0xFFD97706);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('مركز التنبيهات'),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService.instance.notificationsStream(userId, role: role),
            builder: (context, snap) {
              final items = snap.data ?? [];
              final hasUnread = items.any((n) => n['read'] != true);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => FirebaseService.instance
                    .markAllNotificationsRead(items.where((n) => n['read'] != true).map((n) => n['id'] as String).toList()),
                child: const Text('قراءة الكل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.notificationsStream(userId, role: role),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('لا توجد تنبيهات جديدة حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = items[i];
              final read = n['read'] == true;
              final color = _colorFor(n['type']);
              final createdAt = (n['createdAt'] as num?)?.toInt();
              final time = createdAt != null ? DateTime.fromMillisecondsSinceEpoch(createdAt) : null;
              return Material(
                color: read ? Colors.white.withOpacity(0.6) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                elevation: read ? 0 : 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    if (!read) FirebaseService.instance.markNotificationRead(n['id']);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: read ? Colors.black.withOpacity(0.04) : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_iconFor(n['type']), size: 20, color: read ? Colors.black38 : color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['title'] ?? '',
                                  style: TextStyle(
                                      fontWeight: read ? FontWeight.w700 : FontWeight.w900, fontSize: 13)),
                              if (n['body'] != null) ...[
                                const SizedBox(height: 4),
                                Text(n['body'],
                                    style: const TextStyle(color: Colors.black45, fontSize: 12, height: 1.4)),
                              ],
                              if (time != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        color: Colors.black26, fontSize: 9, fontWeight: FontWeight.w800)),
                              ],
                            ],
                          ),
                        ),
                        if (!read)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
