import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../chat_screen.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  final AppUser? user;
  const OrderTrackingScreen({super.key, required this.orderId, this.user});

  static const _steps = [
    OrderStatus.PENDING,
    OrderStatus.ASSIGNED,
    OrderStatus.PICKED,
    OrderStatus.IN_DELIVERY,
    OrderStatus.DELIVERED,
  ];

  String _label(OrderStatus s) {
    switch (s) {
      case OrderStatus.PENDING:
        return 'بحث عن كابتن';
      case OrderStatus.ASSIGNED:
        return 'تم تعيين كابتن';
      case OrderStatus.PICKED:
        return 'تم الاستلام';
      case OrderStatus.IN_DELIVERY:
        return 'جاري التوصيل';
      case OrderStatus.DELIVERED:
        return 'تم التسليم';
      case OrderStatus.CANCELLED:
        return 'ملغي';
      default:
        return enumToStr(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تتبع الطلب')),
      body: StreamBuilder<Order?>(
        stream: FirebaseService.instance.orderStream(orderId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data;
          if (order == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }
          final currentIndex = _steps.indexOf(order.status);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (order.status == OrderStatus.CANCELLED)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('تم إلغاء هذا الطلب',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                )
              else
                Column(
                  children: List.generate(_steps.length, (i) {
                    final done = currentIndex >= 0 && i <= currentIndex;
                    return _StepRow(
                      label: _label(_steps[i]),
                      done: done,
                      isLast: i == _steps.length - 1,
                    );
                  }),
                ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(icon: Icons.my_location, label: 'من', value: order.pickup.address),
                      const Divider(),
                      _InfoRow(icon: Icons.location_on, label: 'إلى', value: order.dropoff.address),
                      const Divider(),
                      _InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'السعر',
                          value: '${order.price.toStringAsFixed(0)} ج.م'),
                    ],
                  ),
                ),
              ),
              if (order.driverName != null) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(order.driverName!),
                    subtitle: order.driverPhone != null ? Text(order.driverPhone!) : null,
                    trailing: order.driverRating != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              Text(order.driverRating!.toStringAsFixed(1)),
                            ],
                          )
                        : null,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen(order: order, user: user!)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                    label: const Text('محادثة مع الكابتن'),
                  ),
                ],
              ],
              if (order.status == OrderStatus.PENDING) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => FirebaseService.instance.cancelOrder(order.id),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.red)),
                ),
              ],
              if (order.status == OrderStatus.DELIVERED && order.rating == null) ...[
                const SizedBox(height: 20),
                _RatingCard(order: order),
              ] else if (order.rating != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      ...List.generate(
                          5,
                          (i) => Icon(
                                i < order.rating!.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              )),
                      const SizedBox(width: 8),
                      const Text('شكرًا لتقييمك!', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  final Order order;
  const _RatingCard({required this.order});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  int stars = 5;
  final feedbackCtrl = TextEditingController();
  bool sending = false;

  Future<void> _submit() async {
    setState(() => sending = true);
    try {
      await FirebaseService.instance
          .rateOrder(widget.order, stars.toDouble(), feedbackCtrl.text.trim());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('قيّم رحلتك مع الكابتن',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < stars;
                return IconButton(
                  onPressed: () => setState(() => stars = i + 1),
                  icon: Icon(filled ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 36),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedbackCtrl,
              decoration: const InputDecoration(hintText: 'رأيك يهمنا (اختياري)'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: sending ? null : _submit,
                child: sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;
  const _StepRow({required this.label, required this.done, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : Colors.grey.shade300,
              ),
              child: done ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: done ? AppColors.primary : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(label,
              style: TextStyle(
                  fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                  color: done ? Colors.black : Colors.grey)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }
}
