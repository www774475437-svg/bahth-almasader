import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/web_page.dart';
import '../settings.dart';
import '../text_cleaner.dart';

// الألوان
const kGold = Color(0xFFC9A227);
const kGoldDark = Color(0xFF7A5C00);
const kDeepGreen = Color(0xFF173F35);
const kGreen = Color(0xFF1F5E4E);
const kPaper = Color(0xFFF6F2E9);
const kDarkBg = Color(0xFF000000);
const kDarkCard = Color(0xFF141414);

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color cardColor(BuildContext c) => isDark(c) ? kDarkCard : Colors.white;
Color fieldColor(BuildContext c) => isDark(c) ? const Color(0xFF1F1F1F) : kPaper;
Color accent(BuildContext c) => isDark(c) ? const Color(0xFFE2C46A) : kDeepGreen;
Color barColor(BuildContext c) => isDark(c) ? Colors.black : kDeepGreen;
Color goldText(BuildContext c) => isDark(c) ? const Color(0xFFE9C766) : kGoldDark;

/// خط نصوص الكتب (يختاره المستخدم من الإعدادات)
TextStyle bookStyle(BuildContext context, {double size = 17, Color? color}) {
  final s = Settings.instance;
  return safeFont(
    s.bookFont,
    TextStyle(
      fontSize: size * s.bookScale,
      height: 1.9,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    ),
  );
}

/// خط العناوين الزخرفي
TextStyle titleStyle({double size = 20, Color color = Colors.white, FontWeight? weight}) =>
    safeFont(kTitleFont, TextStyle(fontSize: size, color: color, fontWeight: weight ?? FontWeight.w700));

void showSnack(BuildContext context, String msg, {String? action, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: action == null ? 1500 : 3500),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
    ));
}

Future<void> copyText(BuildContext context, String text, String label) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.lightImpact();
  if (context.mounted) showSnack(context, 'تم نسخ $label ✓');
}

Future<void> shareText(String text) async {
  await Share.share(text);
}

/// يفتح الرابط داخل التطبيق
void openInApp(BuildContext context, Uri uri, {String title = 'تراث'}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebPage(url: uri, title: title)));
}

/// يفتح الرابط خارج التطبيق (تيليجرام مثلًا)
Future<void> openExternal(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'تعذّر فتح الرابط');
}

/// نص تُلوَّن فيه الكلمات الموجودة في نص البحث
TextSpan highlighted(String text, Set<String> keys, TextStyle base, Color hl) {
  if (keys.isEmpty) return TextSpan(text: text, style: base);
  final spans = <TextSpan>[];
  for (final m in RegExp(r'\S+|\s+').allMatches(text)) {
    final tok = m.group(0)!;
    final n = TextCleaner.normalize(tok);
    var hit = n.length > 1 && keys.contains(n);
    if (!hit && n.length > 3 && (n.startsWith('و') || n.startsWith('ف'))) {
      hit = keys.contains(n.substring(1));
    }
    spans.add(TextSpan(
      text: tok,
      style: hit
          ? base.copyWith(
              color: hl,
              fontWeight: FontWeight.bold,
              backgroundColor: kGold.withValues(alpha: 0.20),
            )
          : base,
    ));
  }
  return TextSpan(children: spans);
}

Set<String> keysOf(String query) =>
    TextCleaner.words(query).map(TextCleaner.normalize).where((w) => w.length > 1).toSet();

/// بطاقة بخلفية مناسبة للوضع الليلي والنهاري
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (dark ? Colors.white : kGreen).withValues(alpha: 0.08)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: kDeepGreen.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 46, color: kGold),
            ),
            const SizedBox(height: 16),
            Text(title, style: titleStyle(size: 19, color: accent(context))),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

/// رأس الصفحة بخلفية متدرجة وزخرفة
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final double bottomPad;
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.bottomPad = 26,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark(context)
              ? const [Color(0xFF000000), Color(0xFF15110A), Color(0xFF2A2210)]
              : const [Color(0xFF0F2E26), kDeepGreen, kGreen],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -20,
            child: Icon(Icons.auto_stories_rounded,
                size: 150, color: Colors.white.withValues(alpha: 0.04)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 18, 20, bottomPad),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGold.withValues(alpha: 0.7)),
                  ),
                  child: Icon(icon, color: kGold, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle(size: 23)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  const SectionLabel(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: kGold, size: 20),
            const SizedBox(width: 8),
          ],
          Text(text, style: titleStyle(size: 17, color: accent(context))),
        ],
      ),
    );
  }
}

/// حبة صغيرة لعرض الجزء والصفحة
class PagePill extends StatelessWidget {
  final String text;
  const PagePill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: goldText(context), fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
