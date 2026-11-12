import 'dart:convert';

import 'package:http/http.dart' as http;

import 'approved.dart';

/// يحوّل نص HTML القادم من تراث إلى نص عادي
String cleanHtml(String s) {
  return s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
}

int _toInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

Map<String, dynamic> _parseMeta(dynamic m) {
  if (m is Map) return Map<String, dynamic>.from(m);
  if (m is String && m.isNotEmpty) {
    try {
      final d = jsonDecode(m);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
  }
  return {};
}

String _arabicDigitsToLatin(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
  }
  return b.toString();
}

/// يستخرج سنة الوفاة (بالهجري) من بطاقة الكتاب أو المؤلف
int? parseDeathYear(String text) {
  final t = _arabicDigitsToLatin(text);
  final patterns = [
    RegExp(r'المتوف[ىي]\s*[:：]?\s*(?:سنة\s*)?(\d{1,4})'),
    RegExp(r'(?:توفي|تُوُفِّي|وفاته)\s*(?:سنة|عام)?\s*[:：]?\s*(\d{1,4})'),
    RegExp(r'\(\s*ت\s*[:.]?\s*(\d{1,4})'),
    RegExp(r'\(\s*\d{1,4}\s*-\s*(\d{1,4})\s*هـ'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      if (y != null && y > 0 && y < 1500) return y;
    }
  }
  return null;
}

/// نتيجة واحدة: صفحة من كتاب
class Hit {
  final int bookId;
  final int authorId;
  final String bookName;
  final String authorName;
  final String vol;
  final int page;
  final int pageId;
  final String snippet;

  const Hit({
    required this.bookId,
    this.authorId = 0,
    required this.bookName,
    required this.authorName,
    required this.vol,
    required this.page,
    required this.pageId,
    required this.snippet,
  });

  factory Hit.fromApi(Map<String, dynamic> j) {
    final meta = _parseMeta(j['meta']);
    return Hit(
      bookId: _toInt(j['book_id']),
      authorId: _toInt(j['author_id']),
      bookName: '${meta['book_name'] ?? ''}',
      authorName: '${meta['author_name'] ?? ''}',
      vol: '${meta['vol'] ?? ''}',
      page: _toInt(meta['page']),
      pageId: _toInt(meta['page_id']),
      snippet: cleanHtml('${j['snip'] ?? j['text'] ?? ''}').replaceAll(RegExp(r'\s+'), ' '),
    );
  }

  factory Hit.fromJson(Map<String, dynamic> j) => Hit(
        bookId: _toInt(j['bookId']),
        authorId: _toInt(j['authorId']),
        bookName: '${j['bookName'] ?? ''}',
        authorName: '${j['authorName'] ?? ''}',
        vol: '${j['vol'] ?? ''}',
        page: _toInt(j['page']),
        pageId: _toInt(j['pageId']),
        snippet: '${j['snippet'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'authorId': authorId,
        'bookName': bookName,
        'authorName': authorName,
        'vol': vol,
        'page': page,
        'pageId': pageId,
        'snippet': snippet,
      };

  String get key => '$bookId:$pageId';

  String get volPage {
    final v = vol.trim();
    return (v.isEmpty || v == '0' || v == 'null') ? '$page' : '$v/$page';
  }

  /// [📓اسم الكتاب (صـ 3/270)]
  String get sourceLine => '[📓$bookName (صـ $volPage)]';

  Uri get turathUrl => Uri.parse('https://app.turath.io/book/$bookId?page=$pageId');

  Hit copyWith({String? snippet, int? authorId}) => Hit(
        bookId: bookId,
        authorId: authorId ?? this.authorId,
        bookName: bookName,
        authorName: authorName,
        vol: vol,
        page: page,
        pageId: pageId,
        snippet: snippet ?? this.snippet,
      );
}

class SearchResult {
  final int count;
  final List<Hit> hits;
  const SearchResult(this.count, this.hits);
}

class PageData {
  final Hit hit;
  final String text;
  final List<String> headings;
  const PageData(this.hit, this.text, this.headings);
}

class Heading {
  final int level;
  final int page;
  final String title;
  const Heading(this.level, this.page, this.title);
}

class BookInfo {
  final int id;
  final String name;
  final int authorId;
  final String info;
  final int? deathYear;
  final List<Heading> headings;
  final int pageCount;
  const BookInfo(this.id, this.name, this.authorId, this.info, this.deathYear, this.headings, {this.pageCount = 0});
}

class AuthorInfo {
  final int id;
  final String info;
  final int? deathYear;
  const AuthorInfo(this.id, this.info, this.deathYear);

  String get name {
    final first = info.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return first.length > 80 ? '${first.substring(0, 80)}…' : first;
  }
}

class TurathApi {
  static const _host = 'api.turath.io';

  /// ذاكرة مؤقتة: سنة وفاة مؤلف كل كتاب
  static final Map<int, int?> deathByBook = {};
  static final Map<int, BookInfo> _books = {};
  static final Map<int, AuthorInfo> _authors = {};

  static Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.https(_host, path, {...params, 'ver': '3'});
    final res = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  /// البحث: في الكتب المعتمدة فقط، ويمكن حصره في كتاب أو عالِم منها
  static Future<SearchResult> search(String q, {int page = 1, int? bookId, int? authorId}) async {
    final authors = authorId != null ? '$authorId' : (bookId == null ? Approved.instance.authorsCsv : '');
    final body = await _get('/search', {
      'q': q,
      if (page > 1) 'page': '$page',
      if (bookId != null) 'book': '$bookId',
      if (authors.isNotEmpty) 'author': authors,
    });
    final data = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Hit.fromApi(Map<String, dynamic>.from(e)))
        .toList();
    final count = (body['count'] as num?)?.toInt() ?? data.length;
    return SearchResult(count, data);
  }

  static Future<PageData> getPage(int bookId, int pageId) async {
    final body = await _get('/page', {'book_id': '$bookId', 'pg': '$pageId'});
    final meta = _parseMeta(body['meta']);
    final text = cleanHtml('${body['text'] ?? ''}');
    final heads = (meta['headings'] is List)
        ? (meta['headings'] as List).map((e) => cleanHtml('$e')).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final hit = Hit(
      bookId: bookId,
      bookName: '${meta['book_name'] ?? ''}',
      authorName: '${meta['author_name'] ?? ''}',
      vol: '${meta['vol'] ?? ''}',
      page: _toInt(meta['page']),
      pageId: meta['page_id'] == null ? pageId : _toInt(meta['page_id']),
      snippet: text.length > 250 ? '${text.substring(0, 250)}…' : text,
    );
    return PageData(hit, text, heads);
  }

  /// بطاقة الكتاب، ومعها الفهرس إن طُلب
  static Future<BookInfo> getBook(int id, {bool withIndexes = false}) async {
    final cached = _books[id];
    if (cached != null && (!withIndexes || cached.headings.isNotEmpty)) return cached;
    final body = await _get('/book', {'id': '$id', if (withIndexes) 'include': 'indexes'});
    final meta = body['meta'] is Map ? Map<String, dynamic>.from(body['meta'] as Map) : <String, dynamic>{};
    final info = cleanHtml('${meta['info_long'] ?? meta['info'] ?? ''}');
    final headings = <Heading>[];
    final idx = body['indexes'];
    var pageCount = 0;
    if (idx is Map && idx['page_map'] is List) pageCount = (idx['page_map'] as List).length;
    if (idx is Map && idx['headings'] is List) {
      for (final h in idx['headings'] as List) {
        if (h is Map) {
          headings.add(Heading(_toInt(h['level']), _toInt(h['page']), cleanHtml('${h['title'] ?? ''}')));
        }
      }
    }
    final b = BookInfo(id, '${meta['name'] ?? ''}', _toInt(meta['author_id']), info, parseDeathYear(info), headings,
        pageCount: pageCount);
    _books[id] = b;
    deathByBook[id] = b.deathYear;
    return b;
  }

  static Future<AuthorInfo> getAuthor(int id) async {
    final cached = _authors[id];
    if (cached != null) return cached;
    final body = await _get('/author', {'id': '$id'});
    final info = cleanHtml('${body['info'] ?? ''}');
    final a = AuthorInfo(id, info, parseDeathYear(info));
    _authors[id] = a;
    return a;
  }

  /// يجلب سنوات الوفاة لكتب النتائج (للترتيب من الأقدم)
  static Future<void> loadDeaths(Iterable<int> bookIds) async {
    final ids = bookIds.where((id) => !deathByBook.containsKey(id)).toSet().toList();
    for (var i = 0; i < ids.length; i += 6) {
      final batch = ids.sublist(i, i + 6 > ids.length ? ids.length : i + 6);
      await Future.wait(batch.map((id) async {
        try {
          final b = await getBook(id);
          if (b.deathYear == null && b.authorId > 0) {
            final a = await getAuthor(b.authorId);
            deathByBook[id] = a.deathYear;
          }
        } catch (_) {
          deathByBook[id] = null;
        }
      }));
    }
  }
}
