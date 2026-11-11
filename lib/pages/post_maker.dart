import 'package:flutter/material.dart';

import '../settings.dart';
import '../telegram.dart';
import '../text_cleaner.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import 'quote_image.dart';

enum PostFormat { telegram, whatsapp, plain }

/// صانع المنشور: يجهّز النص والمصدر بتنسيق تيليجرام أو واتساب
class PostMaker extends StatefulWidget {
  final Hit hit;
  final String text;
  const PostMaker({super.key, required this.hit, required this.text});

  @override
  State<PostMaker> createState() => _PostMakerState();
}

class _PostMakerState extends State<PostMaker> {
  late final _title = TextEditingController();
  late final _sayer = TextEditingController();
  late final _text = TextEditingController(text: widget.text.trim());
  PostFormat _format = PostFormat.telegram;
  bool _rahimahu = true;
  bool _noTashkeel = false;
  bool _addLink = false;
  bool _sending = false;
  late String _mark = Settings.instance.closingMark;

  @override
  void dispose() {
    _title.dispose();
    _sayer.dispose();
    _text.dispose();
    super.dispose();
  }

  String get _body {
    var t = _text.text.trim();
    if (_noTashkeel) t = TextCleaner.stripTashkeel(t);
    // نحذف علامات التنصيص إن كانت موجودة لأننا نضيفها
    if (t.startsWith('«')) t = t.substring(1);
    if (t.endsWith('»')) t = t.substring(0, t.length - 1);
    return t.trim();
  }

  String get _intro {
    final s = _sayer.text.trim();
    if (s.isEmpty) return '';
    return _rahimahu ? 'قال $s رَحِمَهُ الله:' : 'قال $s:';
  }

  String get _output {
    final h = widget.hit;
    final quote = '«$_body$_mark»';
    final b = StringBuffer();
    switch (_format) {
      case PostFormat.telegram:
        if (_title.text.trim().isNotEmpty) b.write('📜 ${_title.text.trim()}\n\n');
        if (_intro.isNotEmpty) b.write('▪ $_intro\n\n');
        b.write(quote);
        b.write('\n\n> [📓${h.bookName} (صـ ${h.volPage})]');
        break;
      case PostFormat.whatsapp:
        if (_intro.isNotEmpty) b.write('▪ $_intro\n\n');
        b.write(quote);
        b.write('\n\n[📓${h.bookName} (${h.volPage})]');
        break;
      case PostFormat.plain:
        b.write(quote);
        b.write('\n${h.sourceLine}');
        break;
    }
    if (_addLink) b.write('\n${h.turathUrl}');
    return b.toString();
  }

  Future<void> _publish() async {
    final s = Settings.instance;
    setState(() => _sending = true);
    try {
      await TelegramBot.sendText(s.botToken, s.channel, _output);
      if (mounted) showSnack(context, 'نُشر في القناة ✓');
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر النشر: $e');
    }
    if (mounted) setState(() => _sending = false);
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: fieldColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('صانع المنشور', style: titleStyle(size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SegmentedButton<PostFormat>(
              segments: const [
                ButtonSegment(value: PostFormat.telegram, label: Text('تيليجرام'), icon: Icon(Icons.send_rounded)),
                ButtonSegment(value: PostFormat.whatsapp, label: Text('واتساب'), icon: Icon(Icons.chat_rounded)),
                ButtonSegment(value: PostFormat.plain, label: Text('بسيط'), icon: Icon(Icons.notes_rounded)),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
          ),
          AppCard(
            child: Column(
              children: [
                if (_format == PostFormat.telegram) ...[
                  TextField(
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('العنوان (اختياري)', hint: 'مثل: لا تستخفّ بالبرد!'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_format != PostFormat.plain) ...[
                  TextField(
                    controller: _sayer,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('القائل (اختياري)', hint: 'مثل: ابن القيم'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _rahimahu,
                    onChanged: (v) => setState(() => _rahimahu = v),
                    title: const Text('إضافة «رَحِمَهُ الله» بعد اسم القائل'),
                  ),
                ],
                TextField(
                  controller: _text,
                  onChanged: (_) => setState(() {}),
                  minLines: 4,
                  maxLines: 12,
                  style: bookStyle(context, size: 16),
                  decoration: _dec('النص — احذف منه ما لا تريده'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('علامة الختام:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final m in const ['،.🌿', '،.🪶', '،.', ''])
                            ChoiceChip(
                              label: Text(m.isEmpty ? 'بدون' : m),
                              selected: _mark == m,
                              onSelected: (_) {
                                setState(() => _mark = m);
                                Settings.instance.setClosingMark(m);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _noTashkeel,
                  onChanged: (v) => setState(() => _noTashkeel = v),
                  title: const Text('حذف التشكيل من النص'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _addLink,
                  onChanged: (v) => setState(() => _addLink = v),
                  title: const Text('إضافة رابط الصفحة في تراث'),
                ),
              ],
            ),
          ),
          const SectionLabel('المعاينة', icon: Icons.visibility_rounded),
          AppCard(
            child: SelectableText(_output, style: bookStyle(context, size: 16)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => copyText(context, _output, 'المنشور'),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('نسخ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => shareText(_output),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('مشاركة'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Settings.instance.telegramReady
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF229ED9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _sending ? null : _publish,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text('انشر في ${Settings.instance.channel}'),
                  )
                : Text('لنشر المنشور مباشرة في قناتك، اربطها من تبويب «المزيد» ← النشر في تيليجرام.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: goldText(context),
                side: const BorderSide(color: kGold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuoteImagePage(
                  text: _body,
                  title: _title.text.trim(),
                  intro: _intro,
                  source: '${widget.hit.bookName} (صـ ${widget.hit.volPage})',
                ),
              )),
              icon: const Icon(Icons.image_rounded),
              label: const Text('اصنع صورة اقتباس'),
            ),
          ),
        ],
      ),
    );
  }
}
