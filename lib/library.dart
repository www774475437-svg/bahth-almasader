import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily.dart';
import 'turath_api.dart';

// =====================================================================
// الفواصل
// =====================================================================

class Bookmark {
  final String id;
  String name;
  int color;
  int bookId;
  String bookName;
  String authorName;
  int pageId;
  String volPage;
  DateTime? placedAt;

  Bookmark({
    required this.id,
    required this.name,
    required this.color,
    this.bookId = 0,
    this.bookName = '',
    this.authorName = '',
    this.pageId = 0,
    this.volPage = '',
    this.placedAt,
  });

  bool get isSet => bookId > 0;

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        color: (j['color'] as num?)?.toInt() ?? 0xFFE57373,
        bookId: (j['bookId'] as num?)?.toInt() ?? 0,
        bookName: '${j['bookName'] ?? ''}',
        authorName: '${j['authorName'] ?? ''}',
        pageId: (j['pageId'] as num?)?.toInt() ?? 0,
        volPage: '${j['volPage'] ?? ''}',
        placedAt: DateTime.tryParse('${j['placedAt'] ?? ''}'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'bookId': bookId,
        'bookName': bookName,
        'authorName': authorName,
        'pageId': pageId,
        'volPage': volPage,
        'placedAt': placedAt?.toIso8601String(),
      };

  Hit toHit() => Hit(
        bookId: bookId,
        bookName: bookName,
        authorName: authorName,
        vol: '',
        page: 0,
        pageId: pageId,
        snippet: '',
      );
}

const kBookmarkColors = <int>[
  0xFFE5534B, // أحمر
  0xFFF2C94C, // أصفر
  0xFF6FCF57, // أخضر
  0xFF3B82F6, // أزرق
  0xFFA78BFA, // بنفسجي
  0xFFF59E0B, // برتقالي
  0xFF14B8A6, // فيروزي
  0xFFEC4899, // وردي
];

// =====================================================================
// التذكيرات
// =====================================================================

enum Repeat { once, daily, weekly }

class Reminder {
  final String id;
  String title;
  String note;
  DateTime time;
  Repeat repeat;
  bool enabled;

  /// رابط اختياري: 'bm:<id>' لفاصل، أو 'book:<id>:<name>' لكتاب
  String link;

  Reminder({
    required this.id,
    required this.title,
    this.note = '',
    required this.time,
    this.repeat = Repeat.once,
    this.enabled = true,
    this.link = '',
  });

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        note: '${j['note'] ?? ''}',
        time: DateTime.tryParse('${j['time']}') ?? DateTime.now(),
        repeat: Repeat.values[((j['repeat'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt()],
        enabled: j['enabled'] != false,
        link: '${j['link'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'time': time.toIso8601String(),
        'repeat': repeat.index,
        'enabled': enabled,
        'link': link,
      };

  String get repeatLabel => repeat == Repeat.once
      ? 'مرة واحدة'
      : repeat == Repeat.daily
          ? 'يوميًا'
          : 'أسبوعيًا';

  /// المواعيد القادمة (حتى 14 موعدًا)
  List<DateTime> upcoming() {
    final now = DateTime.now();
    final out = <DateTime>[];
    if (repeat == Repeat.once) {
      if (time.isAfter(now)) out.add(time);
      return out;
    }
    var t = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (repeat == Repeat.weekly) {
      while (t.weekday != time.weekday) {
        t = DateTime(t.year, t.month, t.day + 1, time.hour, time.minute);
      }
    }
    final step = repeat == Repeat.daily ? 1 : 7;
    while (out.length < 14) {
      if (t.isAfter(now)) out.add(t);
      t = DateTime(t.year, t.month, t.day + step, time.hour, time.minute);
    }
    return out;
  }
}

// =====================================================================
// الكتب المحمّلة
// =====================================================================

class DownloadedBook {
  final int id;
  final String name;
  final String author;
  final int bytes;
  final DateTime date;
  const DownloadedBook(this.id, this.name, this.author, this.bytes, this.date);

  factory DownloadedBook.fromJson(Map<String, dynamic> j) => DownloadedBook(
        (j['id'] as num?)?.toInt() ?? 0,
        '${j['name'] ?? ''}',
        '${j['author'] ?? ''}',
        (j['bytes'] as num?)?.toInt() ?? 0,
        DateTime.tryParse('${j['date']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'author': author, 'bytes': bytes, 'date': date.toIso8601String()};

  String get sizeLabel {
    final mb = bytes / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} م.ب' : '${(bytes / 1024).round()} ك.ب';
  }
}

class _OfflineBook {
  final List<String> pages;
  final List<String> vols;
  final List<int> nums;
  final List<Heading> headings;
  _OfflineBook(this.pages, this.vols, this.nums, this.headings);
}

// =====================================================================
// المكتبة: الفواصل والتذكيرات والتحميلات
// =====================================================================

class Library extends ChangeNotifier {
  Library._();
  static final Library instance = Library._();

  SharedPreferences? _p;
  List<Bookmark> bookmarks = [];
  List<Reminder> reminders = [];
  List<DownloadedBook> downloads = [];

  /// رقم الكتاب ← نسبة التحميل (0..1)
  final Map<int, double> progress = {};
  final Map<int, _OfflineBook> _cache = {};

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
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

    bookmarks = list('bookmarks', Bookmark.fromJson);
    if (bookmarks.isEmpty) {
      bookmarks = [
        Bookmark(id: 'red', name: 'الأحمر', color: kBookmarkColors[0]),
        Bookmark(id: 'yellow', name: 'الأصفر', color: kBookmarkColors[1]),
        Bookmark(id: 'green', name: 'الأخضر', color: kBookmarkColors[2]),
        Bookmark(id: 'blue', name: 'الأزرق', color: kBookmarkColors[3]),
      ];
    }
    reminders = list('reminders', Reminder.fromJson);
    downloads = list('downloads', DownloadedBook.fromJson);
    notifyListeners();
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> items) async {
    await _p?.setStringList(key, items.map(jsonEncode).toList());
  }

  // ---------- الفواصل ----------
  Bookmark? bookmarkById(String id) {
    for (final b in bookmarks) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> placeBookmark(Bookmark b, Hit at) async {
    b.bookId = at.bookId;
    b.bookName = at.bookName;
    b.authorName = at.authorName;
    b.pageId = at.pageId;
    b.volPage = at.volPage;
    b.placedAt = DateTime.now();
    notifyListeners();
    await _saveList('bookmarks', bookmarks.map((e) => e.toJson()).toList());
  }

  Future<void> addBookmark(String name, int color) async {
    bookmarks.add(Bookmark(id: newId(), name: name.trim().isEmpty ? 'فاصل' : name.trim(), color: color));
    notifyListeners();
    await _saveList('bookmarks', bookmarks.map((e) => e.toJson()).toList());
  }

  Future<void> updateBookmark(Bookmark b, {String? name, int? color, bool clear = false}) async {
    if (name != null && name.trim().isNotEmpty) b.name = name.trim();
    if (color != null) b.color = color;
    if (clear) {
      b.bookId = 0;
      b.bookName = '';
      b.pageId = 0;
      b.volPage = '';
      b.placedAt = null;
    }
    notifyListeners();
    await _saveList('bookmarks', bookmarks.map((e) => e.toJson()).toList());
  }

  Future<void> deleteBookmark(Bookmark b) async {
    bookmarks.remove(b);
    notifyListeners();
    await _saveList('bookmarks', bookmarks.map((e) => e.toJson()).toList());
  }

  // ---------- التذكيرات ----------
  int _baseId(Reminder r) => 1000 + (reminders.indexOf(r) < 0 ? 0 : reminders.indexOf(r)) * 20;

  Future<void> _persistReminders() async {
    await _saveList('reminders', reminders.map((e) => e.toJson()).toList());
  }

  /// يعيد جدولة كل التذكيرات
  Future<void> rescheduleAll() async {
    await Daily.cancelRange(1000, 20 * (reminders.length + 3));
    for (final r in reminders) {
      if (!r.enabled) continue;
      final base = _baseId(r);
      final times = r.upcoming();
      for (var k = 0; k < times.length && k < 20; k++) {
        await Daily.scheduleAt(
          base + k,
          '⏰ ${r.title}',
          r.note.isEmpty ? 'اضغط للمتابعة' : r.note,
          times[k],
          payload: r.link.isEmpty ? 'reminder' : r.link,
        );
      }
    }
  }

  Future<void> saveReminder(Reminder r) async {
    if (!reminders.contains(r)) reminders.add(r);
    notifyListeners();
    await _persistReminders();
    await rescheduleAll();
  }

  Future<void> deleteReminder(Reminder r) async {
    reminders.remove(r);
    notifyListeners();
    await _persistReminders();
    await rescheduleAll();
  }

  Future<void> toggleReminder(Reminder r, bool v) async {
    r.enabled = v;
    notifyListeners();
    await _persistReminders();
    await rescheduleAll();
  }

  // ---------- التحميلات ----------
  bool isDownloaded(int id) => downloads.any((d) => d.id == id);

  Future<File> _file(int id) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/books');
    if (!d.existsSync()) d.createSync(recursive: true);
    return File('${d.path}/$id.json');
  }

  /// تحميل الكتاب كاملًا للقراءة دون إنترنت
  Future<void> download(int id, String name, String author) async {
    if (progress.containsKey(id)) return;
    progress[id] = 0;
    notifyListeners();
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse('https://files.turath.io/books/$id.json'));
      final res = await client.send(req);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final file = await _file(id);
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) {
          progress[id] = got / total;
          notifyListeners();
        }
      }
      await sink.close();
      downloads.removeWhere((d) => d.id == id);
      downloads.insert(0, DownloadedBook(id, name, author, got, DateTime.now()));
      await _saveList('downloads', downloads.map((e) => e.toJson()).toList());
    } finally {
      client.close();
      progress.remove(id);
      notifyListeners();
    }
  }

  Future<void> deleteDownload(int id) async {
    try {
      final f = await _file(id);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
    _cache.remove(id);
    downloads.removeWhere((d) => d.id == id);
    notifyListeners();
    await _saveList('downloads', downloads.map((e) => e.toJson()).toList());
  }

  static Map<String, dynamic> _decode(String s) => Map<String, dynamic>.from(jsonDecode(s) as Map);

  Future<_OfflineBook?> _open(int id) async {
    final c = _cache[id];
    if (c != null) return c;
    if (!isDownloaded(id)) return null;
    final f = await _file(id);
    if (!f.existsSync()) return null;
    final raw = await f.readAsString();
    final j = await Isolate.run(() => _decode(raw));
    final pages = <String>[];
    final vols = <String>[];
    final nums = <int>[];
    for (final p in (j['pages'] as List? ?? [])) {
      if (p is Map) {
        pages.add(cleanHtml('${p['text'] ?? ''}'));
        vols.add('${p['vol'] ?? ''}');
        nums.add((p['page'] as num?)?.toInt() ?? 0);
      }
    }
    final heads = <Heading>[];
    final idx = j['indexes'];
    if (idx is Map && idx['headings'] is List) {
      for (final h in idx['headings'] as List) {
        if (h is Map) {
          heads.add(Heading((h['level'] as num?)?.toInt() ?? 1, (h['page'] as num?)?.toInt() ?? 1,
              cleanHtml('${h['title'] ?? ''}')));
        }
      }
    }
    final b = _OfflineBook(pages, vols, nums, heads);
    _cache[id] = b;
    return b;
  }

  /// صفحة من كتاب محمّل، أو null إن لم يكن محمّلًا
  Future<PageData?> offlinePage(int bookId, int pageId, {String name = '', String author = ''}) async {
    try {
      final b = await _open(bookId);
      if (b == null || pageId < 1 || pageId > b.pages.length) return null;
      final i = pageId - 1;
      final dl = downloads.firstWhere((d) => d.id == bookId);
      final text = b.pages[i];
      final hit = Hit(
        bookId: bookId,
        bookName: name.isNotEmpty ? name : dl.name,
        authorName: author.isNotEmpty ? author : dl.author,
        vol: b.vols[i],
        page: b.nums[i],
        pageId: pageId,
        snippet: text.length > 250 ? '${text.substring(0, 250)}…' : text,
      );
      final heads = b.headings.where((h) => h.page <= pageId).toList();
      return PageData(hit, text, heads.isEmpty ? [] : [heads.last.title]);
    } catch (_) {
      return null;
    }
  }

  Future<int> offlinePageCount(int bookId) async {
    final b = await _open(bookId);
    return b?.pages.length ?? 0;
  }

  /// البحث في الكتب المحمّلة دون إنترنت
  Future<List<Hit>> searchOffline(String query, {int limit = 80}) async {
    final words = query.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty) return [];
    String norm(String s) => s
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    final keys = words.map(norm).toList();
    final out = <Hit>[];
    for (final d in downloads) {
      final b = await _open(d.id);
      if (b == null) continue;
      for (var i = 0; i < b.pages.length; i++) {
        final t = norm(b.pages[i]);
        if (keys.every(t.contains)) {
          final pos = t.indexOf(keys.first);
          final raw = b.pages[i];
          final start = pos < 60 ? 0 : pos - 60;
          final end = (start + 260) > raw.length ? raw.length : start + 260;
          out.add(Hit(
            bookId: d.id,
            bookName: d.name,
            authorName: d.author,
            vol: b.vols[i],
            page: b.nums[i],
            pageId: i + 1,
            snippet: raw.substring(start < raw.length ? start : 0, end).replaceAll(RegExp(r'\s+'), ' '),
          ));
          if (out.length >= limit) return out;
        }
        if (i % 400 == 0) await Future<void>.delayed(Duration.zero);
      }
    }
    return out;
  }

  Future<List<Heading>> offlineHeadings(int bookId) async {
    final b = await _open(bookId);
    return b?.headings ?? [];
  }
}

/// اسم اللون للعرض
Color colorOf(int v) => Color(v);
