import 'package:flutter/material.dart';

import '../storage.dart';
import '../widgets/common.dart';

/// إحصائيات المحفوظات
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  List<MapEntry<String, int>> _top(Iterable<String> values, int n) {
    final m = <String, int>{};
    for (final v in values) {
      if (v.trim().isEmpty) continue;
      m[v] = (m[v] ?? 0) + 1;
    }
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final saved = store.saved;
    final now = DateTime.now();
    final thisMonth = saved.where((s) => s.savedAt.year == now.year && s.savedAt.month == now.month).length;
    final books = saved.map((s) => s.hit.bookName).toSet().length;
    final authors = saved.map((s) => s.hit.authorName).where((a) => a.isNotEmpty).toSet().length;
    final topBooks = _top(saved.map((s) => s.hit.bookName), 5);
    final topAuthors = _top(saved.map((s) => s.hit.authorName), 5);
    final topFolders = _top(saved.map((s) => s.folder), 5);

    Widget stat(IconData icon, String label, int value) => Expanded(
          child: AppCard(
            margin: const EdgeInsets.all(5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: kGold, size: 26),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, v, __) => Text('${v.round()}', style: titleStyle(size: 26, color: accent(context))),
                ),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        );

    Widget bars(String title, IconData icon, List<MapEntry<String, int>> data) {
      if (data.isEmpty) return const SizedBox.shrink();
      final max = data.first.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title, icon: icon),
          AppCard(
            child: Column(
              children: [
                for (final e in data)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${e.value}', style: TextStyle(fontWeight: FontWeight.bold, color: goldText(context))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: e.value / max,
                            minHeight: 7,
                            color: kGreen,
                            backgroundColor: kGreen.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('إحصائياتي', style: titleStyle(size: 18)),
      ),
      body: saved.isEmpty
          ? const EmptyState(
              icon: Icons.insights_rounded, title: 'لا إحصائيات بعد', subtitle: 'احفظ بعض الفوائد بالنجمة لتظهر هنا.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 30),
              children: [
                Row(children: [
                  stat(Icons.star_rounded, 'فائدة محفوظة', saved.length),
                  stat(Icons.calendar_month_rounded, 'هذا الشهر', thisMonth),
                ]),
                Row(children: [
                  stat(Icons.menu_book_rounded, 'كتابًا', books),
                  stat(Icons.person_rounded, 'مؤلفًا', authors),
                  stat(Icons.search_rounded, 'بحثًا', store.history.length),
                ]),
                bars('أكثر الكتب في محفوظاتك', Icons.menu_book_rounded, topBooks),
                bars('أكثر المؤلفين', Icons.person_rounded, topAuthors),
                bars('المجلدات', Icons.folder_rounded, topFolders),
              ],
            ),
    );
  }
}
