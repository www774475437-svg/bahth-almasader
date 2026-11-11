import 'package:flutter/material.dart';

import '../storage.dart';
import '../widgets/common.dart';
import 'book_page.dart';

/// الكتب المفضلة وآخر الكتب المفتوحة
class MyBooksPage extends StatelessWidget {
  const MyBooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final favs = store.favBooks.entries.toList();
        final recent = store.recentBooks;
        final outline = Theme.of(context).colorScheme.outline;

        Widget tile(int id, String name, String author, {bool fav = false}) => AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BookPage(bookId: id, name: name, author: author),
              )),
              child: Row(
                children: [
                  Icon(fav ? Icons.favorite_rounded : Icons.history_edu_rounded,
                      color: fav ? const Color(0xFFE57373) : kGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (author.isNotEmpty) Text(author, style: TextStyle(color: outline, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
            );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: barColor(context),
            foregroundColor: Colors.white,
            title: Text('كتبي', style: titleStyle(size: 18)),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              const SectionLabel('الكتب المفضلة', icon: Icons.favorite_rounded),
              if (favs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text('من قائمة أي نتيجة اختر «كتاب مفضل»، فتظهر نتائجه أولًا عند الترتيب بالمفضلة.',
                      style: TextStyle(color: outline, height: 1.6)),
                )
              else
                for (final f in favs) tile(f.key, f.value, '', fav: true),
              const SectionLabel('آخر الكتب المفتوحة', icon: Icons.history_rounded),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text('ستظهر هنا الكتب التي تفتح صفحاتها.', style: TextStyle(color: outline)),
                )
              else
                for (final r in recent) tile(r.id, r.name, r.author),
            ],
          ),
        );
      },
    );
  }
}
