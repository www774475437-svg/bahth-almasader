import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'turath_api.dart';

/// تقدّم القراءة في كتاب
class BookProgress {
  int last;
  int max;
  int total;
  String name;
  String author;
  DateTime updated;
  BookProgress(this.last, this.max, this.total, this.name, this.author, this.updated);

  double get fraction => total <= 0 ? 0 : (max / total).clamp(0.0, 1.0).toDouble();
  int get percent => (fraction * 100).round();

  factory BookProgress.fromJson(Map<String, dynamic> j) => BookProgress(
        (j['last'] as num?)?.toInt() ?? 1,
        (j['max'] as num?)?.toInt() ?? 1,
        (j['total'] as num?)?.toInt() ?? 0,
        '${j['name'] ?? ''}',
        '${j['author'] ?? ''}',
        DateTime.tryParse('${j['updated']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'last': last,
        'max': max,
        'total': total,
        'name': name,
        'author': author,
        'updated': updated.toIso8601String(),
      };
}

/// تمييز نص داخل صفحة
class Highlight {
  final String id;
  final int bookId;
  final String bookName;
  final String author;
  final int pageId;
  final String volPage;
  final String text;
  int color;
  String note;
  final DateTime date;
  Highlight({
    required this.id,
    required this.bookId,
    required this.bookName,
    required this.author,
    required this.pageId,
    required this.volPage,
    required this.text,
    required this.color,
    this.note = '',
    required this.date,
  });

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: '${j['id']}',
        bookId: (j['bookId'] as num?)?.toInt() ?? 0,
        bookName: '${j['bookName'] ?? ''}',
        author: '${j['author'] ?? ''}',
        pageId: (j['pageId'] as num?)?.toInt() ?? 1,
        volPage: '${j['volPage'] ?? ''}',
        text: '${j['text'] ?? ''}',
        color: (j['color'] as num?)?.toInt() ?? 0xFFF2C94C,
        note: '${j['note'] ?? ''}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookName': bookName,
        'author': author,
        'pageId': pageId,
        'volPage': volPage,
        'text': text,
        'color': color,
        'note': note,
        'date': date.toIso8601String(),
      };

  Hit toHit() => Hit(
      bookId: bookId, bookName: bookName, authorName: author, vol: '', page: 0, pageId: pageId, snippet: text);
}

/// الختمة: خطة قراءة كتاب في عدد من الأيام
class ReadingPlan {
  final String id;
  final int bookId;
  final String bookName;
  final String author;
  final int startPage;
  final int endPage;
  final int days;
  final DateTime start;
  ReadingPlan({
    required this.id,
    required this.bookId,
    required this.bookName,
    required this.author,
    required this.startPage,
    required this.endPage,
    required this.days,
    required this.start,
  });

  int get totalPages => endPage - startPage + 1;
  int get perDay => (totalPages / days).ceil();

  int get dayIndex {
    final s = DateTime(start.year, start.month, start.day);
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(s).inDays;
  }

  /// الصفحة التي يجب أن تصل إليها بنهاية اليوم
  int get targetToday {
    final t = startPage - 1 + perDay * (dayIndex + 1);
    return t > endPage ? endPage : t;
  }

  factory ReadingPlan.fromJson(Map<String, dynamic> j) => ReadingPlan(
        id: '${j['id']}',
        bookId: (j['bookId'] as num?)?.toInt() ?? 0,
        bookName: '${j['bookName'] ?? ''}',
        author: '${j['author'] ?? ''}',
        startPage: (j['startPage'] as num?)?.toInt() ?? 1,
        endPage: (j['endPage'] as num?)?.toInt() ?? 1,
        days: (j['days'] as num?)?.toInt() ?? 30,
        start: DateTime.tryParse('${j['start']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookName': bookName,
        'author': author,
        'startPage': startPage,
        'endPage': endPage,
        'days': days,
        'start': start.toIso8601String(),
      };
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// القراءة: التقدّم، والتمييزات، والختمات، وهدف القراءة اليومي
class Reading extends ChangeNotifier {
  Reading._();
  static final Reading instance = Reading._();

  SharedPreferences? _p;
  Map<int, BookProgress> progress = {};
  List<Highlight> highlights = [];
  List<ReadingPlan> plans = [];

  /// اليوم ← عدد الصفحات المقروءة
  Map<String, int> dayPages = {};
  Set<String> _todaySeen = {};
  int dailyGoal = 10;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    try {
      final m = jsonDecode(p.getString('progress') ?? '{}') as Map;
      progress = m.map((k, v) => MapEntry(int.tryParse('$k') ?? 0,
          BookProgress.fromJson(Map<String, dynamic>.from(v as Map))));
    } catch (_) {
      progress = {};
    }
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => (p.getStringList(key) ?? [])
        .map((s) {
          try {
            return f(Map<String, dynamic>.from(jsonDecode(s) as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList();
    highlights = list('highlights', Highlight.fromJson);
    plans = list('plans', ReadingPlan.fromJson);
    try {
      final m = jsonDecode(p.getString('dayPages') ?? '{}') as Map;
      dayPages = m.map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (_) {
      dayPages = {};
    }
    final seen = p.getStringList('todaySeen') ?? [];
    final today = dayKey(DateTime.now());
    _todaySeen = seen.where((s) => s.startsWith('$today|')).toSet();
    dailyGoal = p.getInt('dailyGoal') ?? 10;
    notifyListeners();
  }

  // ---------- التقدّم ----------
  BookProgress? of(int bookId) => progress[bookId];

  Future<void> _saveProgress() async {
    await _p?.setString('progress', jsonEncode(progress.map((k, v) => MapEntry('$k', v.toJson()))));
  }

  /// يُستدعى عند فتح كل صفحة
  Future<void> recordPage(Hit h, {int total = 0}) async {
    final bp = progress[h.bookId];
    if (bp == null) {
      progress[h.bookId] = BookProgress(h.pageId, h.pageId, total, h.bookName, h.authorName, DateTime.now());
    } else {
      bp.last = h.pageId;
      if (h.pageId > bp.max) bp.max = h.pageId;
      if (total > 0) bp.total = total;
      if (h.bookName.isNotEmpty) bp.name = h.bookName;
      if (h.authorName.isNotEmpty) bp.author = h.authorName;
      bp.updated = DateTime.now();
    }
    // الهدف اليومي: الصفحات المختلفة المقروءة اليوم
    final today = dayKey(DateTime.now());
    final key = '$today|${h.bookId}:${h.pageId}';
    if (!_todaySeen.contains(key)) {
      _todaySeen.add(key);
      dayPages[today] = (dayPages[today] ?? 0) + 1;
      await _p?.setStringList('todaySeen', _todaySeen.toList());
      await _p?.setString('dayPages', jsonEncode(dayPages));
    }
    notifyListeners();
    await _saveProgress();
  }

  Future<void> setTotal(int bookId, int total) async {
    final bp = progress[bookId];
    if (bp == null || total <= 0 || bp.total == total) return;
    bp.total = total;
    notifyListeners();
    await _saveProgress();
  }

  /// متوسط التقدّم في مجموعة كتب (0..1)
  double collectionFraction(Iterable<int> ids) {
    var sum = 0.0;
    var n = 0;
    for (final id in ids) {
      n++;
      sum += progress[id]?.fraction ?? 0;
    }
    return n == 0 ? 0 : sum / n;
  }

  // ---------- الهدف اليومي ----------
  int get todayPages => dayPages[dayKey(DateTime.now())] ?? 0;

  int get streak {
    var d = DateTime.now();
    var s = 0;
    if ((dayPages[dayKey(d)] ?? 0) < dailyGoal) d = d.subtract(const Duration(days: 1));
    while ((dayPages[dayKey(d)] ?? 0) >= dailyGoal && dailyGoal > 0) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  Future<void> setGoal(int g) async {
    dailyGoal = g;
    notifyListeners();
    await _p?.setInt('dailyGoal', g);
  }

  // ---------- التمييزات ----------
  Future<void> _saveHighlights() async {
    await _p?.setStringList('highlights', highlights.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> addHighlight(Highlight h) async {
    highlights.insert(0, h);
    notifyListeners();
    await _saveHighlights();
  }

  Future<void> updateHighlight(Highlight h, {int? color, String? note}) async {
    if (color != null) h.color = color;
    if (note != null) h.note = note.trim();
    notifyListeners();
    await _saveHighlights();
  }

  Future<void> removeHighlight(Highlight h) async {
    highlights.remove(h);
    notifyListeners();
    await _saveHighlights();
  }

  List<Highlight> highlightsOn(int bookId, int pageId) =>
      highlights.where((h) => h.bookId == bookId && h.pageId == pageId).toList();

  // ---------- الختمات ----------
  Future<void> _savePlans() async {
    await _p?.setStringList('plans', plans.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> addPlan(ReadingPlan p) async {
    plans.removeWhere((x) => x.bookId == p.bookId);
    plans.insert(0, p);
    notifyListeners();
    await _savePlans();
  }

  Future<void> removePlan(ReadingPlan p) async {
    plans.remove(p);
    notifyListeners();
    await _savePlans();
  }

  /// كل البيانات للنسخة الاحتياطية
  Map<String, dynamic> exportAll() => {
        'progress': progress.map((k, v) => MapEntry('$k', v.toJson())),
        'highlights': highlights.map((e) => e.toJson()).toList(),
        'plans': plans.map((e) => e.toJson()).toList(),
        'dayPages': dayPages,
        'dailyGoal': dailyGoal,
      };

  Future<void> importAll(Map<String, dynamic> d) async {
    final p = _p;
    if (p == null) return;
    if (d['progress'] is Map) await p.setString('progress', jsonEncode(d['progress']));
    if (d['highlights'] is List) {
      await p.setStringList('highlights', (d['highlights'] as List).map((e) => jsonEncode(e)).toList());
    }
    if (d['plans'] is List) {
      await p.setStringList('plans', (d['plans'] as List).map((e) => jsonEncode(e)).toList());
    }
    if (d['dayPages'] is Map) await p.setString('dayPages', jsonEncode(d['dayPages']));
    if (d['dailyGoal'] is num) await p.setInt('dailyGoal', (d['dailyGoal'] as num).toInt());
    await load();
  }
}
