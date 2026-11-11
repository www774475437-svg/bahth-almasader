import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/common.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(Icons.manage_search_rounded, 'اعرف مصدر أي نص',
      'الصق النص، ولو كان فيه رموز أو إيموجي أو سطر مصدر، فينقّحه التطبيق ويخبرك باسم الكتاب والجزء والصفحة.'),
  _Slide(Icons.ios_share_rounded, 'من تيليجرام وواتساب مباشرة',
      'اضغط «مشاركة» على أي منشور واختر «بحث المصادر»، أو انسخ النص وافتح التطبيق فيقترح عليك البحث عنه.'),
  _Slide(Icons.auto_stories_rounded, 'اقرأ واحفظ وانشر',
      'افتح الصفحة في «تراث» داخل التطبيق، واحفظ الفوائد في مجلدات، واصنع منشورًا جاهزًا أو صورة اقتباس.'),
];

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2E26), kDeepGreen, kGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('تخطٍّ', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset('assets/icon.png', width: 96, height: 96),
              ),
              const SizedBox(height: 12),
              Text(kAppName, style: titleStyle(size: 30, color: kGold)),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: kGold.withValues(alpha: 0.6)),
                            ),
                            child: Icon(s.icon, size: 52, color: kGold),
                          ),
                          const SizedBox(height: 26),
                          Text(s.title, textAlign: TextAlign.center, style: titleStyle(size: 22)),
                          const SizedBox(height: 12),
                          Text(s.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85), fontSize: 15.5, height: 1.8)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < _slides.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: k == _i ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: k == _i ? kGold : Colors.white30,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kDeepGreen,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (last) {
                        widget.onDone();
                      } else {
                        _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                      }
                    },
                    child: Text(last ? 'ابدأ الآن' : 'التالي',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
