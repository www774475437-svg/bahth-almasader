import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daily.dart';
import '../library.dart';
import '../nav.dart';
import '../settings.dart';
import '../storage.dart';
import '../text_cleaner.dart';
import '../widgets/common.dart';
import '../widgets/voice_sheet.dart';
import 'approved_page.dart';
import 'book_page.dart';
import 'bookmarks_page.dart';
import 'page_viewer.dart';
import 'saved_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _share = MethodChannel('bahth/share');
  int _index = 0;

  void selectTab(int i) {
    if (mounted) setState(() => _index = i);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNotificationTap = _onNotification;
    final lp = Daily.launchPayload;
    if (lp != null) {
      Daily.launchPayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onNotification(lp));
    }
    _share.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        _searchFor(call.arguments as String);
      }
      return null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? shared;
      try {
        shared = await _share.invokeMethod<String>('getInitialText');
      } catch (_) {}
      if (shared != null && shared.trim().isNotEmpty) {
        _searchFor(shared);
      } else {
        _checkClipboard();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  /// الضغط على إشعار: يفتح الفاصل أو الكتاب أو المحفوظات
  void _onNotification(String payload) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    if (payload == 'daily') {
      setState(() => _index = 0);
    } else if (payload == 'saved') {
      setState(() => _index = 2);
    } else if (payload.startsWith('bm:')) {
      final b = Library.instance.bookmarkById(payload.substring(3));
      setState(() => _index = 3);
      if (b != null && b.isSet) {
        nav.push(MaterialPageRoute(builder: (_) => PageViewer(start: b.toHit(), query: '')));
      }
    } else if (payload.startsWith('book:')) {
      final id = int.tryParse(payload.substring(5)) ?? 0;
      if (id > 0) {
        var name = Store.instance.favBooks[id] ?? '';
        for (final r in Store.instance.recentBooks) {
          if (r.id == id) name = r.name;
        }
        nav.push(MaterialPageRoute(builder: (_) => BookPage(bookId: id, name: name.isEmpty ? 'الكتاب' : name)));
      }
    }
  }

  Future<void> _checkClipboard() async {
    if (!Settings.instance.clipboardDetect) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final t = (data?.text ?? '').trim();
      if (t.isEmpty || t == Store.instance.lastClipboardOffer) return;
      if (Store.instance.history.isNotEmpty && Store.instance.history.first == t) return;
      if (TextCleaner.words(t).length < 4) return;
      await Store.instance.setLastClipboardOffer(t);
      if (!mounted) return;
      setState(() => _index = 0);
      searchKey.currentState?.offerClipboard(t);
    } catch (_) {}
  }

  /// اختصارات أيقونة التطبيق
  Future<void> _shortcut(String action) async {
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (action == 'bookmarks') {
      setState(() => _index = 3);
    } else if (action == 'paste') {
      setState(() => _index = 0);
      final data = await Clipboard.getData('text/plain');
      final t = data?.text ?? '';
      if (t.trim().isNotEmpty) {
        await Store.instance.setLastClipboardOffer(t.trim());
        searchKey.currentState?.runSearch(t);
      }
    } else if (action == 'voice') {
      setState(() => _index = 0);
      final t = await showVoiceSheet(context);
      if (t != null && t.trim().isNotEmpty) searchKey.currentState?.runSearch(t);
    }
  }

  void _searchFor(String text) {
    if (!mounted) return;
    if (text.startsWith('§shortcut:')) {
      final a = text.substring('§shortcut:'.length);
      WidgetsBinding.instance.addPostFrameCallback((_) => _shortcut(a));
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchKey.currentState?.runSearch(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          SearchPage(key: searchKey),
          const ApprovedPage(),
          const SavedPage(),
          const BookmarksPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: dark ? kDarkCard : Colors.white,
        indicatorColor: kGold.withValues(alpha: 0.28),
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.manage_search_rounded, color: accent(context)),
            label: 'بحث',
          ),
          NavigationDestination(
            icon: const Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified_rounded, color: accent(context)),
            label: 'المعتمدة',
          ),
          const NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded, color: kGold),
            label: 'المحفوظات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded, color: Color(0xFFE5534B)),
            label: 'الفواصل',
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded, color: accent(context)),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
