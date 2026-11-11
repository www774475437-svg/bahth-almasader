import 'package:flutter/material.dart';

import '../library.dart';
import '../nav.dart';
import '../storage.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import 'author_page.dart';
import 'page_viewer.dart';
import 'reminders_page.dart';
import 'plans.dart';
import '../reading.dart';
import 'search_page.dart';

/// بطاقة الكتاب وفهرسه
class BookPage extends StatefulWidget {
  final int bookId;
  final String name;
  final String author;
  const BookPage({super.key, required this.bookId, required this.name, this.author = ''});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  BookInfo? _book;
  String? _error;
  bool _showInfo = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Store.instance.addRecentBook(widget.bookId, widget.name, widget.author);
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await TurathApi.getBook(widget.bookId, withIndexes: true);
      if (mounted) setState(() => _book = b);
    } catch (_) {
      // دون إنترنت: نستعمل فهرس الكتاب المحمّل
      final heads = await Library.instance.offlineHeadings(widget.bookId);
      if (!mounted) return;
      if (heads.isNotEmpty) {
        setState(() => _book = BookInfo(widget.bookId, widget.name, 0, '', null, heads));
      } else {
        setState(() => _error = 'تعذّر تحميل بيانات الكتاب');
      }
    }
  }

  void _openPage(int pageId) {
    final hit = Hit(
      bookId: widget.bookId,
      authorId: _book?.authorId ?? 0,
      bookName: widget.name,
      authorName: widget.author,
      vol: '',
      page: 0,
      pageId: pageId <= 0 ? 1 : pageId,
      snippet: '',
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageViewer(start: hit, query: '')));
  }

  @override
  Widget build(BuildContext context) {
    final b = _book;
    final outline = Theme.of(context).colorScheme.outline;
    final headings = b == null
        ? <Heading>[]
        : (_filter.isEmpty ? b.headings : b.headings.where((h) => h.title.contains(_filter)).toList());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle(size: 17)),
        actions: [
          ListenableBuilder(
            listenable: Store.instance,
            builder: (context, _) {
              final fav = Store.instance.isFavBook(widget.bookId);
              return IconButton(
                tooltip: fav ? 'إزالة من الكتب المفضلة' : 'كتاب مفضل',
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: fav ? const Color(0xFFFF8A80) : Colors.white),
                onPressed: () async {
                  final now = await Store.instance.toggleFavBook(widget.bookId, widget.name);
                  if (context.mounted) {
                    showSnack(context, now ? 'أُضيف إلى الكتب المفضلة ❤️' : 'أُزيل من المفضلة');
                  }
                },
              );
            },
          ),
          IconButton(
            tooltip: 'افتح في تراث',
            icon: const Icon(Icons.travel_explore_rounded),
            onPressed: () => openInApp(context, Uri.parse('https://app.turath.io/book/${widget.bookId}'),
                title: widget.name),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: headings.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name, style: titleStyle(size: 20, color: accent(context))),
                      if (widget.author.isNotEmpty)
                        InkWell(
                          onTap: b == null || b.authorId == 0
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => AuthorPage(authorId: b.authorId, name: widget.author),
                                  )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.person_rounded, size: 18, color: goldText(context)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(widget.author,
                                      style: TextStyle(
                                          color: goldText(context),
                                          decoration: TextDecoration.underline,
                                          decorationColor: goldText(context))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (b?.deathYear != null) PagePill('توفي المؤلف سنة ${b!.deathYear} هـ'),
                      if (b != null && b.info.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          b.info,
                          maxLines: _showInfo ? null : 4,
                          overflow: _showInfo ? null : TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.7, fontSize: 13.5),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showInfo = !_showInfo),
                          child: Text(_showInfo ? 'أقل' : 'بطاقة الكتاب كاملة'),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: kGreen),
                              onPressed: () => searchWithin(
                                context,
                                SearchScope(label: 'في كتاب: ${widget.name}', bookId: widget.bookId),
                              ),
                              icon: const Icon(Icons.manage_search_rounded),
                              label: const Text('ابحث في هذا الكتاب'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openPage(1),
                            icon: const Icon(Icons.auto_stories_rounded),
                            label: const Text('اقرأ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: Library.instance,
                        builder: (context, _) {
                          final lib = Library.instance;
                          final prog = lib.progress[widget.bookId];
                          final dl = lib.isDownloaded(widget.bookId);
                          return Row(
                            children: [
                              Expanded(
                                child: prog != null
                                    ? Column(
                                        children: [
                                          const Text('جارٍ التحميل…'),
                                          LinearProgressIndicator(value: prog == 0 ? null : prog, color: kGreen),
                                        ],
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: dl
                                            ? () => lib.deleteDownload(widget.bookId)
                                            : () => lib.download(widget.bookId, widget.name, widget.author).then((_) {
                                                  if (context.mounted) showSnack(context, 'حُمّل الكتاب ✓');
                                                }).catchError((_) {
                                                  if (context.mounted) showSnack(context, 'تعذّر التحميل');
                                                }),
                                        icon: Icon(dl ? Icons.delete_outline_rounded : Icons.download_rounded),
                                        label: Text(dl ? 'حذف التحميل' : 'تحميل للقراءة دون إنترنت'),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ReminderEditor(
                                    initialTitle: 'أكمل قراءة «${widget.name}» 📖',
                                    link: 'book:${widget.bookId}',
                                  ),
                                )),
                                icon: const Icon(Icons.alarm_add_rounded),
                                label: const Text('ذكّرني'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ListenableBuilder(
                        listenable: Reading.instance,
                        builder: (context, _) {
                          final p = Reading.instance.of(widget.bookId);
                          final frac = p?.fraction ?? 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: frac,
                                          minHeight: 8,
                                          color: frac >= 0.98 ? kGreen : kGold,
                                          backgroundColor: kGold.withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${p.percent}٪',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: goldText(context))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                children: [
                                  if (p != null)
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
                                        onPressed: () => _openPage(p.last),
                                        icon: const Icon(Icons.play_arrow_rounded),
                                        label: Text('أكمل من صفحة ${p.last}'),
                                      ),
                                    ),
                                  if (p != null) const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => showPlanEditor(context,
                                        bookId: widget.bookId,
                                        name: widget.name,
                                        author: widget.author,
                                        pageCount: _book?.pageCount ?? 0),
                                    icon: const Icon(Icons.event_note_rounded),
                                    label: const Text('ختمة'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: outline)),
                  )
                else if (b == null)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator(color: kGreen)),
                  )
                else ...[
                  SectionLabel('الفهرس (${b.headings.length})', icon: Icons.list_alt_rounded),
                  if (b.headings.length > 15)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: TextField(
                        onChanged: (v) => setState(() => _filter = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'ابحث في عناوين الأبواب…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          filled: true,
                          fillColor: cardColor(context),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  if (b.headings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('لا يوجد فهرس لهذا الكتاب', textAlign: TextAlign.center, style: TextStyle(color: outline)),
                    ),
                ],
              ],
            );
          }
          final h = headings[i - 1];
          final lvl = h.level < 1 ? 1 : (h.level > 5 ? 5 : h.level);
          return InkWell(
            onTap: () => _openPage(h.page),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 9, 16.0 + (lvl - 1) * 16, 9),
              child: Row(
                children: [
                  Icon(lvl == 1 ? Icons.bookmark_rounded : Icons.subdirectory_arrow_left_rounded,
                      size: lvl == 1 ? 18 : 15, color: lvl == 1 ? kGold : outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(h.title,
                        style: TextStyle(
                            fontWeight: lvl == 1 ? FontWeight.bold : FontWeight.normal,
                            fontSize: lvl == 1 ? 15 : 14,
                            height: 1.5)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
