import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Order order;
  final AppUser user;
  const ChatScreen({super.key, required this.order, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final textCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  bool sending = false;

  bool get isDriver => widget.user.id == widget.order.driverId;

  String get otherPartyLabel =>
      isDriver ? 'العميل' : 'الكابتن ${widget.order.driverName ?? ''}';

  String? get recipientId =>
      isDriver ? widget.order.customerId : widget.order.driverId;

  Future<void> _send() async {
    final text = textCtrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    textCtrl.clear();
    try {
      await FirebaseService.instance.sendMessage(
        orderId: widget.order.id,
        senderId: widget.user.id,
        senderName: widget.user.name,
        text: text,
        recipientId: recipientId,
      );
      await Future.delayed(const Duration(milliseconds: 100));
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherPartyLabel, style: const TextStyle(fontSize: 15)),
            const Text('مشوار نشط • أشمون',
                style: TextStyle(fontSize: 10, color: AppColors.primary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirebaseService.instance.messagesStream(widget.order.id),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snap.data!;
                if (messages.isEmpty) {
                  return const Center(
                      child: Text('ابدأ المحادثة الآن', style: TextStyle(color: Colors.grey)));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollCtrl.hasClients) {
                    scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == widget.user.id;
                    return Align(
                      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(color: mine ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textCtrl,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
