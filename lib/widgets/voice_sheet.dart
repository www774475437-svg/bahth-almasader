import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'common.dart';

/// البحث بالصوت: يرجع النص المسموع أو null
Future<String?> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: cardColor(context),
    isScrollControlled: true,
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  String _words = '';
  String _status = 'جارٍ التجهيز…';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') setState(() => _listening = false);
        },
        onError: (e) {
          if (mounted) setState(() => _status = 'لم أسمع جيدًا، اضغط الميكروفون وحاول مرة أخرى');
        },
      );
      if (!ok) {
        if (mounted) setState(() => _status = 'التعرّف على الصوت غير متاح في هذا الجوال');
        return;
      }
      await _listen();
    } catch (_) {
      if (mounted) setState(() => _status = 'التعرّف على الصوت غير متاح');
    }
  }

  Future<String> _arabicLocale() async {
    try {
      final locales = await _speech.locales();
      for (final pref in ['ar_SA', 'ar-SA', 'ar_EG', 'ar-EG']) {
        for (final l in locales) {
          if (l.localeId == pref) return l.localeId;
        }
      }
      for (final l in locales) {
        if (l.localeId.startsWith('ar')) return l.localeId;
      }
    } catch (_) {}
    return 'ar_SA';
  }

  Future<void> _listen() async {
    final locale = await _arabicLocale();
    if (!mounted) return;
    setState(() {
      _listening = true;
      _status = 'تكلّم الآن… اقرأ النص بوضوح';
    });
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        if (!mounted) return;
        setState(() => _words = r.recognizedWords);
      },
      localeId: locale,
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('البحث بالصوت', style: titleStyle(size: 19, color: accent(context))),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _listening ? () => _speech.stop() : _listen,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Container(
                  padding: EdgeInsets.all(_listening ? 18 + _pulse.value * 10 : 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGold.withValues(alpha: _listening ? 0.15 + _pulse.value * 0.15 : 0.12),
                  ),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [kGreen, kDeepGreen]),
                  ),
                  child: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: kGold, size: 38),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(_status, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor(context), borderRadius: BorderRadius.circular(14)),
              child: Text(_words.isEmpty ? '…' : _words, style: bookStyle(context, size: 17)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    onPressed: _words.trim().isEmpty ? null : () => Navigator.pop(context, _words),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('ابحث'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
