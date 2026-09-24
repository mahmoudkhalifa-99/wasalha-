import 'package:flutter/material.dart';

/// شاشة التعريف بالتطبيق (3 صفحات) - مقابلة لمكوّن Onboarding في Login.tsx بنسخة الويب
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final String title;
  final String body;
  final String badge;
  final Widget icon;
  final List<Color> gradient;
  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.badge,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;

  late final List<_OnboardingSlide> slides = [
    _OnboardingSlide(
      title: 'أهلاً بك في تطبيق وصلها',
      body:
          'المنظومة الذكية الأولى لخدمة كافة مراكز وقرى محافظة المنوفية، مشاويرك وطلباتك وأكلك بين إيديك بثواني.',
      badge: 'تغطية شاملة لكل القرى والمراكز',
      icon: Container(
        width: 120,
        height: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
        ),
      ),
      gradient: const [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF134E4A)],
    ),
    _OnboardingSlide(
      title: 'توكتوك • سيارة • دليفري فوري',
      body:
          'اختر وسيلة التوصيل الأنسب لمشوارك: توكتوك سريع في الشوارع، عربية مريحة، أو موتوسيكل لتوصيل طلبات المطاعم والصيدليات.',
      badge: 'أسطول نقل متكامل',
      icon: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛺', style: TextStyle(fontSize: 36)),
            SizedBox(width: 12),
            Text('🚗', style: TextStyle(fontSize: 36)),
            SizedBox(width: 12),
            Text('🏍️', style: TextStyle(fontSize: 36)),
          ],
        ),
      ),
      gradient: const [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF022C22)],
    ),
    _OnboardingSlide(
      title: 'كباتن ثقة، تتبع مباشر وأسعار عادلة',
      body:
          'كل رحلة مؤمنة وتتبع لحظي على الخريطة مع تسعيرة عادلة معلنة مسبقاً ودعم فني وخدمة عملاء مباشرة.',
      badge: 'أمان وثقة 100%',
      icon: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Icon(Icons.verified_user, size: 64, color: Color(0xFF6EE7B7)),
      ),
      gradient: const [Color(0xFF022C22), Color(0xFF115E59), Color(0xFF0F172A)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = slides[step];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: slide.gradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        slide.badge,
                        style: const TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('تخطي',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(48),
                        ),
                        child: slide.icon,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        slide.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (i) {
                        final active = i == step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF34D399) : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (step > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: IconButton.filled(
                              onPressed: () => setState(() => step -= 1),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                padding: const EdgeInsets.all(16),
                              ),
                              icon: const Icon(Icons.arrow_forward, color: Colors.white),
                            ),
                          ),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (step < slides.length - 1) {
                                setState(() => step += 1);
                              } else {
                                widget.onComplete();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(
                              step == slides.length - 1 ? 'ابدأ تجربة وصلها الآن' : 'التالي',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
