import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/quote_image.dart';
import '../text_cleaner.dart';
import '../turath_api.dart';
import 'common.dart';

/// اللغات المتاحة للترجمة
const kLanguages = <String, String>{
  'en': 'الإنجليزية',
  'ur': 'الأردية',
  'id': 'الإندونيسية',
  'ms': 'الملايوية',
  'fr': 'الفرنسية',
  'tr': 'التركية',
  'bn': 'البنغالية',
  'fa': 'الفارسية',
  'es': 'الإسبانية',
  'de': 'الألمانية',
  'ru': 'الروسية',
  'zh-CN': 'الصينية',
  'hi': 'الهندية',
  'sw': 'السواحلية',
  'ha': 'الهوسا',
  'so': 'الصومالية',
  'am': 'الأمهرية',
  'ps': 'البشتو',
  'uz': 'الأوزبكية',
  'tl': 'الفلبينية',
  'it': 'الإيطالية',
  'pt': 'البرتغالية',
  'nl': 'الهولندية',
  'ja': 'اليابانية',
  'ko': 'الكورية',
};

/// ترجمة النص إلى لغة يختارها المستخدم (تُفتح داخل التطبيق)
Future<void> showTranslateSheet(BuildContext context, String text) async {
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getString('lastLang') ?? 'en';
  if (!context.mounted) return;
  final codes = [last, ...kLanguages.keys.where((k) => k != last)];
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: cardColor(context),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            Text('ترجم إلى…', style: titleStyle(size: 18, color: accent(ctx))),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  for (final c in codes)
                    ListTile(
                      leading: Icon(c == last ? Icons.history_rounded : Icons.translate_rounded, color: kGold),
                      title: Text(kLanguages[c] ?? c),
                      onTap: () => Navigator.pop(ctx, c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await prefs.setString('lastLang', picked);
  var t = text.trim();
  if (t.length > 4500) t = t.substring(0, 4500);
  final uri = Uri.https('translate.google.com', '/', {
    'sl': 'ar',
    'tl': picked,
    'text': t,
    'op': 'translate',
  });
  if (context.mounted) openInApp(context, uri, title: 'الترجمة إلى ${kLanguages[picked] ?? picked}');
}

/// مشاركة: نص بالتشكيل، أو بدونه، أو صورة
Future<void> showShareSheet(BuildContext context, {required String text, required Hit hit}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: cardColor(context),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مشاركة', style: titleStyle(size: 18, color: accent(ctx))),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.text_fields_rounded, color: kGold),
            title: const Text('نص بالتشكيل'),
            onTap: () => Navigator.pop(ctx, 'with'),
          ),
          ListTile(
            leading: const Icon(Icons.format_clear_rounded, color: kGold),
            title: const Text('نص بدون تشكيل'),
            onTap: () => Navigator.pop(ctx, 'without'),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded, color: kGold),
            title: const Text('صورة بالتشكيل'),
            onTap: () => Navigator.pop(ctx, 'img'),
          ),
          ListTile(
            leading: const Icon(Icons.hide_image_rounded, color: kGold),
            title: const Text('صورة بدون تشكيل'),
            onTap: () => Navigator.pop(ctx, 'img_plain'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final plain = choice == 'without' || choice == 'img_plain';
  final body = plain ? TextCleaner.stripTashkeel(text.trim()) : text.trim();
  if (choice == 'with' || choice == 'without') {
    await shareText('«$body»\n\n${hit.sourceLine}');
  } else {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuoteImagePage(text: body, source: '${hit.bookName} (صـ ${hit.volPage})'),
    ));
  }
}
