import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// المساعد الذكي: الأدوات جاهزة الشكل، والذكاء الاصطناعي يُضاف لاحقًا بإذن الله
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  static const dailyLimit = 20;

  static const _tools = <_Tool>[
    _Tool(Icons.question_answer_rounded, 'اسأل الكتب المعتمدة',
        'اكتب سؤالك في العقيدة أو الفقه أو التفسير أو الحديث، فيجيبك من كلام ابن عثيمين، فإن لم يجد فمن ابن باز، ثم من بعده من العلماء المعتمدين، وتحت كل قول اسم الكتاب والصفحة.'),
    _Tool(Icons.translate_rounded, 'شرح الكلمة (اللغة والنحو)',
        'اضغط على كلمة صعبة في صفحة الكتاب، فيشرح معناها وإعرابها من كتب اللغة والغريب.'),
    _Tool(Icons.verified_rounded, 'تخريج الحديث',
        'الصق حديثًا فيخبرك بمن أخرجه ودرجته (صحيح أو ضعيف) مع اسم الكتاب ورقم الحديث والعالِم الذي حكم عليه، ورابط للتحقق.'),
    _Tool(Icons.summarize_rounded, 'لخّص لي',
        'افتح صفحة أو بابًا من كتاب، فيعطيك خلاصته في نقاط، من الكتاب نفسه.'),
    _Tool(Icons.g_translate_rounded, 'ترجمة الفائدة',
        'يترجم الفائدة إلى الإنجليزية وغيرها لنشرها لغير العرب، مع بقاء المصدر.'),
    _Tool(Icons.edit_note_rounded, 'صياغة المنشور',
        'يكتب لك منشورًا جاهزًا من الفائدة بأسلوب قناتك: العنوان بـ🔖 والنص بين «» والمصدر، وفي آخره ،.🌿'),
    _Tool(Icons.quiz_rounded, 'اختبرني',
        'بعد أن تُتمّ كتابًا يسألك أسئلة من الكتاب نفسه فقط، ومع كل سؤال الصفحة التي أُخذ منها.'),
    _Tool(Icons.menu_book_rounded, 'اقترح لي كتابًا',
        'يسألك عن مستواك وما تريد تعلمه، فيقترح لك كتبًا من المعتمدة بالترتيب الذي يرتّبه العلماء لطالب العلم.'),
    _Tool(Icons.calculate_rounded, 'حاسبة المواريث',
        'أدخل الورثة فيقسم التركة على كتب الفرائض، مع ذكر الأدلة.'),
  ];

  void _soon(BuildContext context, _Tool t) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(t.icon, color: accent(context), size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(t.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 12),
              Text(t.desc, style: const TextStyle(fontSize: 15, height: 1.8)),
              const SizedBox(height: 16),
              const _SoonBadge(big: true),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعد الذكي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome_motion_rounded, color: accent(context), size: 30),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('مساعد من كتب أهل العلم المعتمدين فقط',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.5)),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'يبدأ بكلام ابن عثيمين، ثم ابن باز، ثم بقية العلماء المعتمدين، ومع كل قول المصدر والصفحة. '
                  'ولا يجيب إلا عن المسائل الشرعية وما يتصل بها من اللغة والنحو والفرائض.',
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'اكتب سؤالك هنا…',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    suffixIcon: const Icon(Icons.send_rounded),
                    filled: true,
                    fillColor: fieldColor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const _SoonBadge(),
                  const Spacer(),
                  Text('$dailyLimit سؤالًا في اليوم',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                ]),
              ],
            ),
          ),
          const SectionLabel('الأدوات', icon: Icons.grid_view_rounded),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              for (final t in _tools)
                AppCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  onTap: () => _soon(context, t),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, color: accent(context), size: 30),
                      const SizedBox(height: 8),
                      Text(t.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                      const SizedBox(height: 6),
                      const _SoonBadge(),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'سؤال خارج العلم الشرعي يُرَدّ عليه: «هذا المساعد مخصّص للمسائل الشرعية من كتب أهل العلم فقط».',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.7, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String title;
  final String desc;
  const _Tool(this.icon, this.title, this.desc);
}

class _SoonBadge extends StatelessWidget {
  final bool big;
  const _SoonBadge({this.big = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 8, vertical: big ? 6 : 2),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('سيُضاف لاحقًا بإذن الله',
          style: TextStyle(fontSize: big ? 14 : 10.5, fontWeight: FontWeight.bold, color: goldText(context))),
    );
  }
}
