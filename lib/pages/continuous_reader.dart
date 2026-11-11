import 'package:flutter/material.dart';

import '../library.dart';
import '../reading.dart';
import '../settings.dart';
import '../turath_api.dart';
import '../widgets/common.dart';

/// القراءة المتواصلة: الصفحات تتوالى بالتمرير، مع خلفية ورقية مريحة
class ContinuousReader extends StatefulWidget {
  final Hit start;
  final String query;
  const ContinuousReader({super.key, required this.start, this.query = ''});

  @override
  State<ContinuousReader> createState() => _ContinuousReaderState();
}

class _ContinuousReaderState extends State<ContinuousReader> {
  final _pages = <PageData>[];
  final _scroll = ScrollController();
  late int _next = widget.start.pageId < 1 ? 1 : widget.start.pageId;
  bool _loading = false;
  bool _end = false;
  bool _paper = true;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 900) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    try {
      for (var k = 0; k < 2; k++) {
        if (_total > 0 && _next > _total) {
          _end = true;
          break;
        }
        final off = await Library.instance.offlinePage(widget.start.bookId, _next,
            name: widget.start.bookName, author: widget.start.authorName);
        final p = off ?? await TurathApi.getPage(widget.start.bookId, _next);
        if (p.text.trim().isEmpty && _pages.isNotEmpty) {
          _end = true;
          break;
        }
        _pages.add(p);
        if (_total == 0) {
          _total = Reading.instance.of(widget.start.bookId)?.total ?? 0;
          if (_total == 0) {
            try {
              _total = off != null
                  ? await Library.instance.offlinePageCount(widget.start.bookId)
                  : (await TurathApi.getBook(widget.start.bookId, withIndexes: true)).pageCount;
            } catch (_) {}
          }
        }
        await Reading.instance.recordPage(
          Hit(
            bookId: widget.start.bookId,
            bookName: p.hit.bookName.isNotEmpty ? p.hit.bookName : widget.start.bookName,
            authorName: p.hit.authorName.isNotEmpty ? p.hit.authorName : widget.start.authorName,
            vol: p.hit.vol,
            page: p.hit.page,
            pageId: _next,
            snippet: '',
          ),
          total: _total,
        );
        _next++;
      }
    } catch (_) {
      _end = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final paperBg = _paper ? const Color(0xFFF4ECD8) : Theme.of(context).scaffoldBackgroundColor;
    final ink = _paper ? const Color(0xFF2B2418) : Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      backgroundColor: paperBg,
      appBar: AppBar(
        backgroundColor: _paper ? const Color(0xFFEADFC4) : barColor(context),
        foregroundColor: _paper ? const Color(0xFF3B2F1C) : Colors.white,
        title: Text(widget.start.bookName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: _paper ? 'الخلفية العادية' : 'الخلفية الورقية',
            icon: Icon(_paper ? Icons.dark_mode_outlined : Icons.description_outlined),
            onPressed: () => setState(() => _paper = !_paper),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Settings.instance,
        builder: (context, _) => ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
          itemCount: _pages.length + 1,
          itemBuilder: (context, i) {
            if (i == _pages.length) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _end
                      ? Text('— نهاية الكتاب —', style: TextStyle(color: ink.withValues(alpha: 0.6)))
                      : const CircularProgressIndicator(color: kGold),
                ),
              );
            }
            final p = _pages[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Divider(color: ink.withValues(alpha: 0.15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('صـ ${p.hit.volPage}',
                          style: TextStyle(color: _paper ? const Color(0xFF8A6A1E) : goldText(context), fontSize: 12.5)),
                    ),
                    Expanded(child: Divider(color: ink.withValues(alpha: 0.15))),
                  ],
                ),
                if (p.headings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(p.headings.last,
                        textAlign: TextAlign.center,
                        style: titleStyle(size: 17, color: _paper ? const Color(0xFF6B4F12) : kGold)),
                  ),
                const SizedBox(height: 8),
                SelectableText.rich(
                  highlighted(p.text, keysOf(widget.query), bookStyle(context, size: 19, color: ink),
                      _paper ? const Color(0xFF8A6A1E) : kGold),
                ),
                const SizedBox(height: 18),
              ],
            );
          },
        ),
      ),
    );
  }
}
