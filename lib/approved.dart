import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// الكتب المعتمدة: قائمة يحددها المطوّر (العلماء وكتبهم مبوّبة)
class ABook {
  final int id;
  final String name;
  final int authorId;
  final int catId;
  final int pages;
  const ABook(this.id, this.name, this.authorId, this.catId, this.pages);
}

class AAuthor {
  final int id;
  final String name;
  final int death;
  const AAuthor(this.id, this.name, this.death);

  bool get alive => death >= 1450;
  String get deathLabel => alive ? 'معاصر' : 'ت $death هـ';
}

class ACat {
  final int id;
  final String name;
  const ACat(this.id, this.name);
}

class Approved {
  Approved._();
  static final instance = Approved._();

  List<ACat> cats = [];
  List<AAuthor> authors = [];
  List<ABook> books = [];
  final Map<int, AAuthor> authorById = {};
  final Map<int, ACat> catById = {};

  /// أرقام العلماء المعتمدين مفصولة بفواصل (لحصر البحث فيهم)
  String authorsCsv = '';

  static int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  Future<void> load() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/approved.json'));
      if (j is! Map) return;
      cats = [
        for (final c in (j['cats'] as List? ?? []))
          if (c is List && c.length >= 2) ACat(_i(c[0]), '${c[1]}')
      ];
      authors = [
        for (final a in (j['authors'] as List? ?? []))
          if (a is List && a.length >= 3) AAuthor(_i(a[0]), '${a[1]}', _i(a[2]))
      ];
      books = [
        for (final b in (j['books'] as List? ?? []))
          if (b is List && b.length >= 5) ABook(_i(b[0]), '${b[1]}', _i(b[2]), _i(b[3]), _i(b[4]))
      ];
      authorById.clear();
      for (final a in authors) {
        authorById[a.id] = a;
      }
      catById.clear();
      for (final c in cats) {
        catById[c.id] = c;
      }
      authorsCsv = authors.map((a) => a.id).join(',');
    } catch (_) {}
  }

  List<ABook> inCat(int id) => books.where((b) => b.catId == id).toList();
  List<ABook> byAuthor(int id) => books.where((b) => b.authorId == id).toList();
  int countCat(int id) => books.where((b) => b.catId == id).length;
  int countAuthor(int id) => books.where((b) => b.authorId == id).length;
  String authorName(int id) => authorById[id]?.name ?? '';
  String catName(int id) => catById[id]?.name ?? '';
  int deathOf(ABook b) => authorById[b.authorId]?.death ?? 9999;
}
