import 'package:flutter/material.dart';

import '../storage.dart';
import 'common.dart';

Future<String?> askText(BuildContext context,
    {required String title, String initial = '', String hint = '', int maxLines = 1}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

/// اختيار مجلد لعنصر محفوظ
Future<void> showFolderSheet(BuildContext context, SavedItem item) async {
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: cardColor(context),
    builder: (ctx) => ListenableBuilder(
      listenable: Store.instance,
      builder: (ctx, _) {
        final store = Store.instance;
        Widget tile(String name, String label, IconData icon) => ListTile(
              leading: Icon(icon, color: kGold),
              title: Text(label),
              trailing: item.folder == name ? const Icon(Icons.check_rounded, color: kGreen) : null,
              onTap: () {
                store.setFolder(item, name);
                Navigator.pop(ctx);
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('اختر مجلدًا', style: titleStyle(size: 18, color: accent(ctx))),
                const SizedBox(height: 6),
                tile('', 'بدون مجلد', Icons.inbox_rounded),
                for (final f in store.folders) tile(f, f, Icons.folder_rounded),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_rounded, color: kGreen),
                  title: const Text('مجلد جديد'),
                  onTap: () async {
                    final name = await askText(ctx, title: 'اسم المجلد الجديد', hint: 'مثل: فوائد لغوية');
                    if (name != null && name.trim().isNotEmpty) {
                      await store.addFolder(name);
                      await store.setFolder(item, name.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showNoteDialog(BuildContext context, SavedItem item) async {
  final t = await askText(context,
      title: 'ملاحظة', initial: item.note, hint: 'اكتب ملاحظتك على هذه الفائدة', maxLines: 4);
  if (t != null) await Store.instance.setNote(item, t);
}
