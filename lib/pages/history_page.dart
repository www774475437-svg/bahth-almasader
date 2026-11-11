import 'package:flutter/material.dart';

import '../storage.dart';
import '../widgets/common.dart';

class HistoryPage extends StatelessWidget {
  final ValueChanged<String> onPick;
  const HistoryPage({super.key, required this.onPick});

  /// فتح السجل كصفحة مستقلة
  static void open(BuildContext context, ValueChanged<String> onPick) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        body: HistoryPage(onPick: (q) {
          Navigator.of(ctx).pop();
          onPick(q);
        }),
      ),
    ));
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مسح السجل'),
        content: const Text('هل تريد مسح كل عمليات البحث السابقة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (ok == true) await Store.instance.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final h = Store.instance.history;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PageHeader(
              title: 'السجل',
              subtitle: h.isEmpty ? 'النصوص التي تبحث عنها' : 'آخر ${h.length} بحث',
              icon: Icons.history_rounded,
              trailing: h.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح السجل',
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                      onPressed: () => _confirmClear(context),
                    ),
            ),
            const SizedBox(height: 8),
            if (h.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'السجل فارغ',
                  subtitle: 'ستظهر هنا النصوص التي تبحث عنها،\nواضغط على أي واحد منها لإعادة البحث.',
                ),
              )
            else
              for (final q in h)
                Dismissible(
                  key: ValueKey(q),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => Store.instance.removeHistory(q),
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.red.withValues(alpha: 0.12),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  child: AppCard(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    onTap: () => onPick(q),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: kGold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.replaceAll(RegExp(r'\s+'), ' '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: bookStyle(context, size: 15),
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Store.instance.removeHistory(q),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}
