import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../widgets/common.dart';

class _ChatMsg {
  final bool isUser;
  final String text;
  const _ChatMsg(this.isUser, this.text);
}

/// مفتاح Gemini API — نفس متغير البيئة GEMINI_API_KEY المستخدم في نسخة الويب
/// (process.env.API_KEY)، يُمرَّر هنا وقت البناء:
///   flutter build apk --dart-define=GEMINI_API_KEY=your_key
const String _geminiApiKey =
    String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

const String _systemInstruction =
    "أنت 'وصـــلــهــا'، المساعد الذكي لتطبيق 'وصـــلــهــا'. أنت خبير بخدمات "
    "التوصيل وجغرافيا محافظة المنوفية بالكامل بمراكزها العشرة (شبين، أشمون، "
    "منوف، الباجور، قويسنا، بركة السبع، تلا، السادات، الشهداء). تحدث بلهجة "
    "مصرية منوفية ودودة، مختصرة، واحترافية.";

/// نسخة Flutter من config/AIAssistant.tsx
class AIAssistant extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  const AIAssistant({super.key, required this.isOpen, required this.onClose});

  @override
  State<AIAssistant> createState() => _AIAssistantState();
}

class _AIAssistantState extends State<AIAssistant> {
  final List<_ChatMsg> _messages = [
    const _ChatMsg(false,
        'يا أهلاً بيك! أنا مساعدك الذكي في تطبيق "وصـــلــهــا"، خبير محافظة المنوفية بالكامل. أقدر أساعدك في معرفة أقرب المناطق، أسعار المشاوير، أو حتى أرشحلك أحسن أماكن في المنوفية. تحب تبدأ بإيه؟'),
  ];
  final _inputCtrl = TextEditingController();
  bool _isTyping = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _handleSend() async {
    final userMsg = _inputCtrl.text.trim();
    if (userMsg.isEmpty || _isTyping) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMsg(true, userMsg));
      _isTyping = true;
    });
    _scrollToEnd();

    try {
      if (_geminiApiKey.isEmpty) throw Exception('NO_API_KEY');
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$_geminiApiKey');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userMsg}
              ],
            }
          ],
          'systemInstruction': {
            'parts': [
              {'text': _systemInstruction}
            ],
          },
        }),
      );

      String aiText =
          'معلش يا بطل، الشبكة في المنوفية مريحة شوية، جرب تسأل تاني.';
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final candidates = data['candidates'] as List?;
        final parts = candidates != null && candidates.isNotEmpty
            ? (candidates[0]['content']?['parts'] as List?)
            : null;
        final text =
            parts != null && parts.isNotEmpty ? parts[0]['text'] as String? : null;
        if (text != null && text.trim().isNotEmpty) aiText = text;
      }
      if (mounted) setState(() => _messages.add(_ChatMsg(false, aiText)));
    } catch (error) {
      debugPrint('AI Error: $error');
      if (mounted) {
        setState(() => _messages
            .add(const _ChatMsg(false, 'الظاهر الإنترنت واقع، جرب كمان دقيقة.')));
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final isSmUp = size.width >= 640;

    return Positioned.fill(
      child: GlassBox(
        sigma: 12,
        color: C.slate900.withOpacity(0.4),
        borderRadius: BorderRadius.zero,
        child: Align(
          alignment: isSmUp ? Alignment.center : Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 512,
                maxHeight: isSmUp ? 650 : size.height * 0.8,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: isSmUp
                        ? BorderRadius.circular(56)
                        : const BorderRadius.vertical(top: Radius.circular(56)),
                    boxShadow: Sh.xxl(),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        color: C.slate900,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PressScale(
                              onTap: widget.onClose,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: C.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(LucideIcons.x,
                                    size: 20, color: C.white),
                              ),
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('مساعد وصـــلــهــا الذكي',
                                        style: T.s(14, T.w900, C.white)),
                                    Pulse(
                                      child: Text('متصل الآن • المنوفية',
                                          style: T.s(10, T.w700, C.emerald400)),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: C.emerald500,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: Sh.lg(),
                                  ),
                                  child: const Icon(LucideIcons.sparkles,
                                      size: 24, color: C.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: C.slate50.withOpacity(0.5),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(24),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 24),
                            itemBuilder: (context, i) {
                              if (i == _messages.length) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Spinner(size: 24, color: C.emerald500),
                                  ),
                                );
                              }
                              final m = _messages[i];
                              return Align(
                                alignment: m.isUser
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: size.width * 0.85),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: m.isUser ? C.slate900 : C.white,
                                      border: m.isUser
                                          ? null
                                          : Border.all(color: C.slate100),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(35),
                                        topRight: const Radius.circular(35),
                                        bottomRight:
                                            Radius.circular(m.isUser ? 35 : 0),
                                        bottomLeft:
                                            Radius.circular(m.isUser ? 0 : 35),
                                      ),
                                      boxShadow: Sh.sm(),
                                    ),
                                    child: Text(m.text,
                                        style: T.s(13, T.w700,
                                            m.isUser ? C.white : C.slate800)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: C.white,
                          border: Border(top: BorderSide(color: C.slate100)),
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: C.slate50,
                                borderRadius: BorderRadius.circular(29),
                              ),
                              child: TextField(
                                controller: _inputCtrl,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: T.s(13, T.w700, C.slate900),
                                onSubmitted: (_) => _handleSend(),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'اسأل أي سؤال عن المنوفية...',
                                  hintStyle: T.s(13, T.w700, C.gray400),
                                  contentPadding: const EdgeInsets.fromLTRB(
                                      24, 20, 64, 20),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              child: PressScale(
                                scale: 0.9,
                                onTap: _isTyping ? null : _handleSend,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: C.slate900.withOpacity(_isTyping ? 0.5 : 1),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: Sh.xl(),
                                  ),
                                  child: const Icon(LucideIcons.send,
                                      size: 20, color: C.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
