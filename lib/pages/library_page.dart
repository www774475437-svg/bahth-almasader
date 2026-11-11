import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../library.dart';
import '../storage.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import '../widgets/hit_card.dart';
import 'book_page.dart';
import 'page_viewer.dart';

/// تبويب «تراث»: الموقع داخل التطبيق، والكتب المفضلة والمحمّلة والأخيرة
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _seg = 0;
  late final WebViewController _web;
  int _progress = 0;
  int? _bookId;
  String _bookName = '';
  String _author = '';

  static final _bookRe = RegExp(r'/book/(\d+)');

  String _offQ = '';
  List<Hit>? _offResults;
  bool _offLoading = false;

  Future<void> _searchOffline(String q) async {
    _offQ = q.trim();
    if (_offQ.isEmpty) {
      setState(() => _offResults = null);
      return;
    }
    setState(() => _offLoading = true);
    final r = await Library.instance.searchOffline(_offQ);
    if (mounted) {
      setState(() {
        _offResults = r;
        _offLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onUrlChange: (c) => _onUrl(c.url ?? ''),
        onPageFinished: _onUrl,
      ))
      ..loadRequest(Uri.parse('https://app.turath.io/'));
  }

  Future<void> _onUrl(String url) async {
    final m = _bookRe.firstMatch(url);
    if (m == null) {
      if (_bookId != null && mounted) setState(() => _bookId = null);
      return;
    }
    final id = int.tryParse(m.group(1)!);
    if (id == null || id == _bookId) return;
    setState(() {
      _bookId = id;
      _bookName = 'كتاب رقم $id';
      _author = '';
    });
    try {
      final b = await TurathApi.getBook(id);
      if (!mounted || _bookId != id) return;
      String author = '';
      if (b.authorId > 0) {
        try {
          final a = await TurathApi.getAuthor(b.authorId);
          author = a.name;
        } catch (_) {}
      }
      if (mounted && _bookId == id) {
        setState(() {
          _bookName = b.name.isNotEmpty ? b.name : _bookName;
          _author = author;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(10, top + 8, 10, 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0F2E26), kDeepGreen]),
          ),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    selectedForegroundColor: kDeepGreen,
                    selectedBackgroundColor: kGold,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    visualDensity: VisualDensity.compact,
                  ),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('الموقع')),
                    ButtonSegment(value: 1, label: Text('مفضلة')),
                    ButtonSegment(value: 2, label: Text('محمّلة')),
                    ButtonSegment(value: 3, label: Text('الأخيرة')),
                  ],
                  selected: {_seg},
                  onSelectionChanged: (v) => setState(() => _seg = v.first),
                ),
              ),
              if (_seg == 0)
                IconButton(
                  tooltip: 'رجوع',
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  onPressed: () async {
                    if (await _web.canGoBack()) _web.goBack();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _seg,
            children: [
              _site(context),
              _favorites(context),
              _downloads(context),
              _recent(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _site(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _web),
        if (_progress < 100)
          LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: kGold, backgroundColor: Colors.transparent),
        if (_bookId != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: ListenableBuilder(
              listenable: Listenable.merge([Store.instance, Library.instance]),
              builder: (context, _) => _bookBar(context, _bookId!),
            ),
          ),
      ],
    );
  }

  Widget _bookBar(BuildContext context, int id) {
    final fav = Store.instance.isFavBook(id);
    final lib = Library.instance;
    final dl = lib.isDownloaded(id);
    final prog = lib.progress[id];
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: kDeepGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: kGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_bookName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            ),
            IconButton(
              tooltip: fav ? 'إزالة من المفضلة' : 'حفظ الكتاب في المفضلة',
              icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? const Color(0xFFFF8A80) : Colors.white),
              onPressed: () => Store.instance.toggleFavBook(id, _bookName),
            ),
            if (prog != null)
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(value: prog == 0 ? null : prog, strokeWidth: 2.5, color: kGold),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: dl ? 'محمّل' : 'تحميل للقراءة دون إنترنت',
                icon: Icon(dl ? Icons.offline_pin_rounded : Icons.download_rounded, color: dl ? kGold : Colors.white),
                onPressed: dl
                    ? null
                    : () => lib.download(id, _bookName, _author).then((_) {
                          if (context.mounted) showSnack(context, 'حُمّل «$_bookName» ✓');
                        }).catchError((_) {
                          if (context.mounted) showSnack(context, 'تعذّر التحميل');
                        }),
              ),
            IconButton(
              tooltip: 'بطاقة الكتاب وفهرسه',
              icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BookPage(bookId: id, name: _bookName, author: _author),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookTile(BuildContext context, int id, String name, String author,
      {Widget? trailing, String? sub, IconData icon = Icons.menu_book_rounded}) {
    final outline = Theme.of(context).colorScheme.outline;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookPage(bookId: id, name: name, author: author),
      )),
      child: Row(
        children: [
          Icon(icon, color: kGold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (author.isNotEmpty) Text(author, style: TextStyle(color: outline, fontSize: 12.5)),
                if (sub != null) Text(sub, style: TextStyle(color: outline, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _empty(String title, String sub, IconData icon) =>
      ListView(children: [const SizedBox(height: 40), EmptyState(icon: icon, title: title, subtitle: sub)]);

  Widget _favorites(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final favs = Store.instance.favBooks.entries.toList();
        if (favs.isEmpty) {
          return _empty('لا كتب مفضلة', 'افتح كتابًا في «الموقع» واضغط ❤️ لحفظه هنا.', Icons.favorite_border_rounded);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            for (final f in favs)
              _bookTile(context, f.key, f.value, '',
                  icon: Icons.favorite_rounded,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Store.instance.toggleFavBook(f.key, f.value),
                  )),
          ],
        );
      },
    );
  }

  Widget _downloads(BuildContext context) {
    return ListenableBuilder(
      listenable: Library.instance,
      builder: (context, _) {
        final lib = Library.instance;
        if (lib.downloads.isEmpty && lib.progress.isEmpty) {
          return _empty('لا كتب محمّلة', 'حمّل أي كتاب لتقرأه دون إنترنت: من شريط الكتاب في «الموقع» أو من صفحة الكتاب.',
              Icons.download_rounded);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            if (lib.downloads.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchOffline,
                  decoration: InputDecoration(
                    hintText: 'ابحث في الكتب المحمّلة (دون إنترنت)…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _offResults == null
                        ? null
                        : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _searchOffline('')),
                    isDense: true,
                    filled: true,
                    fillColor: cardColor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
            if (_offLoading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kGold))),
            if (_offResults != null && !_offLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(_offResults!.isEmpty ? 'لا نتائج في الكتب المحمّلة' : 'النتائج: ${_offResults!.length}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: accent(context))),
              ),
              for (var k = 0; k < _offResults!.length; k++)
                HitCard(hit: _offResults![k], query: _offQ, index: k),
              const Divider(height: 30),
            ],
            for (final e in lib.progress.entries)
              AppCard(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جارٍ تحميل كتاب رقم ${e.key}…'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: e.value == 0 ? null : e.value, color: kGreen),
                  ],
                ),
              ),
            for (final d in lib.downloads)
              _bookTile(context, d.id, d.name, d.author,
                  icon: Icons.offline_pin_rounded,
                  sub: '${d.sizeLabel} • ${d.date.year}/${d.date.month}/${d.date.day}',
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'read') {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PageViewer(
                            start: Hit(
                                bookId: d.id,
                                bookName: d.name,
                                authorName: d.author,
                                vol: '',
                                page: 0,
                                pageId: 1,
                                snippet: ''),
                            query: '',
                          ),
                        ));
                      } else if (v == 'delete') {
                        lib.deleteDownload(d.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'read', child: Text('اقرأ من البداية')),
                      PopupMenuItem(value: 'delete', child: Text('حذف التحميل')),
                    ],
                  )),
          ],
        );
      },
    );
  }

  Widget _recent(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final r = Store.instance.recentBooks;
        if (r.isEmpty) {
          return _empty('لا كتب بعد', 'ستظهر هنا الكتب التي تفتحها.', Icons.history_edu_rounded);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [for (final b in r) _bookTile(context, b.id, b.name, b.author, icon: Icons.history_edu_rounded)],
        );
      },
    );
  }
}
