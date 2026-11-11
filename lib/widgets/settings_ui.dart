import 'package:flutter/material.dart';

import 'common.dart';

/// عناصر قائمة الإعدادات بأسلوب مرتّب (أيقونة في مربع، سهم، فواصل)

Color tileIconBg(BuildContext c) => isDark(c) ? const Color(0xFF262626) : const Color(0xFFEDEDF0);
Color tileIconFg(BuildContext c) => isDark(c) ? const Color(0xFFD1D1D6) : const Color(0xFF5B5B60);
Color groupColor(BuildContext c) => isDark(c) ? const Color(0xFF141414) : Colors.white;

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final String? footer;
  const SettingsGroup({super.key, required this.children, this.header, this.footer});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: 72),
          child: Divider(height: 1, thickness: 0.6, color: outline.withValues(alpha: 0.25)),
        ));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(header!, style: TextStyle(color: outline, fontSize: 13.5)),
            ),
          Container(
            decoration: BoxDecoration(
              color: groupColor(context),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: items),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: TextStyle(color: outline, fontSize: 12.5, height: 1.6)),
            ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool chevron;
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.chevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor == null ? tileIconBg(context) : iconColor!.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor ?? tileIconFg(context), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: outline, fontSize: 12.5)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && chevron && onTap != null)
                Icon(Icons.chevron_left_rounded, color: outline.withValues(alpha: 0.7), size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحة فرعية بعنوان كبير
class SettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SettingsScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 30), children: children),
    );
  }
}

/// العنوان الكبير أعلى صفحة الإعدادات
class LargeTitle extends StatelessWidget {
  final String text;
  const LargeTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, top + 24, 24, 18),
      child: Text(text, style: titleStyle(size: 34, color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}
