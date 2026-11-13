import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../daily_benefit.dart';
import '../reading.dart';
import '../storage.dart';
import '../text_cleaner.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import '../widgets/hit_card.dart';
import '../widgets/voice_sheet.dart';
import 'approved_page.dart';
import 'book_page.dart';
import 'dev_picks_page.dart';
import 'history_page.dart';
import '../widgets/goal_card.dart';

/// حصر البحث في كتاب أو مؤلف
class SearchScope {
  final String label;
  final int? bookId;
  final int? authorId;
  const SearchScope({required this.label, this.bookId, this.authorId});
}

enum SortMode { relevance, oldest, favorites }

class _Group {
  final Passage passage;
  String? query;
  int count = 0;
  int page = 1;
  List<Hit> hits = [];
  bool loading = true;
  bool loadingMore = false;
  String? error;
  String? bookFilter;
  _Group(this.passage);

  List<String> get books {
    final seen = <String>[];
    for (final h in hits) {
      if (!seen.contains(h.bookName)) seen.add(h.bookName);
    }
    return seen;
  }

  List<Hit> get visible =>
      bookFilter == null ? hits : hits.where((h) => h.bookName == bookFilter).toList();
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<_Group> _groups = [];
  String? _message;
  String? _clipboardOffer;
  SearchScope? _scope;
  SortMode _sort = SortMode.relevance;
  bool _loadingDeaths = false;
  int _gen = 0;

  void setScope(SearchScope s) {
    setState(() {
      _scope = s;
      _groups = [];
      _message = null;
    });
    showSnack(context, 'سيكون البحث ${s.label}');
  }

  /// حصر البحث في كتاب واحد أو في كتب عالِم واحد من المعتمدين
  Future<void> _pickScope() async {
    final mode = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: const Text('البحث في كتاب واحد'),
              onTap: () => Navigator.pop(c, 0),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('البحث في كتب عالِم واحد'),
              onTap: () => Navigator.pop(c, 1),
            ),
            if (_scope != null)
              ListTile(
                leading: const Icon(Icons.clear_rounded),
                title: const Text('إلغاء الحصر (كل الكتب المعتمدة)'),
                onTap: () => Navigator.pop(c, 2),
              ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == 2) {
      setState(() => _scope = null);
      return;
    }
    final s = await Navigator.of(context).push<SearchScope>(
      MaterialPageRoute(builder: (_) => ScopePickerPage(authors: mode == 1)),
    );
    if (s != null && mounted) setScope(s);
  }

  /// يعيد رسم الصفحة الرئيسية (عند وصول فائدة اليوم)
  void refreshIdle() {
    if (mounted) setState(() {});
  }

  Widget _continueCard(BuildContext context) {
    final r = Store.instance.recentBooks.first;
    final pr = Reading.instance.of(r.id);
    final sub = [
      if (r.author.isNotEmpty) r.author,
      if (pr != null && pr.total > 0) 'قرأت ${pr.percent}٪',
    ].join('  •  ');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BookPage(bookId: r.id, name: r.name, author: r.author)))
          .then((_) => refreshIdle()),
      child: Row(
        children: [
          Icon(Icons.auto_stories_rounded, color: accent(context), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
                if (sub.isNotEmpty)
                  Text(sub, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
    );
  }

  Future<void> _voice() async {
    final t = await showVoiceSheet(context);
    if (t != null && t.trim().isNotEmpty) runSearch(t);
  }

  Future<void> _setSort(SortMode m) async {
    setState(() => _sort = m);
    if (m == SortMode.oldest) {
      setState(() => _loadingDeaths = true);
      await TurathApi.loadDeaths(_groups.expand((g) => g.hits).map((h) => h.bookId));
      if (mounted) setState(() => _loadingDeaths = false);
    }
  }

  List<Hit> _sorted(List<Hit> hits) {
    if (_sort == SortMode.relevance) return hits;
    final list = [...hits];
    if (_sort == SortMode.oldest) {
      int y(Hit h) => TurathApi.deathByBook[h.bookId] ?? 99999;
      list.sort((a, b) => y(a).compareTo(y(b)));
    } else {
      int f(Hit h) => Store.instance.isFavBook(h.bookId) ? 0 : 1;
      list.sort((a, b) => f(a).compareTo(f(b)));
    }
    return list;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// تُستدعى من السجل ومن «المشاركة إلى التطبيق»
  Future<void> runSearch([String? text]) async {
    if (text != null) _controller.text = text;
    final input = _controller.text;
    if (input.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final passages = TextCleaner.extract(input);
    if (passages.isEmpty) {
      setState(() {
        _groups = [];
        _message = 'لم أجد في النص كلمات عربية للبحث عنها.';
      });
      return;
    }

    final gen = ++_gen;
    setState(() {
      _message = null;
      _clipboardOffer = null;
      _groups = passages.map(_Group.new).toList();
    });
    Store.instance.addHistory(input.trim());
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await Future.wait(_groups.map((g) => _searchGroup(g, gen)));
  }

  /// يعرض اقتراح البحث عن نص منسوخ
  void offerClipboard(String text) {
    if (!mounted) return;
    setState(() => _clipboardOffer = text);
  }

  /// يبحث ثم يتحقق من كل نتيجة: لا يقبل إلا ما وُجد فيه النص (أو أكثره) كلماتٍ متتالية
  Future<void> _searchGroup(_Group g, int gen) async {
    try {
      final words = g.passage.words;
      final need = TextCleaner.requiredRun(words.length);
      final cands = <String, Hit>{};
      final foundBy = <String, String>{};
      var tried = 0;
      for (final q in TextCleaner.queries(words)) {
        if (tried >= 5) break;
        tried++;
        final r = await TurathApi.search(q, bookId: _scope?.bookId, authorId: _scope?.authorId);
        if (gen != _gen) return;
        for (final h in r.hits) {
          cands.putIfAbsent(h.key, () => h);
          foundBy.putIfAbsent(h.key, () => q);
        }
        final strong = r.hits.where((h) => TextCleaner.longestRun(words, TextCleaner.words(h.snippet)) >= need);
        if (strong.length >= 3) break;
      }

      final list = cands.values.take(30).toList();
      final score = <String, int>{};
      for (var i = 0; i < list.length; i += 6) {
        final batch = list.sublist(i, i + 6 > list.length ? list.length : i + 6);
        await Future.wait(batch.map((h) async {
          var s = TextCleaner.longestRun(words, TextCleaner.words(h.snippet));
          if (s < need) {
            try {
              final page = await TurathApi.getPage(h.bookId, h.pageId);
              final s2 = TextCleaner.longestRun(words, TextCleaner.words(page.text));
              if (s2 > s) s = s2;
            } catch (_) {}
          }
          score[h.key] = s;
        }));
        if (gen != _gen) return;
      }

      final order = {for (var k = 0; k < list.length; k++) list[k].key: k};
      final good = list.where((h) => (score[h.key] ?? 0) >= need).toList()
        ..sort((a, b) {
          final c = (score[b.key] ?? 0).compareTo(score[a.key] ?? 0);
          return c != 0 ? c : order[a.key]!.compareTo(order[b.key]!);
        });
      g.hits = good;
      g.count = good.length;
      g.query = good.isEmpty ? null : foundBy[good.first.key];
    } catch (_) {
      g.error = 'تعذّر الاتصال بالمكتبة، تأكد من الإنترنت ثم أعد المحاولة.';
    }
    if (gen != _gen || !mounted) return;
    setState(() => g.loading = false);
    if (_sort == SortMode.oldest && g.hits.isNotEmpty) {
      await TurathApi.loadDeaths(g.hits.map((h) => h.bookId));
      if (mounted) setState(() {});
    }
  }

  Future<void> _more(_Group g) async {
    if (g.query == null || g.loadingMore) return;
    setState(() => g.loadingMore = true);
    try {
      final r = await TurathApi.search(g.query!,
          page: g.page + 1, bookId: _scope?.bookId, authorId: _scope?.authorId);
      g.page++;
      g.hits.addAll(r.hits);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تحميل المزيد');
    }
    if (mounted) setState(() => g.loadingMore = false);
  }

  Future<void> _pasteAndSearch() async {
    final data = await Clipboard.getData('text/plain');
    final t = data?.text ?? '';
    if (t.trim().isEmpty) {
      if (mounted) showSnack(context, 'الحافظة فارغة');
      return;
    }
    _controller.text = t;
    runSearch();
  }

  void _clear() {
    _gen++;
    setState(() {
      _controller.clear();
      _groups = [];
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) => ListView(
        controller: _scroll,
        padding: EdgeInsets.zero,
        children: [
          PageHeader(
            title: kAppName,
            subtitle: 'الصق النص فيظهر لك مصدره من الكتب المعتمدة',
            icon: Icons.manage_search_rounded,
            bottomPad: 40,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'السجل',
                  icon: const Icon(Icons.history_rounded, color: Colors.white),
                  onPressed: () => HistoryPage.open(context, (q) => runSearch(q)),
                ),
              ],
            ),
          ),
          _inputCard(context),
          if (_clipboardOffer != null) _clipboardCard(context),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_groups.isEmpty && _message == null) ..._idle(context),
          for (var i = 0; i < _groups.length; i++) ..._groupWidgets(context, _groups[i], i),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _inputCard(BuildContext context) {
    final busy = _groups.any((g) => g.loading);
    return Transform.translate(
      offset: const Offset(0, -24),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 7,
              style: bookStyle(context, size: 16),
              decoration: InputDecoration(
                hintText: 'الصق النص هنا… لا بأس بالرموز والإيموجي وسطر المصدر، سأنقّحها وأستخرج النص',
                hintStyle: const TextStyle(fontSize: 13, height: 1.6),
                filled: true,
                fillColor: fieldColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clear,
                ),
              ),
            ),
            if (_scope != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InputChip(
                    avatar: const Icon(Icons.filter_alt_rounded, size: 18),
                    label: Text(_scope!.label, overflow: TextOverflow.ellipsis),
                    onDeleted: () => setState(() => _scope = null),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GradientButton(
                    onTap: busy ? null : () => runSearch(),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: Colors.white),
                              SizedBox(width: 6),
                              Text('ابحث', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: accent(context).withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: busy ? null : _pasteAndSearch,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('لصق وبحث', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    tooltip: 'البحث بالصوت',
                    onPressed: busy ? null : _voice,
                    icon: Icon(Icons.mic_rounded, color: goldText(context)),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : _pickScope,
                icon: Icon(Icons.filter_alt_outlined, size: 18, color: accent(context)),
                label: Text('حصر البحث في كتاب أو عالِم',
                    style: TextStyle(fontSize: 13, color: accent(context))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clipboardCard(BuildContext context) {
    final t = _clipboardOffer!.replaceAll(RegExp(r'\s+'), ' ');
    return AppCard(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_paste_search_rounded, color: kGold),
              const SizedBox(width: 8),
              Text('وجدت نصًّا منسوخًا', style: titleStyle(size: 16, color: accent(context))),
            ],
          ),
          const SizedBox(height: 6),
          Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: bookStyle(context, size: 15)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _clipboardOffer = null),
                child: const Text('تجاهل'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                onPressed: () => runSearch(_clipboardOffer),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('ابحث عنه'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _idle(BuildContext context) {
    final pick = Store.instance.dailyPick();
    Widget tip(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, color: kGold, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(height: 1.6))),
            ],
          ),
        );
    final benefit = DailyBenefit.today();
    return [
      if (Store.instance.recentBooks.isNotEmpty) ...[
        const SectionLabel('تابع القراءة', icon: Icons.auto_stories_rounded),
        _continueCard(context),
      ],
      if (benefit != null) ...[
        const SectionLabel('فائدة اليوم', icon: Icons.wb_sunny_rounded),
        HitCard(hit: benefit, query: ''),
      ],
      const SectionLabel('اقتراحات المطوّر', icon: Icons.menu_book_rounded),
      const UthaymeenBanner(height: 130),
      const SectionLabel('وِرد القراءة', icon: Icons.local_fire_department_rounded),
      const GoalCard(),
      if (pick != null) ...[
        const SectionLabel('من محفوظاتك', icon: Icons.star_rounded),
        HitCard(hit: pick.hit, query: '', item: pick),
      ],
      const SectionLabel('كيف يعمل؟', icon: Icons.lightbulb_rounded),
      AppCard(
        child: Column(
          children: [
            tip(Icons.auto_fix_high_rounded, 'ينقّح النص: يحذف التشكيل والإيموجي والرموز وسطر العنوان والمصدر.'),
            tip(Icons.format_quote_rounded, 'إن كان في النص كلام بين «» يبحث عنه وحده.'),
            tip(Icons.call_split_rounded, 'نصّان أو أكثر بينها سطر فارغ؟ يبحث عن كل نص وحده.'),
            tip(Icons.content_cut_rounded, 'لا يعرض إلا الكتب التي فيها النص أو أكثره بلفظه متتابعًا، لا كلمات متفرقة.'),
            tip(Icons.ios_share_rounded, 'من تيليجرام أو واتساب: «مشاركة» ← «بحث المصادر» فيبحث فورًا.'),
            tip(Icons.edit_note_rounded, 'زر «منشور» يجهّز النص بتنسيق تيليجرام أو واتساب أو صورة.'),
            tip(Icons.mic_rounded, 'زر الميكروفون: اقرأ النص بصوتك فيبحث عنه.'),
            tip(Icons.history_edu_rounded, 'رتّب النتائج «الأقدم أولًا» لتعرف أصل النص ومن نقله أولًا.'),
          ],
        ),
      ),
    ];
  }

  List<Widget> _groupWidgets(BuildContext context, _Group g, int i) {
    final scheme = Theme.of(context).colorScheme;
    final multi = _groups.length > 1;
    final w = <Widget>[];

    final books = g.books;
    w.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          if (multi)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(20)),
              child: Text('النص ${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          Expanded(
            child: Text(
              g.loading
                  ? 'جارٍ البحث والتنقيح…'
                  : g.hits.isEmpty
                      ? 'لا نتائج'
                      : 'النتائج: ${g.count}  •  ${_booksLabel(books.length)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: accent(context)),
            ),
          ),
          if (!g.loading && g.hits.isNotEmpty)
            IconButton(
              tooltip: 'نسخ كل المصادر',
              icon: Icon(Icons.copy_all_rounded, color: accent(context)),
              onPressed: () => copyText(
                context,
                g.visible.map((h) => h.sourceLine).toSet().join('\n'),
                'كل المصادر',
              ),
            ),
        ],
      ),
    ));

    w.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('النص بعد التنقيح', style: TextStyle(fontSize: 13, color: scheme.outline)),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SelectableText(g.passage.cleaned, style: bookStyle(context, size: 15)),
            ),
            if (g.query != null && g.query != g.passage.cleaned)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text('وُجد بالبحث عن: ${g.query}',
                    style: TextStyle(fontSize: 12, color: accent(context))),
              ),
          ],
        ),
      ),
    ));

    if (g.loading) {
      w.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      ));
      return w;
    }
    if (g.error != null) {
      w.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(g.error!, style: TextStyle(color: scheme.error)),
      ));
      return w;
    }
    if (g.hits.isEmpty) {
      final q = g.passage.words.take(10).join(' ');
      w.add(AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لم أجد هذا النص بلفظه في الكتب المعتمدة.', style: TextStyle(fontWeight: FontWeight.bold, color: accent(context))),
            const SizedBox(height: 4),
            Text('جرّب جزءًا أقصر منه، أو تأكد من ألفاظه، أو ابحث عنه في جوجل.',
                style: TextStyle(color: scheme.outline, height: 1.6)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openInApp(
                context,
                Uri.https('www.google.com', '/search', {'q': '"$q"'}),
                title: 'جوجل',
              ),
              icon: const Icon(Icons.public_rounded),
              label: const Text('ابحث في جوجل'),
            ),
          ],
        ),
      ));
      return w;
    }

    if (books.length > 1) {
      w.add(SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: const Text('كل الكتب'),
                selected: g.bookFilter == null,
                onSelected: (_) => setState(() => g.bookFilter = null),
              ),
            ),
            for (final b in books)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(b, overflow: TextOverflow.ellipsis),
                  selected: g.bookFilter == b,
                  onSelected: (_) => setState(() => g.bookFilter = b),
                ),
              ),
          ],
        ),
      ));
    }

    if (i == 0) {
      w.add(SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Icon(Icons.sort_rounded, color: accent(context), size: 20),
            ),
            for (final m in SortMode.values)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(m == SortMode.relevance
                      ? 'الأقرب'
                      : m == SortMode.oldest
                          ? (_loadingDeaths && _sort == m ? 'الأقدم… ⏳' : 'الأقدم أولًا')
                          : 'المفضلة أولًا'),
                  selected: _sort == m,
                  onSelected: (_) => _setSort(m),
                ),
              ),
          ],
        ),
      ));
    }

    final vis = _sorted(g.visible);
    for (var k = 0; k < vis.length; k++) {
      w.add(HitCard(hit: vis[k], query: g.query ?? '', index: k));
    }
    if (g.hits.length < g.count) {
      w.add(Center(
        child: g.loadingMore
            ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: kGreen))
            : TextButton.icon(
                onPressed: () => _more(g),
                icon: Icon(Icons.expand_more_rounded, color: accent(context)),
                label: Text('المزيد من النتائج', style: TextStyle(color: accent(context))),
              ),
      ));
    }
    if (multi && i < _groups.length - 1) {
      w.add(const Divider(indent: 30, endIndent: 30, height: 30));
    }
    return w;
  }
}

String _booksLabel(int n) {
  if (n == 1) return 'في كتاب واحد';
  if (n == 2) return 'في كتابين';
  if (n <= 10) return 'في $n كتب';
  return 'في $n كتابًا';
}

class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GradientButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kGreen, kDeepGreen]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
