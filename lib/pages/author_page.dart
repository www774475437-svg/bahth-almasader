import 'package:flutter/material.dart';

import '../nav.dart';
import '../turath_api.dart';
import '../widgets/common.dart';
import 'search_page.dart';

/// بطاقة المؤلف
class AuthorPage extends StatefulWidget {
  final int authorId;
  final String name;
  const AuthorPage({super.key, required this.authorId, required this.name});

  @override
  State<AuthorPage> createState() => _AuthorPageState();
}

class _AuthorPageState extends State<AuthorPage> {
  AuthorInfo? _a;
  String? _error;

  @override
  void initState() {
    super.initState();
    TurathApi.getAuthor(widget.authorId).then((a) {
      if (mounted) setState(() => _a = a);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل بيانات المؤلف');
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor(context),
        foregroundColor: Colors.white,
        title: Text('المؤلف', style: titleStyle(size: 18)),
      ),
      body: ListView(
        children: [
          AppCard(
            margin: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: kGreen,
                      child: Icon(Icons.person_rounded, color: kGold, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.name, style: titleStyle(size: 19, color: accent(context)))),
                  ],
                ),
                const SizedBox(height: 10),
                if (a?.deathYear != null) PagePill('توفي سنة ${a!.deathYear} هـ'),
                const SizedBox(height: 10),
                if (_error != null)
                  Text(_error!)
                else if (a == null)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kGreen)))
                else if (a.info.isNotEmpty)
                  SelectableText(a.info, style: const TextStyle(height: 1.8, fontSize: 14.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => searchWithin(
                      context,
                      SearchScope(label: 'في كتب: ${widget.name}', authorId: widget.authorId),
                    ),
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('ابحث في كتب هذا المؤلف'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
