import 'package:flutter/material.dart';

import '../data/uthaymeen.dart';
import '../nav.dart';
import '../reading.dart';
import '../widgets/common.dart';
import 'book_page.dart';
import 'search_page.dart';

/// بطاقة مجموعة ابن عثيمين (شفافة مع شريط التقدّم)
class UthaymeenBanner extends StatelessWidget {
  final double height;
  const UthaymeenBanner({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Reading.instance,
      builder: (context, _) {
        final f = Reading.instance.collectionFraction(kUthaymeenBooks.map((b) => b.id));
        final pct = (f * 100);
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UthaymeenPage())),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kGold.withValues(alpha: 0.45), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Stack(
                children: [
                  Opacity(
                    opacity: isDark(context) ? 0.88 : 0.96,
                    child: Image.asset('assets/uthaymeen.jpg', height: height, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.55)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: f == 0 ? 0.004 : f,
                                minHeight: 7,
                                color: kGold,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${pct < 1 && pct > 0 ? pct.toStringAsFixed(1) : pct.round()}٪',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// اقتراحات المطوّر
class DevPicksPage extends StatelessWidget {
  const DevPicksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('اقتراحات المطوّر ✨', style: titleStyle(size: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 30),
        children: [
          const SectionLabel('مكتبة الشيخ ابن عثيمين رَحِمَهُ الله', icon: Icons.auto_stories_rounded),
          const UthaymeenBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Text(
              'مؤلفات الشيخ وشروحه كاملة (${kUthaymeenBooks.length} كتابًا)، مع شريط يبيّن ما قرأته منها حتى تُتمّها.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, height: 1.7),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: kGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('مجموعات أخرى يختارها المطوّر قريبًا بإذن الله.',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// مكتبة ابن عثيمين: الأقسام والكتب مع التقدّم
class UthaymeenPage extends StatefulWidget {
  const UthaymeenPage({super.key});

  @override
  State<UthaymeenPage> createState() => _UthaymeenPageState();
}

class _UthaymeenPageState extends State<UthaymeenPage> {
  String? _cat;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Reading.instance,
      builder: (context, _) {
        final r = Reading.instance;
        final ids = kUthaymeenBooks.map((b) => b.id);
        final f = r.collectionFraction(ids);
        final started = kUthaymeenBooks.where((b) => (r.of(b.id)?.max ?? 0) > 0).length;
        final done = kUthaymeenBooks.where((b) => (r.of(b.id)?.fraction ?? 0) >= 0.98).length;
        final books = kUthaymeenBooks.where((b) {
          if (_cat != null && uthaymeenCategory(b.title) != _cat) return false;
          if (_q.isNotEmpty && !b.title.contains(_q)) return false;
          return true;
        }).toList();

        // آخر كتاب قُرئ من المجموعة
        CollectionBook? lastBook;
        DateTime? lastAt;
        for (final b in kUthaymeenBooks) {
          final p = r.of(b.id);
          if (p != null && (lastAt == null || p.updated.isAfter(lastAt))) {
            lastAt = p.updated;
            lastBook = b;
          }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: barColor(context),
            foregroundColor: Colors.white,
            title: Text('مكتبة ابن عثيمين', style: titleStyle(size: 18)),
            actions: [
              IconButton(
                tooltip: 'ابحث في كتب الشيخ',
                icon: const Icon(Icons.manage_search_rounded),
                onPressed: () => searchWithin(
                  context,
                  const SearchScope(label: 'في كتب ابن عثيمين', authorId: kUthaymeenAuthorId),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/uthaymeen.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
              AppCard(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${(f * 100).toStringAsFixed(f * 100 < 10 ? 1 : 0)}٪',
                            style: titleStyle(size: 30, color: accent(context))),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('من مؤلفات الشيخ قرأتها')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: f == 0 ? 0.004 : f,
                        minHeight: 10,
                        color: kGold,
                        backgroundColor: kGold.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('بدأت $started كتابًا • أتممت $done من ${kUthaymeenBooks.length}',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                    if (lastBook != null) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        onPressed: () => _open(lastBook!),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('أكمل: ${lastBook.title}', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث في عناوين كتب الشيخ…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: cardColor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('الكل (${kUthaymeenBooks.length})'),
                        selected: _cat == null,
                        onSelected: (_) => setState(() => _cat = null),
                      ),
                    ),
                    for (final c in kUthaymeenCategories)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('$c (${kUthaymeenBooks.where((b) => uthaymeenCategory(b.title) == c).length})'),
                          selected: _cat == c,
                          onSelected: (_) => setState(() => _cat = c),
                        ),
                      ),
                  ],
                ),
              ),
              for (final b in books) _tile(context, b, r.of(b.id)),
            ],
          ),
        );
      },
    );
  }

  void _open(CollectionBook b) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookPage(bookId: b.id, name: b.title, author: kUthaymeenName),
    ));
  }

  Widget _tile(BuildContext context, CollectionBook b, BookProgress? p) {
    final frac = p?.fraction ?? 0;
    final outline = Theme.of(context).colorScheme.outline;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => _open(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(frac >= 0.98 ? Icons.verified_rounded : Icons.menu_book_rounded,
                  color: frac >= 0.98 ? kGreen : kGold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(p == null ? '' : '${p.percent}٪',
                  style: TextStyle(color: goldText(context), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              color: frac >= 0.98 ? kGreen : kGold,
              backgroundColor: outline.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(uthaymeenCategory(b.title), style: TextStyle(fontSize: 11.5, color: outline)),
        ],
      ),
    );
  }
}
