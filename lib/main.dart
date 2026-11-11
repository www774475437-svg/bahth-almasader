import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const TurathFinderApp());

class TurathFinderApp extends StatelessWidget {
  const TurathFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بحث المصادر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E5E4E),
        useMaterial3: true,
      ),
      // واجهة عربية من اليمين إلى اليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const SearchPage(),
    );
  }
}

/// نتيجة واحدة من نتائج البحث في تراث
class Hit {
  final int bookId;
  final String bookName;
  final String authorName;
  final String vol;
  final int page;
  final int pageId;
  final String snippet;

  Hit({
    required this.bookId,
    required this.bookName,
    required this.authorName,
    required this.vol,
    required this.page,
    required this.pageId,
    required this.snippet,
  });

  factory Hit.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> meta = {};
    final m = j['meta'];
    if (m is String) {
      meta = jsonDecode(m) as Map<String, dynamic>;
    } else if (m is Map) {
      meta = Map<String, dynamic>.from(m);
    }
    int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return Hit(
      bookId: toInt(j['book_id']),
      bookName: '${meta['book_name'] ?? ''}',
      authorName: '${meta['author_name'] ?? ''}',
      vol: '${meta['vol'] ?? ''}',
      page: toInt(meta['page']),
      pageId: toInt(meta['page_id']),
      snippet: _clean('${j['snip'] ?? j['text'] ?? ''}'),
    );
  }

  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// الجزء/الصفحة، مثل 3/270 أو 270 إن لم يكن للكتاب أجزاء
  String get volPage =>
      (vol.isEmpty || vol == '0' || vol == 'null') ? '$page' : '$vol/$page';

  /// سطر المصدر جاهزًا للنسخ
  String get sourceLine => '[📓$bookName (صـ $volPage)]';

  /// الرابط المباشر إلى الصفحة في تراث
  Uri get turathUrl =>
      Uri.parse('https://app.turath.io/book/$bookId?page=$pageId');
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final List<Hit> _hits = [];
  int _count = 0;
  int _resultsPage = 1;
  bool _loading = false;
  String? _error;

  Future<void> _search({bool more = false}) async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _hits.clear();
        _count = 0;
        _resultsPage = 1;
      }
    });
    try {
      final params = {
        'q': q,
        'ver': '3',
        if (more) 'page': '${_resultsPage + 1}',
      };
      final uri = Uri.https('api.turath.io', '/search', params);
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw 'رمز الخطأ ${res.statusCode}';
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = (body['data'] as List? ?? [])
          .map((e) => Hit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _count = (body['count'] as num?)?.toInt() ?? data.length;
        _hits.addAll(data);
        if (more) _resultsPage++;
      });
    } catch (e) {
      setState(() => _error = 'تعذّر البحث، تأكد من الاتصال بالإنترنت.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
      _search();
    }
  }

  Future<void> _open(Hit h) async {
    final ok = await launchUrl(h.turathUrl, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط')));
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ $label'), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث المصادر'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'عن التطبيق',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: const Text('بحث المصادر'),
                  content: const Text(
                    'الصق نصًّا ليظهر لك اسم الكتاب والجزء والصفحة، '
                    'مع رابط مباشر إلى الصفحة في «تراث».\n\n'
                    'المطوّر: أبو عبد الرحمن الأثري\n'
                    'الإصدار: 1.0.0',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسنًا'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'تطوير: أبو عبد الرحمن الأثري',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline, fontSize: 12),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'الصق النص هنا…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _hits.clear();
                        _count = 0;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _search(),
                        icon: const Icon(Icons.search),
                        label: const Text('ابحث'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _paste,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('لصق وبحث'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_count > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('عدد النتائج: $_count',
                    style: TextStyle(color: scheme.outline)),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          Expanded(
            child: _hits.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _count == 0 && _controller.text.isNotEmpty && _error == null
                          ? 'لا نتائج'
                          : 'ألصق نصًا لتعرف مصدره',
                      style: TextStyle(color: scheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _hits.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _hits.length) {
                        if (_loading) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _hits.length < _count
                            ? TextButton(
                                onPressed: () => _search(more: true),
                                child: const Text('المزيد من النتائج'))
                            : const SizedBox.shrink();
                      }
                      return _HitCard(
                        hit: _hits[i],
                        onOpen: () => _open(_hits[i]),
                        onCopySource: () => _copy(_hits[i].sourceLine, 'المصدر'),
                        onCopyLink: () =>
                            _copy(_hits[i].turathUrl.toString(), 'الرابط'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final Hit hit;
  final VoidCallback onOpen, onCopySource, onCopyLink;

  const _HitCard({
    required this.hit,
    required this.onOpen,
    required this.onCopySource,
    required this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📓 ${hit.bookName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (hit.authorName.isNotEmpty)
                Text(hit.authorName, style: TextStyle(color: scheme.outline)),
              const SizedBox(height: 4),
              Text('صـ ${hit.volPage}',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(hit.snippet, maxLines: 6, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('افتح في تراث'),
                  ),
                  TextButton.icon(
                    onPressed: onCopySource,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('نسخ المصدر'),
                  ),
                  TextButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('نسخ الرابط'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
