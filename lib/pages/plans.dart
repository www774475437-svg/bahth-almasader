import 'package:flutter/material.dart';

import '../daily.dart';
import '../library.dart';
import '../reading.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import 'page_viewer.dart';

/// قائمة الختمات (خطط القراءة)
class PlansSection extends StatelessWidget {
  const PlansSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Reading.instance,
      builder: (context, _) {
        final r = Reading.instance;
        if (r.plans.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 30),
            child: EmptyState(
              icon: Icons.event_note_rounded,
              title: 'لا ختمات بعد',
              subtitle: 'من صفحة أي كتاب اضغط «ختمة»، واختر عدد الأيام،\nفيقسّم الكتاب عليها ويذكّرك بوِرد كل يوم.',
            ),
          );
        }
        final outline = Theme.of(context).colorScheme.outline;
        return Column(
          children: [
            const SizedBox(height: 8),
            for (final p in r.plans)
              Builder(builder: (context) {
                final read = r.of(p.bookId)?.max ?? (p.startPage - 1);
                final done = (read - p.startPage + 1).clamp(0, p.totalPages).toInt();
                final frac = p.totalPages <= 0 ? 0.0 : done / p.totalPages;
                final target = p.targetToday;
                final behind = read < target;
                final day = p.dayIndex + 1;
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_note_rounded, color: kGold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p.bookName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'delete') Reading.instance.removePlan(p);
                            },
                            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف الختمة'))],
                          ),
                        ],
                      ),
                      Text(
                        'اليوم ${day > p.days ? p.days : day} من ${p.days} • ${p.perDay} صفحة يوميًا',
                        style: TextStyle(color: outline, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 8,
                          color: frac >= 1 ? kGreen : kGold,
                          backgroundColor: kGold.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        frac >= 1
                            ? 'أتممت الختمة، بارك الله فيك 🎉'
                            : behind
                                ? 'وِرد اليوم: حتى صفحة $target (أنت عند $read)'
                                : 'أنجزت وِرد اليوم ✓ (عند صفحة $read)',
                        style: TextStyle(color: behind ? goldText(context) : kGreen, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PageViewer(
                            start: Hit(
                              bookId: p.bookId,
                              bookName: p.bookName,
                              authorName: p.author,
                              vol: '',
                              page: 0,
                              pageId: read < p.startPage ? p.startPage : read,
                              snippet: '',
                            ),
                            query: '',
                          ),
                        )),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('أكمل الوِرد'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

/// إنشاء ختمة لكتاب
Future<void> showPlanEditor(BuildContext context,
    {required int bookId, required String name, String author = '', int pageCount = 0}) async {
  var days = 30;
  var total = pageCount;
  var hour = 20;
  var remind = true;
  if (total <= 0) {
    total = Reading.instance.of(bookId)?.total ?? 0;
  }
  if (total <= 0) {
    try {
      total = Library.instance.isDownloaded(bookId)
          ? await Library.instance.offlinePageCount(bookId)
          : (await TurathApi.getBook(bookId, withIndexes: true)).pageCount;
    } catch (_) {}
  }
  if (!context.mounted) return;
  if (total <= 0) {
    showSnack(context, 'تعذّر معرفة عدد صفحات الكتاب');
    return;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: cardColor(context),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final per = (total / days).ceil();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ختمة «$name»', style: titleStyle(size: 18, color: accent(ctx))),
                Text('عدد الصفحات: $total', style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in const [7, 15, 30, 60, 90, 180])
                      ChoiceChip(
                        label: Text('$d يومًا'),
                        selected: days == d,
                        onSelected: (_) => setS(() => days = d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('= $per صفحة كل يوم', style: titleStyle(size: 18, color: goldText(ctx))),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remind,
                  onChanged: (v) => setS(() => remind = v),
                  title: const Text('تذكير يومي بالوِرد'),
                  subtitle: Text('الساعة ${hour.toString().padLeft(2, '0')}:00'),
                ),
                if (remind)
                  Slider(
                    value: hour.toDouble(),
                    min: 4,
                    max: 23,
                    divisions: 19,
                    label: '$hour:00',
                    onChanged: (v) => setS(() => hour = v.round()),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ابدأ الختمة'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (ok != true) return;
  await Reading.instance.addPlan(ReadingPlan(
    id: Library.newId(),
    bookId: bookId,
    bookName: name,
    author: author,
    startPage: 1,
    endPage: total,
    days: days,
    start: DateTime.now(),
  ));
  if (remind) {
    await Daily.requestPermission();
    final now = DateTime.now();
    await Library.instance.saveReminder(Reminder(
      id: Library.newId(),
      title: 'وِرد ختمة «$name» 📖',
      note: '${(total / days).ceil()} صفحة اليوم',
      time: DateTime(now.year, now.month, now.day, hour),
      repeat: Repeat.daily,
      link: 'book:$bookId',
    ));
  }
  if (context.mounted) showSnack(context, 'بدأت الختمة، وفّقك الله 🌿');
}
