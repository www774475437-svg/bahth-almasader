import 'package:flutter/material.dart';

import '../export.dart';
import '../storage.dart';
import '../text_cleaner.dart';
import '../widgets/common.dart';
import '../widgets/folder_sheet.dart';
import '../widgets/hit_card.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  String _filter = '';

  /// null = الكل، '' = بدون مجلد، غير ذلك = اسم المجلد
  String? _folder;

  List<SavedItem> _items() {
    final f = TextCleaner.normalize(_filter);
    return Store.instance.saved.where((s) {
      if (_folder != null && s.folder != _folder) return false;
      if (f.isEmpty) return true;
      final hay = TextCleaner.normalize('${s.hit.bookName} ${s.hit.authorName} ${s.hit.snippet} ${s.note}');
      return hay.contains(f);
    }).toList();
  }

  Future<void> _export(String kind) async {
    if (kind == 'import') {
      try {
        final n = await importFromFile();
        if (n != null && mounted) showSnack(context, 'أُضيفت $n فائدة ✓');
      } catch (_) {
        if (mounted) showSnack(context, 'الملف غير صالح');
      }
      return;
    }
    if (kind == 'folder') {
      try {
        await shareFolderFile(_folder);
      } catch (_) {
        if (mounted) showSnack(context, 'تعذّرت المشاركة');
      }
      return;
    }
    final items = _items();
    if (items.isEmpty) {
      showSnack(context, 'لا توجد محفوظات لتصديرها');
      return;
    }
    try {
      if (kind == 'pdf') {
        await exportPdf(items);
      } else if (kind == 'txt') {
        await exportText(items);
      } else {
        if (mounted) await copyText(context, savedAsText(items), 'المحفوظات');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر التصدير');
    }
  }

  Future<void> _folderMenu(String name) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: titleStyle(size: 18, color: accent(ctx))),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('إعادة التسمية'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('حذف المجلد (تبقى الفوائد في «بدون مجلد»)'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final n = await askText(context, title: 'اسم جديد للمجلد', initial: name);
      if (n != null && n.trim().isNotEmpty) {
        await Store.instance.renameFolder(name, n);
        if (_folder == name) setState(() => _folder = n.trim());
      }
    } else if (action == 'delete') {
      await Store.instance.deleteFolder(name);
      if (_folder == name) setState(() => _folder = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final all = store.saved;
        final items = _items();

        Widget chip(String label, String? value, {IconData? icon, VoidCallback? onLong}) {
          final count = value == null ? all.length : all.where((s) => s.folder == value).length;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onLongPress: onLong,
              child: ChoiceChip(
                avatar: icon == null ? null : Icon(icon, size: 16),
                label: Text('$label ($count)'),
                selected: _folder == value,
                onSelected: (_) => setState(() => _folder = value),
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PageHeader(
              title: 'المحفوظات',
              subtitle: all.isEmpty ? 'الفوائد التي تميّزها بالنجمة' : 'عددها: ${all.length}',
              icon: Icons.star_rounded,
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'تصدير ومشاركة',
                onSelected: _export,
                itemBuilder: (_) => [
                  if (all.isNotEmpty) ...[
                    const PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
                    const PopupMenuItem(value: 'txt', child: Text('تصدير ملف نصي')),
                    const PopupMenuItem(value: 'copy', child: Text('نسخ الكل')),
                    PopupMenuItem(
                      value: 'folder',
                      child: Text(_folder == null || _folder!.isEmpty
                          ? 'مشاركة المحفوظات مع صديق'
                          : 'مشاركة مجلد «${_folder!}» مع صديق'),
                    ),
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(value: 'import', child: Text('استيراد ملف فوائد')),
                ],
              ),
            ),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.star_outline_rounded,
                  title: 'لا توجد محفوظات بعد',
                  subtitle: 'اضغط ☆ على أي نتيجة بحث لحفظها هنا،\nورتّبها في مجلدات.',
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث في المحفوظات والملاحظات…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: cardColor(context),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  children: [
                    chip('الكل', null, icon: Icons.all_inbox_rounded),
                    for (final f in store.folders)
                      chip(f, f, icon: Icons.folder_rounded, onLong: () => _folderMenu(f)),
                    chip('بدون مجلد', '', icon: Icons.inbox_rounded),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('مجلد'),
                        onPressed: () async {
                          final n = await askText(context, title: 'مجلد جديد', hint: 'مثل: فوائد لغوية');
                          if (n != null) await store.addFolder(n);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Text('اضغط مطوّلًا على مجلد لإعادة تسميته أو حذفه',
                    style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.outline)),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: EmptyState(
                      icon: Icons.search_off_rounded, title: 'لا شيء هنا', subtitle: 'لا توجد فوائد مطابقة.'),
                )
              else
                for (var k = 0; k < items.length; k++)
                  HitCard(hit: items[k].hit, query: items[k].query, item: items[k], index: k),
            ],
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}
