import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  /// إرسال سؤال المستخدم لـ Gemini API واسترجاع الرد النصي
  Future<String> ask(String userMessage) async {
    if (AiConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return 'المساعد الذكي محتاج مفتاح Gemini API الأول. اطّلع على '
          'lib/config/ai_config.dart وحط مفتاحك هناك.';
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${AiConfig.model}:generateContent?key=${AiConfig.geminiApiKey}',
    );
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userMessage}
              ],
            }
          ],
          'systemInstruction': {
            'parts': [
              {'text': AiConfig.systemInstruction}
            ],
          },
        }),
      );
      if (res.statusCode != 200) {
        return 'معلش يا بطل، الشبكة في أشمون مريحة شوية، جرب تسأل تاني. (${res.statusCode})';
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      return (text is String && text.trim().isNotEmpty)
          ? text
          : 'معلش يا بطل، الشبكة في أشمون مريحة شوية، جرب تسأل تاني.';
    } catch (e) {
      return 'الظاهر الإنترنت واقع، جرب كمان دقيقة.';
    }
  }
}
