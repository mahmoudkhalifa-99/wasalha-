import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../legal_texts.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// سياسة الخصوصية / الشروط داخل التطبيق. لو فيه رابط عام متظبّط بنفتحه في المتصفح،
/// وإلا بنعرض النص المحلي.
class LegalView extends StatelessWidget {
  final bool privacy;
  const LegalView({super.key, required this.privacy});

  static Future<void> open(BuildContext context, {required bool privacy}) async {
    final url = privacy ? privacyPolicyUrl : termsUrl;
    if (url.isNotEmpty) {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LegalView(privacy: privacy)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: C.slate50,
        appBar: AppBar(
          backgroundColor: C.white,
          foregroundColor: C.slate900,
          title: Text(privacy ? 'سياسة الخصوصية' : 'شروط الاستخدام',
              style: T.s(16, T.w900, C.slate900)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(privacy ? privacyPolicyText : termsText,
                  style: T.s(13, T.w500, C.slate700, height: 1.9)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => launchUrl(
                        Uri(scheme: 'mailto', path: legalContactEmail),
                        mode: LaunchMode.externalApplication),
                    child: const Text('راسلنا بالبريد'),
                  ),
                  OutlinedButton(
                    onPressed: () => launchUrl(
                        Uri.parse('https://wa.me/2$legalContactWhatsapp'),
                        mode: LaunchMode.externalApplication),
                    child: const Text('واتساب'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سطر روابط صغير (الشروط • الخصوصية) للشاشات.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(String t, bool privacy) => GestureDetector(
          onTap: () => LegalView.open(context, privacy: privacy),
          child: Text(t,
              style: T.s(11, T.w700, C.slate500)
                  .copyWith(decoration: TextDecoration.underline)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link('شروط الاستخدام', false),
        Text('  •  ', style: T.s(11, T.w700, C.slate400)),
        link('سياسة الخصوصية', true),
      ],
    );
  }
}
