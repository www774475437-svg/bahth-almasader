import 'package:flutter/material.dart';

import '../daily.dart';
import '../library.dart';
import '../widgets/common.dart';

const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String _two(int n) => n.toString().padLeft(2, '0');

String reminderWhen(Reminder r) {
  final t = '${_two(r.time.hour)}:${_two(r.time.minute)}';
  switch (r.repeat) {
    case Repeat.once:
      return '${r.time.year}/${r.time.month}/${r.time.day} — $t';
    case Repeat.daily:
      return 'كل يوم — $t';
    case Repeat.weekly:
      return 'كل ${_weekdays[r.time.weekday - 1]} — $t';
  }
}

/// قائمة التذكيرات
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('التذكيرات', style: titleStyle(size: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGold,
        foregroundColor: kDeepGreen,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderEditor())),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('تذكير جديد'),
      ),
      body: ListenableBuilder(
        listenable: Library.instance,
        builder: (context, _) {
          final list = Library.instance.reminders;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.alarm_rounded,
              title: 'لا تذكيرات بعد',
              subtitle: 'أنشئ تذكيرًا لإكمال كتاب أو فاصل،\nأو لمراجعة محفوظاتك.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 90),
            children: [
              for (final r in list)
                AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ReminderEditor(existing: r))),
                  child: Row(
                    children: [
                      Icon(Icons.alarm_rounded, color: r.enabled ? kGold : Theme.of(context).disabledColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                            Text(reminderWhen(r),
                                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5)),
                            if (r.note.isNotEmpty)
                              Text(r.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Switch(
                        value: r.enabled,
                        onChanged: (v) => Library.instance.toggleReminder(r, v),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// إنشاء تذكير أو تعديله
class ReminderEditor extends StatefulWidget {
  final Reminder? existing;
  final String initialTitle;
  final String initialNote;
  final String link;
  const ReminderEditor({
    super.key,
    this.existing,
    this.initialTitle = '',
    this.initialNote = '',
    this.link = '',
  });

  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? widget.initialTitle);
  late final _note = TextEditingController(text: widget.existing?.note ?? widget.initialNote);
  late DateTime _time = widget.existing?.time ??
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1, 20, 0);
  late Repeat _repeat = widget.existing?.repeat ?? Repeat.once;

  static const _templates = [
    'أكمل قراءة الكتاب 📖',
    'أكمل القراءة عند الفاصل 🔖',
    'راجع محفوظاتك ⭐',
    'ورد القراءة اليومي',
    'حضّر منشور القناة ✍️',
  ];

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _time.isBefore(DateTime.now()) ? DateTime.now() : _time,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d != null) setState(() => _time = DateTime(d.year, d.month, d.day, _time.hour, _time.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute));
    if (t != null) setState(() => _time = DateTime(_time.year, _time.month, _time.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'اكتب عنوان التذكير');
      return;
    }
    if (_repeat == Repeat.once && !_time.isAfter(DateTime.now())) {
      showSnack(context, 'اختر وقتًا في المستقبل');
      return;
    }
    await Daily.requestPermission();
    final lib = Library.instance;
    final r = widget.existing ??
        Reminder(id: Library.newId(), title: title, time: _time, link: widget.link);
    r.title = title;
    r.note = _note.text.trim();
    r.time = _time;
    r.repeat = _repeat;
    r.enabled = true;
    await lib.saveReminder(r);
    if (mounted) {
      showSnack(context, 'حُفظ التذكير ⏰');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l) => InputDecoration(
          labelText: l,
          filled: true,
          fillColor: fieldColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text(widget.existing == null ? 'تذكير جديد' : 'تعديل التذكير', style: titleStyle(size: 18)),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await Library.instance.deleteReminder(widget.existing!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          AppCard(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _title, decoration: dec('العنوان')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _templates)
                      ActionChip(label: Text(t), onPressed: () => setState(() => _title.text = t)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _note, maxLines: 3, decoration: dec('ملاحظة (اختياري)')),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Repeat>(
                    segments: const [
                      ButtonSegment(value: Repeat.once, label: Text('مرة')),
                      ButtonSegment(value: Repeat.daily, label: Text('يوميًا')),
                      ButtonSegment(value: Repeat.weekly, label: Text('أسبوعيًا')),
                    ],
                    selected: {_repeat},
                    onSelectionChanged: (v) => setState(() => _repeat = v.first),
                  ),
                ),
                const SizedBox(height: 8),
                if (_repeat != Repeat.daily)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded, color: kGold),
                    title: Text(_repeat == Repeat.weekly
                        ? 'اليوم: ${_weekdays[_time.weekday - 1]}'
                        : 'التاريخ: ${_time.year}/${_time.month}/${_time.day}'),
                    onTap: _pickDate,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded, color: kGold),
                  title: Text('الوقت: ${_two(_time.hour)}:${_two(_time.minute)}'),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kGreen,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('حفظ التذكير'),
            ),
          ),
        ],
      ),
    );
  }
}
