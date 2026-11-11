import 'package:flutter/material.dart';

import '../library.dart';
import '../reading.dart';
import '../widgets/translate_share.dart';
import '../widgets/common.dart';
import '../widgets/folder_sheet.dart';
import 'page_viewer.dart';
import 'reminders_page.dart';
import 'plans.dart';

String fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

/// الفواصل الملوّنة
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  bool _edit = false;
  int _seg = 0;

  Future<void> _pickColor(Bookmark b) async {
    final c = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor(context),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final col in kBookmarkColors)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, col),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(col),
                    child: b.color == col ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (c != null) await Library.instance.updateBookmark(b, color: c);
  }

  Future<void> _add() async {
    final lib = Library.instance;
    final name = await askText(context, title: 'فاصل جديد', hint: 'مثل: البنفسجي، أو: درس الفجر');
    if (name == null) return;
    final used = lib.bookmarks.map((b) => b.color).toSet();
    final color = kBookmarkColors.firstWhere((c) => !used.contains(c), orElse: () => kBookmarkColors.first);
    await lib.addBookmark(name, color);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Reading.instance]),
      builder: (context, _) {
        final lib = Library.instance;
        final outline = Theme.of(context).colorScheme.outline;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PageHeader(
              title: 'الفواصل',
              subtitle: 'ضع فاصلًا من صفحة القراءة لتعود إليه',
              icon: Icons.bookmarks_rounded,
              trailing: _seg != 0
                  ? null
                  : TextButton(
                      onPressed: () => setState(() => _edit = !_edit),
                      child: Text(_edit ? 'تم' : 'تعديل', style: const TextStyle(color: kGold, fontSize: 16)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: 0, label: Text('الفواصل'), icon: Icon(Icons.bookmark_rounded)),
                  ButtonSegment(
                      value: 1,
                      label: Text('التمييزات (${Reading.instance.highlights.length})'),
                      icon: const Icon(Icons.border_color_rounded)),
                  const ButtonSegment(value: 2, label: Text('الختمات'), icon: Icon(Icons.event_note_rounded)),
                ],
                selected: {_seg},
                onSelectionChanged: (v) => setState(() => _seg = v.first),
              ),
            ),
            if (_seg == 1) ..._highlights(context),
            if (_seg == 2) const PlansSection(),
            if (_seg == 0) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < lib.bookmarks.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 64, color: outline.withValues(alpha: 0.2)),
                    _tile(lib.bookmarks[i], outline),
                  ],
                ],
              ),
            ),
            if (_edit)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة فاصل'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Text(
                'من صفحة القراءة اضغط 🔖 واختر الفاصل لتنقله إليها. اضغط على أي فاصل لتكمل من حيث توقفت.',
                style: TextStyle(color: outline, height: 1.7, fontSize: 13),
              ),
            ),
            ],
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  List<Widget> _highlights(BuildContext context) {
    final list = Reading.instance.highlights;
    if (list.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 30),
          child: EmptyState(
            icon: Icons.border_color_rounded,
            title: 'لا تمييزات بعد',
            subtitle: 'في صفحة القراءة حدّد نصًّا بالضغط المطوّل،\nثم اختر «تمييز 🖍️».',
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 8),
      for (final h in list)
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PageViewer(start: h.toHit(), query: ''),
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(h.color).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(h.text, maxLines: 6, overflow: TextOverflow.ellipsis, style: bookStyle(context, size: 16)),
              ),
              if (h.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('📝 ${h.note}', style: const TextStyle(height: 1.6)),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text('📓 ${h.bookName} (صـ ${h.volPage})  •  ${fmtDate(h.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                  ),
                  IconButton(
                    tooltip: 'مشاركة',
                    icon: const Icon(Icons.share_rounded, size: 20),
                    onPressed: () => showShareSheet(context, text: h.text, hit: h.toHit()),
                  ),
                  IconButton(
                    tooltip: 'ملاحظة',
                    icon: const Icon(Icons.edit_note_rounded, size: 22),
                    onPressed: () async {
                      final n = await askText(context, title: 'ملاحظة', initial: h.note, maxLines: 3);
                      if (n != null) await Reading.instance.updateHighlight(h, note: n);
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () => Reading.instance.removeHighlight(h),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _tile(Bookmark b, Color outline) {
    final subtitle = b.isSet
        ? '${b.placedAt == null ? '' : '${fmtDate(b.placedAt!)}   '}${b.bookName} (صـ ${b.volPage})'
        : 'لم يُستعمل بعد';
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      leading: GestureDetector(
        onTap: _edit ? () => _pickColor(b) : null,
        child: Icon(b.isSet ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Color(b.color), size: 34),
      ),
      title: Text(b.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: outline)),
      trailing: _edit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'إعادة التسمية',
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: () async {
                    final n = await askText(context, title: 'اسم الفاصل', initial: b.name);
                    if (n != null) await Library.instance.updateBookmark(b, name: n);
                  },
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () => Library.instance.deleteBookmark(b),
                ),
              ],
            )
          : b.isSet
              ? PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'remind') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReminderEditor(
                          initialTitle: 'أكمل القراءة عند الفاصل «${b.name}»',
                          initialNote: '${b.bookName} (صـ ${b.volPage})',
                          link: 'bm:${b.id}',
                        ),
                      ));
                    } else if (v == 'clear') {
                      Library.instance.updateBookmark(b, clear: true);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remind', child: Text('ذكّرني بإكماله ⏰')),
                    PopupMenuItem(value: 'clear', child: Text('إفراغ الفاصل')),
                  ],
                )
              : null,
      onTap: !b.isSet || _edit
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PageViewer(start: b.toHit(), query: ''),
              )),
    );
  }
}
