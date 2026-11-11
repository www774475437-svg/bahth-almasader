import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// النشر المباشر إلى قناة تيليجرام عبر بوت
class TelegramBot {
  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// يحوّل تنسيق المنشور إلى HTML تيليجرام:
  /// السطر الذي يبدأ بـ «> » يصير اقتباسًا، وسطر العنوان (📜) يصير عريضًا
  static String toHtml(String text) {
    final out = <String>[];
    final quote = <String>[];
    void flush() {
      if (quote.isNotEmpty) {
        out.add('<blockquote>${quote.join('\n')}</blockquote>');
        quote.clear();
      }
    }

    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.startsWith('> ') || l.startsWith('>')) {
        quote.add(_esc(l.replaceFirst(RegExp(r'^>\s?'), '')));
        continue;
      }
      flush();
      if (i == 0 && l.trim().startsWith('📜')) {
        out.add('<b>${_esc(l)}</b>');
      } else {
        out.add(_esc(l));
      }
    }
    flush();
    return out.join('\n');
  }

  static void _check(http.Response r) {
    Map<String, dynamic> body = {};
    try {
      body = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {}
    if (r.statusCode != 200 || body['ok'] != true) {
      throw Exception('${body['description'] ?? 'HTTP ${r.statusCode}'}');
    }
  }

  static Future<void> sendText(String token, String chat, String text) async {
    final uri = Uri.https('api.telegram.org', '/bot$token/sendMessage');
    final r = await http.post(uri, body: {
      'chat_id': chat,
      'text': toHtml(text),
      'parse_mode': 'HTML',
      'disable_web_page_preview': 'true',
    }).timeout(const Duration(seconds: 25));
    _check(r);
  }

  static Future<void> sendPhoto(String token, String chat, Uint8List png, {String caption = ''}) async {
    final uri = Uri.https('api.telegram.org', '/bot$token/sendPhoto');
    final req = http.MultipartRequest('POST', uri)
      ..fields['chat_id'] = chat
      ..files.add(http.MultipartFile.fromBytes('photo', png, filename: 'quote.png'));
    if (caption.isNotEmpty) {
      req.fields['caption'] = toHtml(caption);
      req.fields['parse_mode'] = 'HTML';
    }
    final streamed = await req.send().timeout(const Duration(seconds: 40));
    final r = await http.Response.fromStream(streamed);
    _check(r);
  }

  /// للتجربة من الإعدادات
  static Future<void> test(String token, String chat) =>
      sendText(token, chat, '✅ تم ربط تطبيق «بحث المصادر» بالقناة بنجاح.');
}
