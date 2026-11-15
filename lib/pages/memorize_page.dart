import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../turath_api.dart';
import '../widgets/common.dart';

class _Matn {
  final int id;
  final String name;
  final int pages;
  const _Matn(this.id, this.name, this.pages);
}

/// حفظ المتون: اختيار متن من الكتب المعتمدة
class MemorizePage extends StatelessWidget {
  const MemorizePage({super.key});

  static const _matns = <_Matn>[
    _Matn(11126, 'ثلاثة الأصول', 12),
    _Matn(8524, 'القواعد الأربع', 4),
    _Matn(12836, 'الأربعون النووية', 81),
    _Matn(30855, 'لمعة الاعتقاد', 39),
    _Matn(18098, 'العقيدة الواسطية', 32),
    _Matn(30850, 'كشف الشبهات', 54),
    _Matn(5940, 'نخبة الفكر', 18),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حفظ المتون')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        children: [
          Text(
            'اختر متنًا، فيعرضه مقطعًا مقطعًا، وتخفي كلماته شيئًا فشيئًا حتى تحفظه.',
            style: TextStyle(fontSize: 14, height: 1.8, color: Theme.of(context).colorScheme.outline),
          ),
          for (final m in _matns)
            AppCard(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Drill(matn: m))),
              child: Row(children: [
                Icon(Icons.psychology_rounded, color: accent(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(m.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_left_rounded),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Drill extends StatefulWidget {
  final _Matn matn;
  const _Drill({required this.matn});

  @override
  State<_Drill> createState() => _DrillState();
}

class _DrillState extends State<_Drill> {
  final List<String> _parts = [];
  int _page = 0;
  int _i = 0;
  double _hide = 0;
  bool _loading = true;
  String? _error;
  bool _reveal = false;
  SharedPreferences? _p;

  String get _key => 'memo_${widget.matn.id}';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {}
    final saved = _p?.getInt(_key) ?? 0;
    await _more(until: saved);
    if (mounted) setState(() => _i = min(saved, max(0, _parts.length - 1)));
  }

  /// يحمّل صفحات المتن حتى يصير عنده مقاطع كافية
  Future<void> _more({int until = 0}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      while (_page < widget.matn.pages && _parts.length <= until + 3) {
        _page++;
        final p = await TurathApi.getPage(widget.matn.id, _page);
        _parts.addAll(_split(p.text));
      }
    } catch (_) {
      _error = 'تعذّر التحميل، تأكد من الإنترنت.';
    }
    if (mounted) setState(() => _loading = false);
  }

  static List<String> _split(String text) {
    final cut = text.indexOf('____');
    final body = cut > 0 ? text.substring(0, cut) : text;
    final out = <String>[];
    for (final para in body.split(RegExp(r'\n+'))) {
      final t = para.trim();
      if (t.length < 15) continue;
      final words = t.split(RegExp(r'\s+'));
      var buf = <String>[];
      for (final w in words) {
        buf.add(w);
        final end = RegExp(r'[.؛:؟!،]$').hasMatch(w);
        if ((buf.length >= 12 && end) || buf.length >= 22) {
          out.add(buf.join(' '));
          buf = [];
        }
      }
      if (buf.isNotEmpty) out.add(buf.join(' '));
    }
    return out;
  }

  void _go(int d) {
    final n = _i + d;
    if (n < 0) return;
    if (n >= _parts.length) {
      if (_page < widget.matn.pages) _more(until: n).then((_) => _go(0));
      return;
    }
    setState(() {
      _i = n;
      _reveal = false;
    });
    try {
      _p?.setInt(_key, _i);
    } catch (_) {}
  }

  String _masked(String s) {
    if (_reveal || _hide <= 0) return s;
    final words = s.split(' ');
    final rnd = Random(_i * 7919 + widget.matn.id);
    final order = List<int>.generate(words.length, (k) => k)..shuffle(rnd);
    final n = (words.length * _hide).round();
    final hidden = order.take(n).toSet();
    return [for (var k = 0; k < words.length; k++) hidden.contains(k) ? '•' * min(6, words[k].length) : words[k]]
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final has = _parts.isNotEmpty && _i < _parts.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.matn.name)),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (has)
              Text('المقطع ${_i + 1}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(18),
                onTap: has ? () => setState(() => _reveal = !_reveal) : null,
                child: Center(
                  child: _loading && !has
                      ? const CircularProgressIndicator()
                      : has
                          ? SingleChildScrollView(
                              child: Text(_masked(_parts[_i]),
                                  textAlign: TextAlign.center, style: bookStyle(context, size: 22)),
                            )
                          : Text(_error ?? 'لا يوجد نص'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Text('إخفاء الكلمات'),
              Expanded(
                child: Slider(
                  value: _hide,
                  divisions: 4,
                  label: '${(_hide * 100).round()}٪',
                  onChanged: (v) => setState(() => _hide = v),
                ),
              ),
            ]),
            Text('اضغط على النص لإظهاره كاملًا', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _i > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السابق'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _go(1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('التالي'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
