import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _Msg {
  final bool isUser;
  final String text;
  const _Msg(this.isUser, this.text);
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final List<_Msg> messages = [
    const _Msg(false,
        'يا أهلاً بيك في وصـــلــهــا! أنا مساعدك الذكي لخدمات المنوفية بالكامل، أقدر أساعدك تعرف أسعار المشاوير، ترشيحات مطاعم، أو أماكن في أي مركز. تحب تسأل عن إيه؟'),
  ];
  final inputCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  bool typing = false;

  Future<void> _send() async {
    final text = inputCtrl.text.trim();
    if (text.isEmpty || typing) return;
    inputCtrl.clear();
    setState(() {
      messages.add(_Msg(true, text));
      typing = true;
    });
    _scrollDown();
    final reply = await AiService.instance.ask(text);
    if (!mounted) return;
    setState(() {
      messages.add(_Msg(false, reply));
      typing = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black87,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مساعد وصلها الذكي',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('متصل الآن',
                            style: TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(18),
                itemCount: messages.length + (typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == messages.length) {
                    return const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    );
                  }
                  final m = messages[i];
                  return Align(
                    alignment: m.isUser ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: m.isUser ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: m.isUser ? null : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                            color: m.isUser ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputCtrl,
                      decoration: InputDecoration(
                        hintText: 'اسأل أي سؤال عن المنوفية...',
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    onPressed: typing ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: Colors.black87),
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
