import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../approved.dart';
import '../widgets/common.dart';
import 'book_page.dart';

class _Step {
  final int id;
  final String title;
  const _Step(this.id, this.title);
}

class _Track {
  final String name;
  final IconData icon;
  final List<_Step> steps;
  const _Track(this.name, this.icon, this.steps);
}

/// «ابدأ هنا»: منهج قراءة مرتّب لطالب العلم من الكتب المعتمدة
class StudyPathPage extends StatefulWidget {
  const StudyPathPage({super.key});

  @override
  State<StudyPathPage> createState() => _StudyPathPageState();
}

class _StudyPathPageState extends State<StudyPathPage> {
  static const _tracks = <_Track>[
    _Track('العقيدة', Icons.shield_moon_rounded, [
      _Step(239, 'ثلاثة الأصول والقواعد الأربع'),
      _Step(11257, 'شرح ثلاثة الأصول — ابن عثيمين'),
      _Step(30850, 'كشف الشبهات'),
      _Step(9923, 'شرح كشف الشبهات — ابن عثيمين'),
      _Step(7339, 'القول المفيد على كتاب التوحيد — ابن عثيمين'),
      _Step(30855, 'لمعة الاعتقاد — ابن قدامة'),
      _Step(11366, 'تعليق مختصر على لمعة الاعتقاد — ابن عثيمين'),
      _Step(18098, 'العقيدة الواسطية — ابن تيمية'),
      _Step(11250, 'شرح العقيدة الواسطية — ابن عثيمين'),
      _Step(21817, 'فتح رب البرية بتلخيص الحموية — ابن عثيمين'),
      _Step(11100, 'تقريب التدمرية — ابن عثيمين'),
      _Step(8352, 'شرح العقيدة الطحاوية — ابن أبي العز'),
    ]),
    _Track('التفسير وعلوم القرآن', Icons.auto_stories_rounded, [
      _Step(12081, 'مقدمة في أصول التفسير — ابن تيمية'),
      _Step(42, 'تفسير السعدي'),
    ]),
    _Track('الحديث والمصطلح', Icons.format_quote_rounded, [
      _Step(12836, 'الأربعون النووية'),
      _Step(21812, 'شرح الأربعين النووية — ابن عثيمين'),
      _Step(11254, 'شرح المنظومة البيقونية — ابن عثيمين'),
      _Step(5940, 'نخبة الفكر — ابن حجر'),
      _Step(9260, 'شرح رياض الصالحين — ابن عثيمين'),
      _Step(9111, 'بلوغ المرام — ابن حجر'),
    ]),
    _Track('الفقه وأصوله', Icons.balance_rounded, [
      _Step(31246, 'آداب المشي إلى الصلاة'),
      _Step(9942, 'الأصول من علم الأصول — ابن عثيمين'),
      _Step(10649, 'الشرح الممتع على زاد المستقنع — ابن عثيمين'),
    ]),
    _Track('الآداب والسلوك', Icons.spa_rounded, [
      _Step(9884, 'حلية طالب العلم — بكر أبو زيد'),
    ]),
  ];

  Set<int> _done = {};
  SharedPreferences? _p;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _p = await SharedPreferences.getInstance();
      final l = _p!.getStringList('studyDone') ?? const [];
      if (mounted) setState(() => _done = l.map(int.tryParse).whereType<int>().toSet());
    } catch (_) {}
  }

  void _toggle(int id) {
    setState(() => _done.contains(id) ? _done.remove(id) : _done.add(id));
    try {
      _p?.setStringList('studyDone', _done.map((e) => '$e').toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ap = Approved.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('ابدأ هنا')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        children: [
          Text(
            'منهج مرتّب لطالب العلم في كل فن، يبدأ بالمتن المختصر ثم شرحه. علّم ما أتممته بالدائرة.',
            style: TextStyle(fontSize: 14, height: 1.8, color: Theme.of(context).colorScheme.outline),
          ),
          for (final t in _tracks) ...[
            Builder(builder: (context) {
              final steps = t.steps.where((s) => ap.books.any((b) => b.id == s.id)).toList();
              final done = steps.where((s) => _done.contains(s.id)).length;
              return AppCard(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(t.icon, color: accent(context)),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('$done من ${steps.length}'),
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        ListTile(
                          leading: IconButton(
                            icon: Icon(
                              _done.contains(steps[i].id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: _done.contains(steps[i].id) ? kGold : null,
                            ),
                            onPressed: () => _toggle(steps[i].id),
                          ),
                          title: Text('${i + 1}. ${steps[i].title}', style: const TextStyle(height: 1.5)),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BookPage(bookId: steps[i].id, name: steps[i].title),
                          )),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
