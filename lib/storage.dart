import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'turath_api.dart';

class SavedItem {
  final Hit hit;
  final String query;
  final DateTime savedAt;
  String folder;
  String note;

  SavedItem(this.hit, this.query, this.savedAt, {this.folder = '', this.note = ''});

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        Hit.fromJson(Map<String, dynamic>.from(j['hit'] as Map)),
        '${j['query'] ?? ''}',
        DateTime.tryParse('${j['savedAt']}') ?? DateTime.now(),
        folder: '${j['folder'] ?? ''}',
        note: '${j['note'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'hit': hit.toJson(),
        'query': query,
        'savedAt': savedAt.toIso8601String(),
        'folder': folder,
        'note': note,
      };
}

/// المحفوظات والمجلدات وسجل البحث — محفوظة على الجهاز
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  static const defaultFolders = ['فوائد', 'أحاديث', 'طرائف', 'شعر'];

  SharedPreferences? _p;
  List<SavedItem> saved = [];
  List<String> folders = [...defaultFolders];
  List<String> history = [];
  String lastClipboardOffer = '';

  /// الكتب المفضلة: رقم الكتاب ← اسمه
  Map<int, String> favBooks = {};

  /// آخر الكتب المفتوحة
  List<RecentBook> recentBooks = [];

  /// يُستدعى عند تغيّر المحفوظات (لتحديث الويدجت والإشعار)
  VoidCallback? onSavedChanged;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    saved = (p.getStringList('saved') ?? [])
        .map((s) {
          try {
            return SavedItem.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedItem>()
        .toList();
    folders = p.getStringList('folders') ?? [...defaultFolders];
    history = p.getStringList('history') ?? [];
    lastClipboardOffer = p.getString('lastClipboardOffer') ?? '';
    try {
      final f = jsonDecode(p.getString('favBooks') ?? '{}') as Map;
      favBooks = f.map((k, v) => MapEntry(int.tryParse('$k') ?? 0, '$v'));
    } catch (_) {
      favBooks = {};
    }
    recentBooks = (p.getStringList('recentBooks') ?? [])
        .map((s) {
          try {
            return RecentBook.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentBook>()
        .toList();
    notifyListeners();
  }

  Future<void> _persistSaved() async {
    await _p?.setStringList('saved', saved.map((s) => jsonEncode(s.toJson())).toList());
    onSavedChanged?.call();
  }

  // ===== الكتب المفضلة =====
  bool isFavBook(int id) => favBooks.containsKey(id);

  Future<bool> toggleFavBook(int id, String name) async {
    final now = !favBooks.containsKey(id);
    if (now) {
      favBooks[id] = name;
    } else {
      favBooks.remove(id);
    }
    notifyListeners();
    await _p?.setString('favBooks', jsonEncode(favBooks.map((k, v) => MapEntry('$k', v))));
    return now;
  }

  // ===== آخر الكتب =====
  Future<void> addRecentBook(int id, String name, String author) async {
    if (id <= 0 || name.isEmpty) return;
    recentBooks.removeWhere((b) => b.id == id);
    recentBooks.insert(0, RecentBook(id, name, author));
    if (recentBooks.length > 20) recentBooks = recentBooks.sublist(0, 20);
    notifyListeners();
    await _p?.setStringList('recentBooks', recentBooks.map((b) => jsonEncode(b.toJson())).toList());
  }

  // ===== مشاركة مجلد واستيراده =====
  String exportFolderJson(String? folder) {
    final items = folder == null ? saved : saved.where((s) => s.folder == folder).toList();
    return jsonEncode({
      'app': 'bahth_almasader',
      'version': 1,
      'folder': folder ?? '',
      'items': items.map((s) => s.toJson()).toList(),
    });
  }

  /// يرجع عدد الفوائد المضافة
  Future<int> importJson(String json) async {
    final d = jsonDecode(json);
    if (d is! Map || d['app'] != 'bahth_almasader' || d['items'] is! List) {
      throw const FormatException('ملف غير صالح');
    }
    var added = 0;
    for (final e in d['items'] as List) {
      if (e is! Map) continue;
      final item = SavedItem.fromJson(Map<String, dynamic>.from(e));
      if (isSaved(item.hit)) continue;
      if (item.folder.isNotEmpty && !folders.contains(item.folder)) folders.add(item.folder);
      saved.add(item);
      added++;
    }
    saved.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    notifyListeners();
    await _p?.setStringList('folders', folders);
    await _persistSaved();
    return added;
  }

  bool isSaved(Hit h) => saved.any((s) => s.hit.key == h.key);

  SavedItem? find(Hit h) {
    for (final s in saved) {
      if (s.hit.key == h.key) return s;
    }
    return null;
  }

  /// يحفظ النتيجة أو يزيلها، ويرجع true إن صارت محفوظة
  Future<bool> toggleSave(Hit h, String query) async {
    final i = saved.indexWhere((s) => s.hit.key == h.key);
    if (i >= 0) {
      saved.removeAt(i);
    } else {
      saved.insert(0, SavedItem(h, query, DateTime.now()));
    }
    notifyListeners();
    await _persistSaved();
    return i < 0;
  }

  Future<void> remove(SavedItem item) async {
    saved.remove(item);
    notifyListeners();
    await _persistSaved();
  }

  Future<void> setFolder(SavedItem item, String folder) async {
    item.folder = folder;
    notifyListeners();
    await _persistSaved();
  }

  Future<void> setNote(SavedItem item, String note) async {
    item.note = note.trim();
    notifyListeners();
    await _persistSaved();
  }

  Future<void> addFolder(String name) async {
    final n = name.trim();
    if (n.isEmpty || folders.contains(n)) return;
    folders.add(n);
    notifyListeners();
    await _p?.setStringList('folders', folders);
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final n = newName.trim();
    if (n.isEmpty || folders.contains(n)) return;
    final i = folders.indexOf(oldName);
    if (i < 0) return;
    folders[i] = n;
    for (final s in saved) {
      if (s.folder == oldName) s.folder = n;
    }
    notifyListeners();
    await _p?.setStringList('folders', folders);
    await _persistSaved();
  }

  Future<void> deleteFolder(String name) async {
    folders.remove(name);
    for (final s in saved) {
      if (s.folder == name) s.folder = '';
    }
    notifyListeners();
    await _p?.setStringList('folders', folders);
    await _persistSaved();
  }

  /// فائدة عشوائية من المحفوظات (تتغير كل يوم)
  SavedItem? dailyPick() {
    if (saved.isEmpty) return null;
    final now = DateTime.now();
    final seed = now.year * 1000 + now.month * 50 + now.day;
    return saved[Random(seed).nextInt(saved.length)];
  }

  Future<void> addHistory(String q) async {
    history.remove(q);
    history.insert(0, q);
    if (history.length > 60) history = history.sublist(0, 60);
    notifyListeners();
    await _p?.setStringList('history', history);
  }

  Future<void> removeHistory(String q) async {
    history.remove(q);
    notifyListeners();
    await _p?.setStringList('history', history);
  }

  Future<void> clearHistory() async {
    history = [];
    notifyListeners();
    await _p?.setStringList('history', history);
  }

  Future<void> setLastClipboardOffer(String t) async {
    lastClipboardOffer = t;
    await _p?.setString('lastClipboardOffer', t);
  }
}

class RecentBook {
  final int id;
  final String name;
  final String author;
  const RecentBook(this.id, this.name, this.author);

  factory RecentBook.fromJson(Map<String, dynamic> j) =>
      RecentBook((j['id'] as num?)?.toInt() ?? 0, '${j['name'] ?? ''}', '${j['author'] ?? ''}');

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'author': author};
}
