import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/author_page.dart';
import '../pages/book_page.dart';
import '../pages/page_viewer.dart';
import '../pages/post_maker.dart';
import '../storage.dart';
import '../turath_api.dart';
import 'common.dart';
import 'folder_sheet.dart';
import 'translate_share.dart';

/// بطاقة نتيجة: الكتاب، المؤلف، الجزء والصفحة، النص، والأزرار
class HitCard extends StatelessWidget {
  final Hit hit;
  final String query;
  final SavedItem? item;
  final int index;

  const HitCard({super.key, required this.hit, required this.query, this.item, this.index = 0});

  void _openPage(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageViewer(start: hit, query: query)));
  }

  Future<void> _toggleStar(BuildContext context) async {
    HapticFeedback.selectionClick();
    final now = await Store.instance.toggleSave(hit, query);
    if (!context.mounted) return;
    if (now) {
      showSnack(context, 'حُفظ في المحفوظات ⭐', action: 'اختر مجلدًا', onAction: () {
        final s = Store.instance.find(hit);
        if (s != null) showFolderSheet(context, s);
      });
    } else {
      showSnack(context, 'أُزيل من المحفوظات');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = keysOf(query);
    final it = item;

    final card = AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
      onTap: () => _openPage(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kDeepGreen, kGreen]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.menu_book_rounded, color: kGold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.bookName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, color: accent(context), height: 1.4)),
                    if (hit.authorName.isNotEmpty)
                      Text(hit.authorName, style: TextStyle(color: scheme.outline, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ترجمة',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.translate_rounded, color: scheme.outline, size: 22),
                onPressed: () => showTranslateSheet(context, hit.snippet),
              ),
              IconButton(
                tooltip: 'مشاركة',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.share_rounded, color: scheme.outline, size: 22),
                onPressed: () => showShareSheet(context, text: hit.snippet, hit: hit),
              ),
              ListenableBuilder(
                listenable: Store.instance,
                builder: (context, _) {
                  final saved = Store.instance.isSaved(hit);
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: saved ? 'إزالة من المحفوظات' : 'حفظ',
                    onPressed: () => _toggleStar(context),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(
                        saved ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(saved),
                        color: saved ? kGold : scheme.outline,
                        size: 29,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              PagePill('صـ ${hit.volPage}'),
              if (TurathApi.deathByBook[hit.bookId] != null)
                PagePill('ت ${TurathApi.deathByBook[hit.bookId]} هـ'),
              if (Store.instance.isFavBook(hit.bookId))
                const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFE57373)),
              if (it != null && it.folder.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_rounded, size: 14, color: accent(context)),
                      const SizedBox(width: 4),
                      Text(it.folder, style: TextStyle(fontSize: 12.5, color: accent(context))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text.rich(
              highlighted(hit.snippet, keys, bookStyle(context, size: 16.5), isDark(context) ? kGold : kGreen),
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (it != null && it.note.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6, left: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGold.withValues(alpha: 0.45)),
              ),
              child: Text('📝 ${it.note}', style: const TextStyle(height: 1.6)),
            ),
          const Divider(height: 14),
          Row(
            children: [
              _Action(icon: Icons.auto_stories_rounded, label: 'الصفحة', onTap: () => _openPage(context)),
              _Action(
                icon: Icons.edit_note_rounded,
                label: 'منشور',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostMaker(hit: hit, text: hit.snippet),
                )),
              ),
              _Action(icon: Icons.content_copy_rounded, label: 'المصدر',
                  onTap: () => copyText(context, hit.sourceLine, 'المصدر')),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: scheme.outline),
                onSelected: (v) async {
                  switch (v) {
                    case 'share':
                      shareText('«${hit.snippet}»\n${hit.sourceLine}');
                      break;
                    case 'book':
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BookPage(bookId: hit.bookId, name: hit.bookName, author: hit.authorName),
                      ));
                      break;
                    case 'author':
                      var aid = hit.authorId;
                      if (aid == 0) {
                        try {
                          aid = (await TurathApi.getBook(hit.bookId)).authorId;
                        } catch (_) {}
                      }
                      if (!context.mounted) return;
                      if (aid == 0) {
                        showSnack(context, 'تعذّر جلب بيانات المؤلف');
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AuthorPage(authorId: aid, name: hit.authorName),
                        ));
                      }
                      break;
                    case 'fav':
                      final now = await Store.instance.toggleFavBook(hit.bookId, hit.bookName);
                      if (context.mounted) {
                        showSnack(context, now ? 'أُضيف «${hit.bookName}» إلى الكتب المفضلة ❤️' : 'أُزيل من المفضلة');
                      }
                      break;
                    case 'folder':
                      if (it != null) showFolderSheet(context, it);
                      break;
                    case 'note':
                      if (it != null) showNoteDialog(context, it);
                      break;
                    case 'delete':
                      if (it != null) Store.instance.remove(it);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'book', child: Text('عن الكتاب وفهرسه')),
                  const PopupMenuItem(value: 'author', child: Text('عن المؤلف')),
                  PopupMenuItem(
                      value: 'fav',
                      child: Text(Store.instance.isFavBook(hit.bookId) ? 'إزالة الكتاب من المفضلة' : 'كتاب مفضل ❤️')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'share', child: Text('مشاركة النص والمصدر')),
                  if (it != null) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'folder', child: Text('نقل إلى مجلد')),
                    PopupMenuItem(value: 'note', child: Text(it.note.isEmpty ? 'إضافة ملاحظة' : 'تعديل الملاحظة')),
                    const PopupMenuItem(value: 'delete', child: Text('حذف من المحفوظات')),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // ظهور ناعم للبطاقة
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index < 6 ? index : 6) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: card,
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: accent(context)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: accent(context))),
          ],
        ),
      ),
    );
  }
}
