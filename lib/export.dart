import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'storage.dart';

String _date(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// نص المحفوظات بصيغة قابلة للنسخ
String savedAsText(List<SavedItem> items) {
  final b = StringBuffer('📚 محفوظات «$kAppName»\n\n');
  for (final s in items) {
    b.writeln('«${s.hit.snippet}»');
    b.writeln(s.hit.sourceLine);
    if (s.hit.authorName.isNotEmpty) b.writeln('المؤلف: ${s.hit.authorName}');
    if (s.folder.isNotEmpty) b.writeln('المجلد: ${s.folder}');
    if (s.note.isNotEmpty) b.writeln('ملاحظة: ${s.note}');
    b.writeln('—————');
  }
  return b.toString();
}

Future<void> exportText(List<SavedItem> items) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/mahfuzat_${DateTime.now().millisecondsSinceEpoch}.txt');
  await f.writeAsString(savedAsText(items));
  await Share.shareXFiles([XFile(f.path)], text: 'محفوظات بحث المصادر');
}

Future<void> exportPdf(List<SavedItem> items) async {
  final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
  final font = pw.Font.ttf(fontData);
  final green = PdfColor.fromInt(0xFF1F5E4E);
  final gold = PdfColor.fromInt(0xFF9A7A12);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: gold, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('محفوظات «$kAppName»', style: pw.TextStyle(fontSize: 16, color: green)),
            pw.Text(_date(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        for (final s in items)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(s.hit.bookName, style: pw.TextStyle(fontSize: 14, color: green)),
                if (s.hit.authorName.isNotEmpty)
                  pw.Text(s.hit.authorName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 6),
                pw.Text('«${s.hit.snippet}»', style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
                pw.SizedBox(height: 6),
                pw.Text('صـ ${s.hit.volPage}${s.folder.isNotEmpty ? '   •   ${s.folder}' : ''}',
                    style: pw.TextStyle(fontSize: 10, color: gold)),
                if (s.note.isNotEmpty)
                  pw.Text('ملاحظة: ${s.note}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    ),
  );

  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/mahfuzat_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await f.writeAsBytes(await doc.save());
  await Share.shareXFiles([XFile(f.path)], text: 'محفوظات بحث المصادر');
}


/// مشاركة مجلد (أو كل المحفوظات) كملف يفتحه صديقك في التطبيق
Future<void> shareFolderFile(String? folder) async {
  final json = Store.instance.exportFolderJson(folder);
  final dir = await getTemporaryDirectory();
  final safe = (folder == null || folder.isEmpty ? 'mahfuzat' : folder).replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
  final f = File('${dir.path}/$safe.bahth.json');
  await f.writeAsString(json);
  await Share.shareXFiles([XFile(f.path)],
      text: 'مجلد فوائد من تطبيق «$kAppName» — افتحه من التطبيق: المحفوظات ← استيراد');
}

/// استيراد ملف فوائد، ويرجع عدد المضاف (أو null إن أُلغي)
Future<int?> importFromFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any);
  final path = r?.files.single.path;
  if (path == null) return null;
  final text = await File(path).readAsString();
  return Store.instance.importJson(text);
}

// ===================== النسخة الاحتياطية =====================
const _skipKeys = {'botToken', 'channel', 'lastClipboardOffer', 'todaySeen'};

/// يحفظ كل بيانات التطبيق في ملف ويشاركه
Future<void> exportBackup() async {
  final p = await SharedPreferences.getInstance();
  final data = <String, dynamic>{};
  for (final k in p.getKeys()) {
    if (_skipKeys.contains(k)) continue;
    final v = p.get(k);
    if (v is bool) {
      data[k] = {'t': 'b', 'v': v};
    } else if (v is int) {
      data[k] = {'t': 'i', 'v': v};
    } else if (v is double) {
      data[k] = {'t': 'd', 'v': v};
    } else if (v is String) {
      data[k] = {'t': 's', 'v': v};
    } else if (v is List) {
      data[k] = {'t': 'l', 'v': v.map((e) => '$e').toList()};
    }
  }
  final json = jsonEncode({'app': 'bahth_backup', 'version': 1, 'date': DateTime.now().toIso8601String(), 'data': data});
  final dir = await getTemporaryDirectory();
  final d = DateTime.now();
  final f = File('${dir.path}/bahth_backup_${d.year}-${d.month}-${d.day}.json');
  await f.writeAsString(json);
  await Share.shareXFiles([XFile(f.path)], text: 'نسخة احتياطية من «$kAppName»');
}

/// يستعيد نسخة احتياطية (يرجع false إن أُلغي)
Future<bool> importBackup() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any);
  final path = r?.files.single.path;
  if (path == null) return false;
  final j = jsonDecode(await File(path).readAsString());
  if (j is! Map || j['app'] != 'bahth_backup' || j['data'] is! Map) {
    throw const FormatException('ملف غير صالح');
  }
  final p = await SharedPreferences.getInstance();
  for (final e in (j['data'] as Map).entries) {
    final k = '${e.key}';
    final m = e.value;
    if (m is! Map) continue;
    final v = m['v'];
    switch (m['t']) {
      case 'b':
        await p.setBool(k, v == true);
        break;
      case 'i':
        await p.setInt(k, (v as num).toInt());
        break;
      case 'd':
        await p.setDouble(k, (v as num).toDouble());
        break;
      case 's':
        await p.setString(k, '$v');
        break;
      case 'l':
        await p.setStringList(k, (v as List).map((e) => '$e').toList());
        break;
    }
  }
  return true;
}
