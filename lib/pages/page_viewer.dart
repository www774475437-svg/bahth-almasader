import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../library.dart';
import '../reading.dart';
import '../settings.dart';
import '../storage.dart';
import '../text_cleaner.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import '../widgets/translate_share.dart';
import 'book_page.dart';
import 'continuous_reader.dart';
import 'post_maker.dart';

/// قراءة الصفحة كاملة داخل التطبيق
class PageViewer extends StatefulWidget {
  final Hit start;
  final String query;
  const PageViewer({super.key, required this.start, required this.query});

  @override
  State<PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<PageViewer> {
  late int _pageId = widget.start.pageId;
  late Hit _hit = widget.start;
  String _text = '';
  bool _loading = true;
  bool _noTashkeel = false;
  bool _offline = false;
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  List<String> _headings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final off = await Library.instance.offlinePage(widget.start.bookId, _pageId,
          name: widget.start.bookName, author: widget.start.authorName);
      _offline = off != null;
      final p = off ?? await TurathApi.getPage(widget.start.bookId, _pageId);
      _text = p.text;
      _headings = p.headings;
      _hit = Hit(
        bookId: widget.start.bookId,
        authorId: widget.start.authorId,
        bookName: p.hit.bookName.isNotEmpty ? p.hit.bookName : widget.start.bookName,
        authorName: p.hit.authorName.isNotEmpty ? p.hit.authorName : widget.start.authorName,
        vol: p.hit.vol,
        page: p.hit.page,
        pageId: _pageId,
        snippet: _pageId == widget.start.pageId ? widget.start.snippet : p.hit.snippet,
      );
      Store.instance.addRecentBook(_hit.bookId, _hit.bookName, _hit.authorName);
      _recordProgress(_hit);
    } catch (_) {
      _error = 'تعذّر تحميل الصفحة، تأكد من الإنترنت ثم أعد المحاولة.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// يسجّل التقدّم في الكتاب (ونسبة الإنجاز)
  Future<void> _recordProgress(Hit h) async {
    var total = Reading.instance.of(h.bookId)?.total ?? 0;
    try {
      if (total <= 0) {
        total = _offline
            ? await Library.instance.offlinePageCount(h.bookId)
            : (await TurathApi.getBook(h.bookId, withIndexes: true)).pageCount;
      }
    } catch (_) {}
    await Reading.instance.recordPage(h, total: total);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// الاستماع للصفحة
  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.45);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      var t = TextCleaner.stripTashkeel(_text).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length > 3900) t = t.substring(0, 3900);
      setState(() => _speaking = true);
      await _tts.speak(t);
    } catch (_) {
      if (mounted) {
        setState(() => _speaking = false);
        showSnack(context, 'القارئ الصوتي العربي غير متاح في هذا الجوال');
      }
    }
  }

  /// تمييز نص محدد
  Future<void> _addHighlight(String text) async {
    final t = text.trim();
    if (t.length < 2) return;
    final noteCtrl = TextEditingController();
    final color = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: cardColor(context),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تمييز', style: titleStyle(size: 18, color: accent(ctx))),
            const SizedBox(height: 8),
            Text('«$t»', maxLines: 3, overflow: TextOverflow.ellipsis, style: bookStyle(ctx, size: 15)),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)')),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              children: [
                for (final c in const [0xFFF2C94C, 0xFF6FCF57, 0xFF3B82F6, 0xFFE5534B, 0xFFA78BFA])
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, c),
                    child: CircleAvatar(radius: 22, backgroundColor: Color(c)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (color == null) return;
    await Reading.instance.addHighlight(Highlight(
      id: Library.newId(),
      bookId: _hit.bookId,
      bookName: _hit.bookName,
      author: _hit.authorName,
      pageId: _pageId,
      volPage: _hit.volPage,
      text: t,
      color: color,
      note: noteCtrl.text.trim(),
      date: DateTime.now(),
    ));
    if (mounted) showSnack(context, 'مُيِّز النص 🖍️');
  }

  /// نص الصفحة مع تلوين كلمات البحث والتمييزات
  TextSpan _pageSpan(BuildContext context) {
    final base = bookStyle(context, size: 19);
    final hl = isDark(context) ? kGold : kGreen;
    final keys = keysOf(widget.query);
    final text = _shown;
    final ranges = <List<int>>[];
    for (final h in Reading.instance.highlightsOn(_hit.bookId, _pageId)) {
      var needle = _noTashkeel ? TextCleaner.stripTashkeel(h.text) : h.text;
      var i = text.indexOf(needle);
      if (i < 0) {
        needle = TextCleaner.stripTashkeel(h.text);
        i = text.indexOf(needle);
      }
      if (i >= 0 && !ranges.any((r) => i < r[1] && i + needle.length > r[0])) {
        ranges.add([i, i + needle.length, h.color]);
      }
    }
    if (ranges.isEmpty) return highlighted(text, keys, base, hl);
    ranges.sort((a, b) => a[0].compareTo(b[0]));
    final out = <InlineSpan>[];
    var pos = 0;
    for (final r in ranges) {
      if (r[0] > pos) out.add(highlighted(text.substring(pos, r[0]), keys, base, hl));
      out.add(TextSpan(
        text: text.substring(r[0], r[1]),
        style: base.copyWith(backgroundColor: Color(r[2]).withValues(alpha: 0.38)),
      ));
      pos = r[1];
    }
    if (pos < text.length) out.add(highlighted(text.substring(pos), keys, base, hl));
    return TextSpan(children: out);
  }

  void _go(int delta) {
    if (_pageId + delta < 1) return;
    _pageId += delta;
    _load();
  }

  String get _shown => _noTashkeel ? TextCleaner.stripTashkeel(_text) : _text;

  /// وضع فاصل في هذه الصفحة
  Future<void> _placeBookmark() async {
    final lib = Library.instance;
    final b = await showModalBottomSheet<Bookmark>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor(context),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ضع فاصلًا هنا', style: titleStyle(size: 18, color: accent(ctx))),
              const SizedBox(height: 6),
              for (final bm in lib.bookmarks)
                ListTile(
                  leading: Icon(bm.isSet ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: Color(bm.color), size: 30),
                  title: Text(bm.name),
                  subtitle: Text(bm.isSet ? 'الآن في: ${bm.bookName} (صـ ${bm.volPage})' : 'فارغ',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, bm),
                ),
            ],
          ),
        ),
      ),
    );
    if (b == null) return;
    await lib.placeBookmark(b, _hit);
    if (mounted) showSnack(context, 'وُضع الفاصل «${b.name}» هنا 🔖');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text(_hit.bookName,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle(size: 17)),
        actions: [
          ListenableBuilder(
            listenable: Store.instance,
            builder: (context, _) {
              final saved = Store.instance.isSaved(_hit);
              return IconButton(
                tooltip: 'حفظ',
                icon: Icon(saved ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: saved ? kGold : Colors.white),
                onPressed: _loading
                    ? null
                    : () async {
                        final now = await Store.instance.toggleSave(_hit, widget.query);
                        if (context.mounted) {
                          showSnack(context, now ? 'حُفظ في المحفوظات ⭐' : 'أُزيل من المحفوظات');
                        }
                      },
              );
            },
          ),
          ListenableBuilder(
            listenable: Library.instance,
            builder: (context, _) {
              final here = Library.instance.bookmarks
                  .where((b) => b.bookId == _hit.bookId && b.pageId == _pageId)
                  .toList();
              return IconButton(
                tooltip: 'فاصل',
                icon: Icon(here.isEmpty ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
                    color: here.isEmpty ? Colors.white : Color(here.first.color)),
                onPressed: _loading ? null : _placeBookmark,
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final s = Settings.instance;
              switch (v) {
                case 'bigger':
                  s.setBookScale((s.bookScale + 0.1).clamp(0.8, 1.6).toDouble());
                  break;
                case 'smaller':
                  s.setBookScale((s.bookScale - 0.1).clamp(0.8, 1.6).toDouble());
                  break;
                case 'tashkeel':
                  setState(() => _noTashkeel = !_noTashkeel);
                  break;
                case 'share':
                  showShareSheet(context, text: _text, hit: _hit);
                  break;
                case 'copy':
                  copyText(context, _shown.trim(), 'نص الصفحة');
                  break;
                case 'continuous':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ContinuousReader(start: _hit, query: widget.query),
                  ));
                  break;
                case 'copysrc':
                  copyText(context, '«${_shown.trim()}»\n\n${_hit.sourceLine}', 'النص مع المصدر');
                  break;
                case 'translate':
                  showTranslateSheet(context, _shown);
                  break;
                case 'download':
                  Library.instance.download(_hit.bookId, _hit.bookName, _hit.authorName).then((_) {
                    if (context.mounted) showSnack(context, 'حُمّل الكتاب ✓ يمكنك قراءته دون إنترنت');
                  }).catchError((_) {
                    if (context.mounted) showSnack(context, 'تعذّر التحميل');
                  });
                  showSnack(context, 'بدأ تحميل الكتاب…');
                  break;
                case 'book':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookPage(bookId: _hit.bookId, name: _hit.bookName, author: _hit.authorName),
                  ));
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'book', child: Text('فهرس الكتاب وبطاقته')),
              const PopupMenuItem(value: 'bigger', child: Text('تكبير الخط')),
              const PopupMenuItem(value: 'smaller', child: Text('تصغير الخط')),
              PopupMenuItem(value: 'tashkeel', child: Text(_noTashkeel ? 'إظهار التشكيل' : 'إخفاء التشكيل')),
              const PopupMenuItem(value: 'continuous', child: Text('القراءة المتواصلة 📜')),
              const PopupMenuItem(value: 'copy', child: Text('نسخ نص الصفحة')),
              const PopupMenuItem(value: 'copysrc', child: Text('نسخ النص مع المصدر')),
              const PopupMenuItem(value: 'share', child: Text('مشاركة الصفحة')),
              const PopupMenuItem(value: 'translate', child: Text('ترجمة الصفحة')),
              if (!Library.instance.isDownloaded(_hit.bookId))
                const PopupMenuItem(value: 'download', child: Text('تحميل الكتاب للقراءة دون إنترنت')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: cardColor(context),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(_hit.authorName,
                      style: TextStyle(color: scheme.outline, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (_offline)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.offline_pin_rounded, color: kGreen, size: 18),
                  ),
                PagePill('صـ ${_hit.volPage}'),
              ],
            ),
          ),
          if (_headings.isNotEmpty && !_loading)
            Container(
              width: double.infinity,
              color: kGold.withValues(alpha: 0.10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_rounded, size: 16, color: kGold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_headings.join(' ← '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: goldText(context), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kGreen))
                  : _error != null
                      ? EmptyState(icon: Icons.cloud_off_rounded, title: 'لم تُحمَّل الصفحة', subtitle: _error!)
                      : ListenableBuilder(
                          key: ValueKey(_pageId),
                          listenable: Settings.instance,
                          builder: (context, _) => SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                            child: ListenableBuilder(
                              listenable: Reading.instance,
                              builder: (context, _) => SelectableText.rich(
                                _pageSpan(context),
                                contextMenuBuilder: (ctx, state) {
                                  final v = state.textEditingValue;
                                  final sel = v.selection;
                                  final items = [...state.contextMenuButtonItems];
                                  if (sel.isValid && !sel.isCollapsed) {
                                    final picked = sel.textInside(v.text);
                                    items.insertAll(0, [
                                      ContextMenuButtonItem(
                                        label: 'تمييز 🖍️',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _addHighlight(picked);
                                        },
                                      ),
                                      ContextMenuButtonItem(
                                        label: 'ترجمة',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          showTranslateSheet(context, picked);
                                        },
                                      ),
                                      ContextMenuButtonItem(
                                        label: 'منشور',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          Navigator.of(context).push(MaterialPageRoute(
                                            builder: (_) => PostMaker(hit: _hit, text: picked),
                                          ));
                                        },
                                      ),
                                    ]);
                                  }
                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: state.contextMenuAnchors,
                                    buttonItems: items,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: cardColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'الصفحة السابقة',
                    onPressed: _loading ? null : () => _go(-1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 30),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BarButton(
                          icon: _speaking ? Icons.stop_circle_rounded : Icons.headphones_rounded,
                          label: _speaking ? 'إيقاف' : 'استماع',
                          onTap: _text.isEmpty ? null : _toggleSpeak,
                        ),
                        _BarButton(
                          icon: Icons.translate_rounded,
                          label: 'ترجمة',
                          onTap: _text.isEmpty ? null : () => showTranslateSheet(context, _shown),
                        ),
                        _BarButton(
                          icon: Icons.share_rounded,
                          label: 'مشاركة',
                          onTap: _text.isEmpty ? null : () => showShareSheet(context, text: _text, hit: _hit),
                        ),
                        _BarButton(
                          icon: Icons.edit_note_rounded,
                          label: 'منشور',
                          onTap: _text.isEmpty
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PostMaker(hit: _hit, text: _shown),
                                  )),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'الصفحة التالية',
                    onPressed: _loading ? null : () => _go(1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _BarButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? Theme.of(context).disabledColor : accent(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            Text(label, style: TextStyle(fontSize: 11.5, color: c)),
          ],
        ),
      ),
    );
  }
}
