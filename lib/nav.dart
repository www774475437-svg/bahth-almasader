import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'pages/search_page.dart';

final searchKey = GlobalKey<SearchPageState>();
final homeKey = GlobalKey<HomeShellState>();

/// يرجع إلى صفحة البحث ويحصر البحث في كتاب أو مؤلف
void searchWithin(BuildContext context, SearchScope scope) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  homeKey.currentState?.selectTab(0);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    searchKey.currentState?.setScope(scope);
  });
}

/// يرجع إلى صفحة البحث ويبحث عن نص
void searchText(BuildContext context, String text) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  homeKey.currentState?.selectTab(0);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    searchKey.currentState?.runSearch(text);
  });
}
