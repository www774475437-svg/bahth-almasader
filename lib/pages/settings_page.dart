import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../config.dart';
import '../export.dart';
import '../reading.dart';
import '../daily.dart';
import '../library.dart';
import '../nav.dart';
import '../settings.dart';
import '../storage.dart';
import '../telegram.dart';
import '../widgets/common.dart';
import '../widgets/folder_sheet.dart';
import '../widgets/settings_ui.dart';
import 'history_page.dart';
import 'my_books_page.dart';
import 'onboarding.dart';
import 'reminders_page.dart';
import 'stats_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// تبويب «المزيد» — قائمة مرتّبة بأيقونات
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Settings.instance, Store.instance, Library.instance, Reading.instance]),
      builder: (context, _) {
        final s = Settings.instance;
        final store = Store.instance;
        final lib = Library.instance;
        return ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            const LargeTitle('المزيد'),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.favorite_border_rounded,
                iconColor: const Color(0xFFE5534B),
                title: 'تواصل مع المطوّر',
                subtitle: kDeveloper,
                onTap: () => openExternal(context, Uri.parse(kTelegramUrl)),
              ),
            ]),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.local_library_outlined,
                title: 'كتبي',
                subtitle: '${store.favBooks.length} مفضل • ${lib.downloads.length} محمّل',
                onTap: () => _push(context, const MyBooksPage()),
              ),
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'التذكيرات',
                subtitle: lib.reminders.isEmpty ? null : '${lib.reminders.length} تذكير',
                onTap: () => _push(context, const RemindersPage()),
              ),
              SettingsTile(
                icon: Icons.wb_sunny_outlined,
                title: 'فائدة اليوم',
                subtitle: s.dailyNotify ? 'الإشعار مفعّل' : 'إشعار وويدجت',
                onTap: () => _push(context, const DailySettingsPage()),
              ),
              SettingsTile(
                icon: Icons.local_fire_department_outlined,
                title: 'هدف القراءة اليومي',
                subtitle: '${Reading.instance.dailyGoal} صفحات • 🔥 ${Reading.instance.streak}',
                onTap: () => _pickGoal(context),
              ),
              SettingsTile(
                icon: Icons.history_rounded,
                title: 'سجل البحث',
                onTap: () => HistoryPage.open(context, (q) => searchText(context, q)),
              ),
              SettingsTile(
                icon: Icons.insights_rounded,
                title: 'إحصائياتي',
                onTap: () => _push(context, const StatsPage()),
              ),
            ]),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.contrast_rounded,
                title: 'المظهر',
                subtitle: s.themeMode == ThemeMode.dark
                    ? 'ليلي'
                    : s.themeMode == ThemeMode.light
                        ? 'نهاري'
                        : 'تلقائي',
                onTap: () => _push(context, const AppearancePage()),
              ),
              SettingsTile(
                icon: Icons.apps_rounded,
                title: 'أيقونة التطبيق',
                onTap: () => _push(context, const AppIconPage()),
              ),
              SettingsTile(
                icon: Icons.text_fields_rounded,
                title: 'الخطوط',
                subtitle: '${kFontLabels[s.uiFont] ?? s.uiFont} • ${kFontLabels[s.bookFont] ?? s.bookFont}',
                onTap: () => _push(context, const FontsPage()),
              ),
              SettingsTile(
                icon: Icons.folder_outlined,
                title: 'مجلدات المحفوظات',
                subtitle: '${store.folders.length} مجلدات',
                onTap: () => _push(context, const FoldersPage()),
              ),
              SettingsTile(
                icon: Icons.send_outlined,
                title: 'النشر في تيليجرام',
                subtitle: s.telegramReady ? 'مربوط بـ ${s.channel}' : 'غير مربوط',
                onTap: () => telegramDialog(context),
              ),
            ]),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.content_paste_search_rounded,
                title: 'اقتراح البحث عن المنسوخ',
                chevron: false,
                trailing: Switch(value: s.clipboardDetect, onChanged: s.setClipboardDetect),
              ),
            ]),
            SettingsGroup(
              footer: 'النسخة الاحتياطية تحفظ المحفوظات والفواصل والتمييزات والختمات والتذكيرات والإعدادات في ملف واحد.',
              children: [
                SettingsTile(
                  icon: Icons.backup_outlined,
                  title: 'حفظ نسخة احتياطية',
                  onTap: () async {
                    try {
                      await exportBackup();
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'تعذّر حفظ النسخة');
                    }
                  },
                ),
                SettingsTile(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'استعادة نسخة احتياطية',
                  onTap: () => _restore(context),
                ),
              ],
            ),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'المساعدة',
                onTap: () => _push(context, OnboardingPage(onDone: () => Navigator.of(context).pop())),
              ),
              SettingsTile(
                icon: Icons.ios_share_rounded,
                title: 'شارك التطبيق',
                onTap: () => shareText(kShareAppText),
              ),
              SettingsTile(
                icon: Icons.lightbulb_outline_rounded,
                title: 'اقترح ميزة',
                onTap: () => openExternal(context, Uri.parse(kTelegramUrl)),
              ),
            ]),
            SettingsGroup(children: [
              SettingsTile(
                icon: Icons.auto_stories_outlined,
                title: 'حول',
                subtitle: 'الإصدار $kVersion',
                onTap: () => _push(context, const AboutAppPage()),
              ),
            ]),
          ],
        );
      },
    );
  }
}

Future<void> _pickGoal(BuildContext context) async {
  final g = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: groupColor(context),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('كم صفحة تقرأ كل يوم؟', style: titleStyle(size: 18, color: accent(ctx))),
          for (final n in const [5, 10, 20, 30, 50, 100])
            ListTile(
              leading: const Icon(Icons.local_fire_department_rounded, color: kGold),
              title: Text('$n صفحات'),
              trailing: Reading.instance.dailyGoal == n ? const Icon(Icons.check_rounded, color: kGreen) : null,
              onTap: () => Navigator.pop(ctx, n),
            ),
        ],
      ),
    ),
  );
  if (g != null) await Reading.instance.setGoal(g);
}

Future<void> _restore(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('استعادة نسخة احتياطية'),
      content: const Text('ستُستبدل بياناتك الحالية ببيانات الملف. هل تريد المتابعة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('متابعة')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final done = await importBackup();
    if (!done) return;
    await Settings.instance.load();
    await Store.instance.load();
    await Library.instance.load();
    await Reading.instance.load();
    Settings.instance.setThemeMode(Settings.instance.themeMode);
    Library.instance.rescheduleAll();
    Daily.refresh();
    if (context.mounted) showSnack(context, 'استُعيدت النسخة ✓');
  } catch (_) {
    if (context.mounted) showSnack(context, 'الملف غير صالح');
  }
}

// ================= أيقونة التطبيق =================
const _iconChoices = <String, String>{
  'main': 'الذهبي (الرسمي)',
  'royal': 'الملكي',
  'black': 'الأسود الذهبي',
  'emerald': 'الزمرّدي',
  'paper': 'الورقي',
  'mihrab': 'المحراب',
  'night': 'الليلي',
  'library': 'المكتبة',
};

class AppIconPage extends StatefulWidget {
  const AppIconPage({super.key});

  @override
  State<AppIconPage> createState() => _AppIconPageState();
}

class _AppIconPageState extends State<AppIconPage> {
  static const _ch = MethodChannel('bahth/share');
  String _current = 'main';

  @override
  void initState() {
    super.initState();
    _ch.invokeMethod<String>('currentIcon').then((v) {
      if (v != null && mounted) setState(() => _current = v);
    }).catchError((_) {});
  }

  Future<void> _set(String k) async {
    try {
      await _ch.invokeMethod('setIcon', {'key': k});
      setState(() => _current = k);
      if (mounted) showSnack(context, 'تغيّرت الأيقونة ✓ (قد تحتاج الشاشة الرئيسية ثوانيَ لتتحدّث)');
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تغيير الأيقونة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(title: 'أيقونة التطبيق', children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
          children: [
            for (final e in _iconChoices.entries)
              GestureDetector(
                onTap: () => _set(e.key),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _current == e.key ? kGold : Colors.transparent, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/icons/${e.key}.png', width: 86, height: 86),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ================= المظهر =================
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final s = Settings.instance;
        Widget mode(ThemeMode m, IconData i, String label) => SettingsTile(
              icon: i,
              title: label,
              chevron: false,
              trailing: s.themeMode == m ? const Icon(Icons.check_rounded, color: kGreen) : null,
              onTap: () => s.setThemeMode(m),
            );
        return SettingsScaffold(title: 'المظهر', children: [
          SettingsGroup(children: [
            mode(ThemeMode.light, Icons.light_mode_outlined, 'نهاري'),
            mode(ThemeMode.dark, Icons.dark_mode_outlined, 'ليلي'),
            mode(ThemeMode.system, Icons.brightness_auto_outlined, 'تلقائي حسب الجوال'),
          ]),
        ]);
      },
    );
  }
}

// ================= الخطوط =================
class FontsPage extends StatelessWidget {
  const FontsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final s = Settings.instance;
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return SettingsScaffold(title: 'الخطوط', children: [
          SettingsGroup(header: 'خط الواجهة', children: [
            for (final f in kUiFonts)
              SettingsTile(
                icon: Icons.font_download_outlined,
                title: kFontLabels[f] ?? f,
                chevron: false,
                trailing: s.uiFont == f ? const Icon(Icons.check_rounded, color: kGreen) : null,
                onTap: () => s.setUiFont(f),
              ),
          ]),
          SettingsGroup(header: 'خط النصوص', children: [
            for (final f in kBookFonts)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => s.setBookFont(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('«إنما الأعمال بالنيات»',
                                  style: safeFont(f, TextStyle(fontSize: 20, height: 1.7, color: onSurface))),
                              Text(kFontLabels[f] ?? f,
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                        ),
                        if (s.bookFont == f) const Icon(Icons.check_rounded, color: kGreen),
                      ],
                    ),
                  ),
                ),
              ),
          ]),
          SettingsGroup(header: 'حجم خط النصوص', children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  const Text('أ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: s.bookScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      onChanged: s.setBookScale,
                    ),
                  ),
                  const Text('أ', style: TextStyle(fontSize: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text('«مَن سلك طريقًا يلتمس فيه علمًا، سهّل الله له به طريقًا إلى الجنة»',
                  textAlign: TextAlign.center, style: bookStyle(context, size: 17)),
            ),
          ]),
        ]);
      },
    );
  }
}

// ================= المجلدات =================
class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        return SettingsScaffold(title: 'مجلدات المحفوظات', children: [
          SettingsGroup(
            footer: 'حذف المجلد لا يحذف الفوائد، بل تنتقل إلى «بدون مجلد».',
            children: [
              for (final f in store.folders)
                SettingsTile(
                  icon: Icons.folder_outlined,
                  title: f,
                  subtitle: '${store.saved.where((x) => x.folder == f).length} فائدة',
                  chevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () async {
                          final n = await askText(context, title: 'اسم جديد', initial: f);
                          if (n != null) await store.renameFolder(f, n);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () => store.deleteFolder(f),
                      ),
                    ],
                  ),
                ),
              SettingsTile(
                icon: Icons.create_new_folder_outlined,
                iconColor: kGreen,
                title: 'إضافة مجلد',
                chevron: false,
                onTap: () async {
                  final n = await askText(context, title: 'مجلد جديد', hint: 'مثل: فوائد لغوية');
                  if (n != null) await store.addFolder(n);
                },
              ),
            ],
          ),
        ]);
      },
    );
  }
}

// ================= فائدة اليوم =================
class DailySettingsPage extends StatelessWidget {
  const DailySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final s = Settings.instance;
        return SettingsScaffold(title: 'فائدة اليوم', children: [
          SettingsGroup(
            footer: 'تصلك كل يوم فائدة عشوائية من محفوظاتك.',
            children: [
              SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'الإشعار اليومي',
                chevron: false,
                trailing: Switch(
                  value: s.dailyNotify,
                  onChanged: (v) async {
                    if (v) await Daily.requestPermission();
                    s.setDailyNotify(v);
                    Daily.refresh();
                  },
                ),
              ),
              if (s.dailyNotify)
                SettingsTile(
                  icon: Icons.schedule_rounded,
                  title: 'الوقت',
                  subtitle: '${s.notifyHour.toString().padLeft(2, '0')}:00',
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay(hour: s.notifyHour, minute: 0));
                    if (t != null) {
                      s.setNotifyHour(t.hour);
                      Daily.refresh();
                    }
                  },
                ),
            ],
          ),
          const SettingsGroup(
            header: 'ويدجت الشاشة الرئيسية',
            footer: 'اضغط مطوّلًا على الشاشة الرئيسية للجوال ← الأدوات (Widgets) ← «بحث المصادر» ← اسحبها إلى الشاشة.',
            children: [
              SettingsTile(icon: Icons.widgets_outlined, title: 'ويدجت «فائدة اليوم»', chevron: false),
            ],
          ),
        ]);
      },
    );
  }
}

// ================= حول =================
class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return SettingsScaffold(title: 'حول', children: [
      const SizedBox(height: 10),
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset('assets/icon.png', width: 100, height: 100),
        ),
      ),
      const SizedBox(height: 12),
      Center(child: Text(kAppName, style: titleStyle(size: 26, color: accent(context)))),
      Center(child: Text('الإصدار $kVersion', style: TextStyle(color: outline))),
      const SizedBox(height: 18),
      SettingsGroup(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'تلصق نصًّا فيخبرك باسم الكتاب والمؤلف والجزء والصفحة، مع قراءة الصفحة '
            'داخل التطبيق، وحفظ الفوائد في مجلدات، والفواصل والتذكيرات، وصنع المنشورات وصور الاقتباس.',
            style: TextStyle(height: 1.8),
          ),
        ),
      ]),
      SettingsGroup(children: [
        SettingsTile(icon: Icons.person_outline_rounded, title: 'المطوّر', subtitle: kDeveloper, chevron: false),
        SettingsTile(
          icon: Icons.send_outlined,
          iconColor: const Color(0xFF229ED9),
          title: 'تيليجرام',
          subtitle: kTelegramUrl.replaceFirst('https://', ''),
          onTap: () => openExternal(context, Uri.parse(kTelegramUrl)),
        ),
        const SettingsTile(
            icon: Icons.storage_outlined, title: 'مصدر البيانات', subtitle: 'مكتبة تراث (turath.io)', chevron: false),
      ]),
    ]);
  }
}

// ================= ربط قناة تيليجرام =================
Future<void> telegramDialog(BuildContext context) async {
  final s = Settings.instance;
  final token = TextEditingController(text: s.botToken);
  final chan = TextEditingController(text: s.channel.isEmpty ? '@' : s.channel);
  var testing = false;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('النشر في قناتك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. افتح @BotFather في تيليجرام وأنشئ بوتًا، وانسخ «التوكن».\n'
                '2. أضف البوت مشرفًا في قناتك مع صلاحية النشر.\n'
                '3. اكتب التوكن ومعرّف القناة هنا ثم اضغط «تجربة».',
                style: TextStyle(height: 1.7, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: token,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'توكن البوت', hintText: '123456:ABC-DEF…'),
              ),
              TextField(
                controller: chan,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'معرّف القناة', hintText: '@my_channel'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: testing
                ? null
                : () async {
                    setD(() => testing = true);
                    try {
                      await TelegramBot.test(token.text.trim(), chan.text.trim());
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم الإرسال إلى القناة ✓')));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل: $e')));
                      }
                    }
                    setD(() => testing = false);
                  },
            child: Text(testing ? 'جارٍ…' : 'تجربة'),
          ),
          TextButton(
            onPressed: () {
              s.setTelegram('', '');
              Navigator.pop(ctx);
            },
            child: const Text('فصل'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              s.setTelegram(token.text, chan.text);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
