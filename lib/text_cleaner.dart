/// تنقيح النص قبل البحث:
/// - حذف التشكيل والإيموجي والرموز والأرقام والروابط
/// - حذف أسطر العناوين والمصادر ([📓…] و صـ 3/270) وأسطر التقديم مثل «قال … رحمه الله:»
/// - إن وُجد نص بين «» يُبحث عنه هو فقط
/// - إن كان في الرسالة أكثر من نص (مفصولة بسطر فارغ) يُبحث عن كل نص وحده
/// - إن لم يُعثر على النص كاملًا يُجرَّب البحث بأجزاء منه

class Passage {
  final String original;
  final List<String> words;
  const Passage(this.original, this.words);

  String get cleaned => words.join(' ');
}

class TextCleaner {
  static final _tashkeel =
      RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  static final _nonArabic = RegExp(r'[^ء-غف-ي\s]');

  static final _urls = RegExp(r'https?://\S+|www\.\S+');

  /// عبارات تُكتب في الكتب غالبًا رمزًا (ﷺ) أو تُزاد في المنشورات
  static const _honorifics = [
    'صلى الله عليه وآله وسلم',
    'صلى الله عليه وعلى آله وسلم',
    'صلى الله عليه وسلم',
    'رضي الله عنهما',
    'رضي الله عنهم',
    'رضي الله عنها',
    'رضي الله عنه',
    'رحمهم الله تعالى',
    'رحمه الله تعالى',
    'رحمها الله تعالى',
    'رحمهم الله',
    'رحمه الله',
    'رحمها الله',
    'عليه الصلاة والسلام',
    'عليه السلام',
  ];

  static String stripTashkeel(String s) => s.replaceAll(_tashkeel, '');

  /// صيغة موحّدة للمقارنة فقط (لتلوين الكلمات في النتائج)
  static String normalize(String s) => stripTashkeel(s)
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^ء-ي]'), '');

  static List<String> words(String s) {
    var t = stripTashkeel(s).replaceAll('ٱ', 'ا').replaceAll(_urls, ' ');
    for (final h in _honorifics) {
      t = t.replaceAll(h, ' ');
    }
    t = t.replaceAll(_nonArabic, ' ');
    return t
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
  }

  static bool _isSourceOrTitle(String line) {
    final l = line.trim();
    if (l.isEmpty) return true;
    final n = words(l).length;
    if (n == 0) return true;
    if (l.contains('📓') || l.contains('📜') || l.contains('🔖')) return true;
    if (l.startsWith('[') && l.endsWith(']')) return true;
    if (n <= 12 && RegExp(r'(صـ|(^|[\s(\[])[صج]\s*[:.]?\s*\d)').hasMatch(l)) {
      return true;
    }
    if (n <= 12 && RegExp(r'\d+\s*/\s*\d+').hasMatch(l)) return true;
    // سطر تقديم مثل: قال ابن القيم رحمه الله:
    if (n <= 12 && RegExp(r'[:：]\s*$').hasMatch(l)) return true;
    return false;
  }

  /// يستخرج النصوص المراد البحث عنها من رسالة المستخدم
  static List<Passage> extract(String input) {
    final text = input.replaceAll(_urls, ' ').replaceAll('\r', '');

    // 1) النصوص بين علامات التنصيص لها الأولوية
    final quoted = RegExp(r'«([^»]+)»|“([^”]+)”|"([^"]+)"')
        .allMatches(text)
        .map((m) => (m.group(1) ?? m.group(2) ?? m.group(3) ?? '').trim())
        .where((s) => words(s).length >= 3)
        .toList();

    List<String> raw;
    if (quoted.isNotEmpty) {
      raw = quoted;
    } else {
      // 2) فقرات مفصولة بأسطر فارغة، بعد حذف أسطر العناوين والمصادر
      raw = [];
      final buf = <String>[];
      for (final line in text.split('\n')) {
        if (line.trim().isEmpty) {
          if (buf.isNotEmpty) {
            raw.add(buf.join(' '));
            buf.clear();
          }
          continue;
        }
        if (_isSourceOrTitle(line)) continue;
        buf.add(line);
      }
      if (buf.isNotEmpty) raw.add(buf.join(' '));
    }

    final out = <Passage>[];
    for (final p in raw) {
      final w = words(p);
      if (w.length >= 2) out.add(Passage(p.trim(), w));
    }
    if (out.isEmpty) {
      final w = words(text);
      if (w.isNotEmpty) out.add(Passage(text.trim(), w));
    }
    return out.take(5).toList();
  }

  /// صيغ البحث بالترتيب: النص كاملًا، ثم مقاطع من 8 كلمات، ثم من 5
  static List<String> queries(List<String> w) {
    final out = <String>[];
    void add(List<String> ws) {
      final q = ws.join(' ');
      if (ws.isNotEmpty && !out.contains(q)) out.add(q);
    }

    List<String> win(int start, int len) {
      final s = start < 0 ? 0 : (start > w.length ? w.length : start);
      final e = (s + len) > w.length ? w.length : s + len;
      return w.sublist(s, e);
    }

    if (w.length <= 12) add(w);
    for (final len in const [8, 5]) {
      if (w.length > len) {
        add(win(0, len));
        add(win((w.length - len) ~/ 2, len));
        add(win(w.length - len, len));
      }
    }
    if (out.isEmpty) add(w);
    return out;
  }
}
