import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../settings.dart';
import '../telegram.dart';
import '../widgets/common.dart';

class _QuoteTheme {
  final String name;
  final Gradient bg;
  final Color text;
  final Color accent;
  final Color border;
  const _QuoteTheme(this.name, this.bg, this.text, this.accent, this.border);
}

const _themes = [
  _QuoteTheme(
    'زمرّدي',
    LinearGradient(
        colors: [Color(0xFF0F2E26), Color(0xFF1F5E4E)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft),
    Color(0xFFFAF4E4),
    Color(0xFFE2BE55),
    Color(0xFFC9A227),
  ),
  _QuoteTheme(
    'ورقي',
    LinearGradient(
        colors: [Color(0xFFFBF6E9), Color(0xFFF1E6CC)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter),
    Color(0xFF2B2418),
    Color(0xFF1F5E4E),
    Color(0xFFB8952B),
  ),
  _QuoteTheme(
    'ليلي',
    LinearGradient(
        colors: [Color(0xFF0B1220), Color(0xFF1B2638)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter),
    Color(0xFFEDEFF5),
    Color(0xFFE2BE55),
    Color(0xFF8E7A3A),
  ),
  _QuoteTheme(
    'عنّابي',
    LinearGradient(
        colors: [Color(0xFF3B0F1A), Color(0xFF6E1F2E)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft),
    Color(0xFFFFF4E8),
    Color(0xFFF0C674),
    Color(0xFFD4A64A),
  ),
];

/// يصنع صورة جميلة للاقتباس مع المصدر لمشاركتها
class QuoteImagePage extends StatefulWidget {
  final String text;
  final String title;
  final String intro;
  final String source;
  const QuoteImagePage({
    super.key,
    required this.text,
    required this.source,
    this.title = '',
    this.intro = '',
  });

  @override
  State<QuoteImagePage> createState() => _QuoteImagePageState();
}

class _QuoteImagePageState extends State<QuoteImagePage> {
  final _key = GlobalKey();
  int _theme = 0;
  bool _showTitle = true;
  bool _watermark = true;
  double _size = 19;
  bool _busy = false;

  Future<Uint8List> _capture() async {
    final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _publish() async {
    final s = Settings.instance;
    setState(() => _busy = true);
    try {
      final png = await _capture();
      await TelegramBot.sendPhoto(s.botToken, s.channel, png, caption: '> [📓${widget.source}]');
      if (mounted) showSnack(context, 'نُشرت الصورة في القناة ✓');
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر النشر: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final png = await _capture();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر صنع الصورة');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = _themes[_theme];
    final s = Settings.instance;
    final hasTitle = _showTitle && widget.title.isNotEmpty;

    final card = RepaintBoundary(
      key: _key,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: t.bg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          decoration: BoxDecoration(
            border: Border.all(color: t.border, width: 1.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTitle) ...[
                Text(widget.title,
                    textAlign: TextAlign.center,
                    style: safeFont(kQuoteTitleFont, TextStyle(fontSize: 26, color: t.accent, height: 1.6))),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 40, height: 1, color: t.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.auto_awesome, size: 14, color: t.accent),
                    ),
                    Container(width: 40, height: 1, color: t.border),
                  ],
                ),
                const SizedBox(height: 10),
              ] else
                Icon(Icons.format_quote_rounded, size: 34, color: t.accent),
              if (widget.intro.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(widget.intro,
                      textAlign: TextAlign.center,
                      style: safeFont(kTitleFont, TextStyle(fontSize: 15, color: t.accent))),
                ),
              Text(
                widget.text,
                textAlign: TextAlign.center,
                style: safeFont(s.bookFont, TextStyle(fontSize: _size, height: 2.0, color: t.text)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('📓 ${widget.source}',
                    textAlign: TextAlign.center,
                    style: safeFont(kTitleFont, TextStyle(fontSize: 13, color: t.accent))),
              ),
              if (_watermark) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset('assets/icon.png', width: 22, height: 22),
                    ),
                    const SizedBox(width: 6),
                    Text(kAppName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.text.withValues(alpha: 0.7))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('صورة اقتباس', style: titleStyle(size: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: FittedBox(child: card),
            ),
          ),
          const SectionLabel('الشكل', icon: Icons.palette_rounded),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _themes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _theme = i),
                child: Container(
                  width: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _themes[i].bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i == _theme ? kGold : Colors.transparent, width: 3),
                  ),
                  child: Text(_themes[i].name, style: TextStyle(color: _themes[i].text)),
                ),
              ),
            ),
          ),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('حجم الخط'),
                    Expanded(
                      child: Slider(
                        value: _size,
                        min: 14,
                        max: 28,
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                  ],
                ),
                if (widget.title.isNotEmpty)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showTitle,
                    onChanged: (v) => setState(() => _showTitle = v),
                    title: const Text('إظهار العنوان'),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _watermark,
                  onChanged: (v) => setState(() => _watermark = v),
                  title: const Text('شعار التطبيق واسمه أسفل الصورة'),
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
              onPressed: _busy ? null : _share,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share_rounded),
              label: const Text('مشاركة / حفظ الصورة'),
            ),
          ),
          if (Settings.instance.telegramReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF229ED9),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _publish,
                icon: const Icon(Icons.send_rounded),
                label: Text('انشر الصورة في ${Settings.instance.channel}'),
              ),
            ),
        ],
      ),
    );
  }
}
