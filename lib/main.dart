import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'approved.dart';
import 'config.dart';
import 'daily.dart';
import 'daily_benefit.dart';
import 'library.dart';
import 'reading.dart';
import 'nav.dart';
import 'pages/home_shell.dart';
import 'pages/onboarding.dart';
import 'settings.dart';
import 'storage.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  await Approved.instance.load();
  await Store.instance.load();
  await Library.instance.load();
  await Reading.instance.load();
  await Daily.init();
  await DailyBenefit.load();
  Store.instance.onSavedChanged = () => Daily.refresh();
  Daily.refresh();
  DailyBenefit.ensure().then((changed) {
    if (changed) {
      Daily.refresh();
      searchKey.currentState?.refreshIdle();
    }
  });
  Library.instance.rescheduleAll();
  runApp(const TurathFinderApp());
}

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: kGreen, brightness: b);
  if (dark) {
    // ليلي أسود فاخر مع لمسات ذهبية
    scheme = scheme.copyWith(
      surface: const Color(0xFF0E0E0E),
      primary: const Color(0xFFE2C46A),
      onPrimary: Colors.black,
      secondary: const Color(0xFFC9A227),
      surfaceContainerHighest: const Color(0xFF1C1C1C),
    );
  }
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : kPaper,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
  return base.copyWith(textTheme: safeTextTheme(Settings.instance.uiFont, base.textTheme));
}

class TurathFinderApp extends StatelessWidget {
  const TurathFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) => MaterialApp(
        title: kAppName,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: Settings.instance.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: Settings.instance.onboardingDone
            ? HomeShell(key: homeKey)
            : OnboardingPage(onDone: () => Settings.instance.setOnboardingDone(true)),
      ),
    );
  }
}
