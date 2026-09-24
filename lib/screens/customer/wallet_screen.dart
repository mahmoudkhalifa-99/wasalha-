import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

/// محفظتي الرقمية - مقابلة لملف pages/WalletView.tsx بنسخة الويب
class WalletScreen extends StatefulWidget {
  final AppUser user;
  const WalletScreen({super.key, required this.user});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const cashNumber = '01065019364'; // رقم فودافون كاش الرسمي للإدارة

  PaymentRequestAction? activeAction;
  final amountCtrl = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')));
      return;
    }
    if (activeAction == PaymentRequestAction.WITHDRAW && amount > widget.user.wallet.balance) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('المبلغ المطلوب أكبر من رصيدك الحالي')));
      return;
    }
    setState(() => submitting = true);
    try {
      await FirebaseService.instance.createPaymentRequest(
        user: widget.user,
        action: activeAction!,
        amount: amount,
      );
      final msg = activeAction == PaymentRequestAction.TOPUP
          ? 'طلب شحن محفظة وصلها: ${amount.toStringAsFixed(0)} ج.م\nالاسم: ${widget.user.name}'
          : 'طلب سحب أرباح من وصلها: ${amount.toStringAsFixed(0)} ج.م\nالاسم: ${widget.user.name}';
      final uri = Uri.parse('https://wa.me/$cashNumber?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        activeAction = null;
        amountCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلبك بنجاح، سيتم تنفيذه بعد المراجعة.')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء إرسال الطلب')));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('محفظتي الرقمية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            balance: widget.user.wallet.balance,
            onTopUp: () => setState(() => activeAction = PaymentRequestAction.TOPUP),
            onWithdraw: () => setState(() => activeAction = PaymentRequestAction.WITHDRAW),
          ),
          if (activeAction != null) ...[
            const SizedBox(height: 16),
            _ActionCard(
              action: activeAction!,
              amountCtrl: amountCtrl,
              submitting: submitting,
              cashNumber: cashNumber,
              onCancel: () => setState(() {
                activeAction = null;
                amountCtrl.clear();
              }),
              onSubmit: _submit,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.history, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('سجل المعاملات المالية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<WalletTransaction>>(
            stream: FirebaseService.instance.walletTransactionsStream(widget.user.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final txs = snap.data!;
              if (txs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12, width: 1.5),
                  ),
                  child: const Center(
                    child: Text('لا توجد معاملات مسجلة في محفظتك حتى الآن',
                        style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700)),
                  ),
                );
              }
              return Column(
                children: txs.map((t) => _TransactionTile(t: t)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;
  const _BalanceCard({required this.balance, required this.onTopUp, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF022C22)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF022C22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: const Text('الرصيد المتاح للاستخدام',
                    style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.account_balance_wallet, color: Color(0xFF6EE7B7)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(balance.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Text('جنيه مصري',
                  style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('يمكنك استخدام رصيدك لدفع المشاوير والطلبات بدون كاش',
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTopUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('شحن رصيد كاش',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onWithdraw,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.account_balance, size: 18),
                  label: const Text('سحب أرباح', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final PaymentRequestAction action;
  final TextEditingController amountCtrl;
  final bool submitting;
  final String cashNumber;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  const _ActionCard({
    required this.action,
    required this.amountCtrl,
    required this.submitting,
    required this.cashNumber,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isTopUp = action == PaymentRequestAction.TOPUP;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isTopUp ? AppColors.primary : const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(isTopUp ? Icons.add_circle_outline : Icons.account_balance,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(isTopUp ? 'شحن المحفظة فوريًا' : 'طلب سحب رصيد',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: '0.00',
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          if (isTopUp) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رقم فودافون كاش الرسمي',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                      Text(cashNumber,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cashNumber));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('تم نسخ الرقم بنجاح')));
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTopUp ? AppColors.primary : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تأكيد وإرسال الطلب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction t;
  const _TransactionTile({required this.t});

  @override
  Widget build(BuildContext context) {
    final credit = t.type == TransactionType.CREDIT;
    final date = DateTime.fromMillisecondsSinceEpoch(t.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: credit ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(credit ? Icons.south_west : Icons.north_east,
                size: 16, color: credit ? const Color(0xFF047857) : const Color(0xFFBE123C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black38)),
              ],
            ),
          ),
          Text('${credit ? '+' : '-'}${t.amount.toStringAsFixed(1)} ج.م',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: credit ? const Color(0xFF059669) : const Color(0xFFE11D48))),
        ],
      ),
    );
  }
}
