import 'package:flutter/material.dart';

import '../approved.dart';
import '../nav.dart';
import '../text_cleaner.dart';
import '../widgets/common.dart';
import 'book_page.dart';
import 'search_page.dart';

String _booksCount(int n) {
  if (n == 0) return 'لا كتب';
  if (n == 1) return 'كتاب واحد';
  if (n == 2) return 'كتابان';
  if (n <= 10) return '$n كتب';
  return '$n كتابًا';
}

bool _match(String name, String q) => TextCleaner.normalize(name).contains(TextCleaner.normalize(q));

/// تبويب «الكتب المعتمدة»: الأبواب والعلماء، ولا يظهر إلا ما اعتمده المطوّر
class ApprovedPage extends StatefulWidget {
  const ApprovedPage({super.key});

  @override
  State<ApprovedPage> createState() => _ApprovedPageState();
}

class _ApprovedPageState extends State<ApprovedPage> {
  int _seg = 0;
  String _q = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap = Approved.instance;
    final q = _q.trim();
    final found = q.isEmpty ? const <ABook>[] : ap.books.where((b) => _match(b.name, q)).take(80).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'الكتب المعتمدة',
          subtitle: '${_booksCount(ap.books.length)} لـ ${ap.authors.length} عالمًا',
          icon: Icons.verified_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: TextField(
            controller: _controller,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم كتاب…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _q = '');
                      },
                    ),
              filled: true,
              fillColor: fieldColor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (q.isNotEmpty) ...[
          if (found.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا يوجد كتاب بهذا الاسم في الكتب المعتمدة')),
            ),
          for (final b in found) _BookTile(book: b),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الأبواب'),
                  selected: _seg == 0,
                  onSelected: (_) => setState(() => _seg = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('العلماء'),
                  selected: _seg == 1,
                  onSelected: (_) => setState(() => _seg = 1),
                ),
              ],
            ),
          ),
          if (_seg == 0)
            for (final c in ap.cats) _catTile(context, c)
          else
            for (final a in _sortedAuthors()) _authorTile(context, a),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  List<AAuthor> _sortedAuthors() {
    final l = [...Approved.instance.authors];
    l.sort((a, b) => a.death.compareTo(b.death));
    return l;
  }

  Widget _catTile(BuildContext context, ACat c) {
    final n = Approved.instance.countCat(c.id);
    final off = n == 0;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: off
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BookListPage(title: c.name, books: Approved.instance.inCat(c.id)),
              )),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: off ? Theme.of(context).disabledColor : kGold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(c.name,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: off ? Theme.of(context).disabledColor : null)),
          ),
          _CountPill(n: n),
        ],
      ),
    );
  }

  Widget _authorTile(BuildContext context, AAuthor a) {
    final n = Approved.instance.countAuthor(a.id);
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookListPage(title: a.name, books: Approved.instance.byAuthor(a.id), authorId: a.id),
      )),
      child: Row(
        children: [
          Icon(Icons.person_rounded, color: accent(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(a.deathLabel, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          _CountPill(n: n),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int n;
  const _CountPill({required this.n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: (n == 0 ? Colors.grey : kGold).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$n', style: TextStyle(fontWeight: FontWeight.bold, color: n == 0 ? Colors.grey : goldText(context))),
    );
  }
}

class _BookTile extends StatelessWidget {
  final ABook book;
  final bool showAuthor;
  final bool showCat;
  const _BookTile({required this.book, this.showAuthor = true, this.showCat = true});

  @override
  Widget build(BuildContext context) {
    final ap = Approved.instance;
    final parts = <String>[
      if (showAuthor) ap.authorName(book.authorId),
      if (showCat) ap.catName(book.catId),
      if (book.pages > 0) '${book.pages} صفحة',
    ].where((s) => s.isNotEmpty).join('  •  ');
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookPage(bookId: book.id, name: book.name, author: ap.authorName(book.authorId)),
      )),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, color: accent(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.5)),
                if (parts.isNotEmpty)
                  Text(parts, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
    );
  }
}

/// قائمة كتب باب أو عالِم، مع الترتيب
class BookListPage extends StatefulWidget {
  final String title;
  final List<ABook> books;
  final int? authorId;
  const BookListPage({super.key, required this.title, required this.books, this.authorId});

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  int _sort = 0;

  List<ABook> get _sorted {
    final ap = Approved.instance;
    final l = [...widget.books];
    if (_sort == 0) {
      l.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sort == 1) {
      l.sort((a, b) {
        final c = ap.deathOf(a).compareTo(ap.deathOf(b));
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    } else {
      l.sort((a, b) {
        final c = widget.authorId != null
            ? ap.catName(a.catId).compareTo(ap.catName(b.catId))
            : ap.authorName(a.authorId).compareTo(ap.authorName(b.authorId));
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final byAuthor = widget.authorId != null;
    final list = _sorted;
    final labels = byAuthor ? const ['الاسم', 'الباب'] : const ['الاسم', 'الأقدم أولًا', 'العالِم'];
    final values = byAuthor ? const [0, 2] : const [0, 1, 2];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (byAuthor)
            IconButton(
              tooltip: 'ابحث في كتبه',
              icon: const Icon(Icons.manage_search_rounded),
              onPressed: () => searchWithin(
                context,
                SearchScope(label: 'في كتب ${widget.title}', authorId: widget.authorId),
              ),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 30),
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_booksCount(list.length), style: TextStyle(fontWeight: FontWeight.bold, color: accent(context))),
                  for (var k = 0; k < labels.length; k++)
                    ChoiceChip(
                      label: Text(labels[k]),
                      selected: _sort == values[k],
                      onSelected: (_) => setState(() => _sort = values[k]),
                    ),
                ],
              ),
            );
          }
          return _BookTile(book: list[i - 1], showAuthor: !byAuthor);
        },
      ),
    );
  }
}

/// اختيار كتاب أو عالِم لحصر البحث فيه
class ScopePickerPage extends StatefulWidget {
  final bool authors;
  const ScopePickerPage({super.key, required this.authors});

  @override
  State<ScopePickerPage> createState() => _ScopePickerPageState();
}

class _ScopePickerPageState extends State<ScopePickerPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final ap = Approved.instance;
    final q = _q.trim();
    final authors = widget.authors
        ? ap.authors.where((a) => q.isEmpty || _match(a.name, q)).toList()
        : const <AAuthor>[];
    final books = widget.authors
        ? const <ABook>[]
        : ap.books.where((b) => q.isEmpty || _match(b.name, q)).take(150).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.authors ? 'اختر عالِمًا' : 'اختر كتابًا')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: !widget.authors,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: widget.authors ? 'اسم العالِم…' : 'اسم الكتاب…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: fieldColor(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.authors ? authors.length : books.length,
              itemBuilder: (context, i) {
                if (widget.authors) {
                  final a = authors[i];
                  return ListTile(
                    leading: Icon(Icons.person_rounded, color: accent(context)),
                    title: Text(a.name),
                    subtitle: Text('${a.deathLabel}  •  ${_booksCount(ap.countAuthor(a.id))}'),
                    onTap: () =>
                        Navigator.of(context).pop(SearchScope(label: 'في كتب ${a.name}', authorId: a.id)),
                  );
                }
                final b = books[i];
                return ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: accent(context)),
                  title: Text(b.name),
                  subtitle: Text(ap.authorName(b.authorId)),
                  onTap: () => Navigator.of(context).pop(SearchScope(label: 'في «${b.name}»', bookId: b.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
