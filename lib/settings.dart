import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خطوط الواجهة
const kUiFonts = <String>[
  'Tajawal',
  'Cairo',
  'Almarai',
  'IBM Plex Sans Arabic',
  'Noto Kufi Arabic',
  'Changa',
];

/// خطوط نصوص الكتب
const kBookFonts = <String>[
  'Amiri',
  'Scheherazade New',
  'Noto Naskh Arabic',
  'Lateef',
  'Markazi Text',
  'Reem Kufi',
];

/// الأسماء العربية للخطوط
const kFontLabels = <String, String>{
  'Tajawal': 'تجوّل',
  'Cairo': 'القاهرة',
  'Almarai': 'المراعي',
  'IBM Plex Sans Arabic': 'بلكس',
  'Noto Kufi Arabic': 'نوتو كوفي',
  'Changa': 'شانغا',
  'Amiri': 'أميري',
  'Scheherazade New': 'شهرزاد',
  'Noto Naskh Arabic': 'نوتو نسخ',
  'Lateef': 'لطيف',
  'Markazi Text': 'المركزي',
  'Reem Kufi': 'ريم كوفي',
};

/// خط العناوين الزخرفي
const kTitleFont = 'El Messiri';

/// خط بطاقات الاقتباس
const kQuoteTitleFont = 'Aref Ruqaa';

TextStyle safeFont(String family, TextStyle style) {
  try {
    return GoogleFonts.getFont(family, textStyle: style);
  } catch (_) {
    return GoogleFonts.amiri(textStyle: style);
  }
}

TextTheme safeTextTheme(String family, TextTheme base) {
  try {
    return GoogleFonts.getTextTheme(family, base);
  } catch (_) {
    return GoogleFonts.tajawalTextTheme(base);
  }
}

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  SharedPreferences? _p;

  ThemeMode themeMode = ThemeMode.light;
  String uiFont = 'Tajawal';
  String bookFont = 'Amiri';
  double bookScale = 1.0;
  bool clipboardDetect = true;
  bool onboardingDone = false;
  String closingMark = '،.🌿';
  String botToken = '';
  String channel = '';
  bool dailyNotify = false;
  int notifyHour = 8;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    final tm = p.getInt('themeMode') ?? 1;
    themeMode = (tm >= 0 && tm <= 2) ? ThemeMode.values[tm] : ThemeMode.light;
    uiFont = p.getString('uiFont') ?? uiFont;
    if (!kUiFonts.contains(uiFont)) uiFont = 'Tajawal';
    bookFont = p.getString('bookFont') ?? bookFont;
    if (!kBookFonts.contains(bookFont)) bookFont = 'Amiri';
    bookScale = p.getDouble('bookScale') ?? 1.0;
    clipboardDetect = p.getBool('clipboardDetect') ?? true;
    onboardingDone = p.getBool('onboardingDone') ?? false;
    closingMark = p.getString('closingMark') ?? closingMark;
    botToken = p.getString('botToken') ?? '';
    channel = p.getString('channel') ?? '';
    dailyNotify = p.getBool('dailyNotify') ?? false;
    notifyHour = p.getInt('notifyHour') ?? 8;
  }

  bool get telegramReady => botToken.trim().isNotEmpty && channel.trim().isNotEmpty;

  void setTelegram(String token, String chan) {
    botToken = token.trim();
    channel = chan.trim();
    _p?.setString('botToken', botToken);
    _p?.setString('channel', channel);
    notifyListeners();
  }

  void setDailyNotify(bool v) {
    dailyNotify = v;
    _p?.setBool('dailyNotify', v);
    notifyListeners();
  }

  void setNotifyHour(int h) {
    notifyHour = h;
    _p?.setInt('notifyHour', h);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _p?.setInt('themeMode', m.index);
    notifyListeners();
  }

  void setUiFont(String f) {
    uiFont = f;
    _p?.setString('uiFont', f);
    notifyListeners();
  }

  void setBookFont(String f) {
    bookFont = f;
    _p?.setString('bookFont', f);
    notifyListeners();
  }

  void setBookScale(double s) {
    bookScale = s;
    _p?.setDouble('bookScale', s);
    notifyListeners();
  }

  void setClipboardDetect(bool v) {
    clipboardDetect = v;
    _p?.setBool('clipboardDetect', v);
    notifyListeners();
  }

  void setOnboardingDone(bool v) {
    onboardingDone = v;
    _p?.setBool('onboardingDone', v);
    notifyListeners();
  }

  void setClosingMark(String v) {
    closingMark = v;
    _p?.setString('closingMark', v);
    notifyListeners();
  }
}
