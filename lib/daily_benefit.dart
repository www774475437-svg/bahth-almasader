import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'approved.dart';
import 'turath_api.dart';

/// «فائدة اليوم» من الكتب المعتمدة (وأغلبها من كتب ابن عثيمين)
class DailyBenefit {
  static const _uthaymeen = 57;
  static const _mainCats = {1, 3, 7, 17, 18, 19, 22, 23};
  static const _otherCats = {1, 3, 23};
  static Map<String, Hit> _cache = {};
  static bool _busy = false;

  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  static Hit? forDay(DateTime d) => _cache[dayKey(d)];
  static Hit? today() => forDay(DateTime.now());

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = jsonDecode(p.getString('dailyBenefits') ?? '{}');
      if (m is Map) {
        _cache = {
          for (final e in m.entries)
            if (e.value is Map) '${e.key}': Hit.fromJson(Map<String, dynamic>.from(e.value as Map))
        };
      }
    } catch (_) {
      _cache = {};
    }
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('dailyBenefits', jsonEncode({for (final e in _cache.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  /// يجهّز فائدة لكل يوم من الأيام القادمة (يحتاج إنترنت)، ويرجع true إن أضاف جديدًا
  static Future<bool> ensure({int days = 7}) async {
    if (_busy) return false;
    _busy = true;
    var changed = false;
    try {
      final now = DateTime.now();
      final keys = [for (var i = 0; i < days; i++) dayKey(DateTime(now.year, now.month, now.day + i))];
      final before = _cache.length;
      _cache.removeWhere((k, _) => !keys.contains(k));
      if (_cache.length != before) changed = true;
      for (final k in keys) {
        if (_cache.containsKey(k)) continue;
        final h = await _fetchOne();
        if (h == null) break;
        _cache[k] = h;
        changed = true;
      }
      if (changed) await _save();
    } catch (_) {}
    _busy = false;
    return changed;
  }

  static Future<Hit?> _fetchOne() async {
    final ap = Approved.instance;
    final rnd = Random();
    final mine =
        ap.books.where((b) => b.authorId == _uthaymeen && b.pages >= 40 && _mainCats.contains(b.catId)).toList();
    final others =
        ap.books.where((b) => b.authorId != _uthaymeen && b.pages >= 40 && _otherCats.contains(b.catId)).toList();
    var failures = 0;
    for (var attempt = 0; attempt < 6 && failures < 3; attempt++) {
      final pool = (mine.isNotEmpty && (others.isEmpty || rnd.nextInt(10) < 8)) ? mine : others;
      if (pool.isEmpty) return null;
      final b = pool[rnd.nextInt(pool.length)];
      final pg = 5 + rnd.nextInt(max(1, b.pages - 10));
      try {
        final p = await TurathApi.getPage(b.id, pg);
        final t = _pick(p.text);
        if (t == null) continue;
        return Hit(
          bookId: b.id,
          authorId: b.authorId,
          bookName: p.hit.bookName.isEmpty ? b.name : p.hit.bookName,
          authorName: ap.authorName(b.authorId),
          vol: p.hit.vol,
          page: p.hit.page,
          pageId: p.hit.pageId,
          snippet: t,
        );
      } catch (_) {
        failures++;
      }
    }
    return null;
  }

  /// يختار فقرة كاملة مناسبة الطول من الصفحة (لا حاشية ولا عنوانًا)
  static String? _pick(String text) {
    final cut = text.indexOf('____');
    final body = cut > 0 ? text.substring(0, cut) : text;
    for (final raw in body.split(RegExp(r'\n+'))) {
      final p = raw.trim();
      if (p.length < 140 || p.length > 650) continue;
      if (RegExp(r'^[\(\[\d٠-٩\-•*]').hasMatch(p)) continue;
      if (!RegExp(r'[.؛!؟»]$').hasMatch(p)) continue;
      return p;
    }
    return null;
  }
}
