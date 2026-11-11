import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// متصفح داخلي لفتح تراث دون الخروج من التطبيق
class WebPage extends StatefulWidget {
  final Uri url;
  final String title;
  const WebPage({super.key, required this.url, this.title = 'تراث'});

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url.toString();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (u) {
          if (mounted) setState(() => _currentUrl = u);
        },
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          // روابط غير الويب (تيليجرام، واتساب…) تُفتح خارج التطبيق
          if (u != null && u.scheme != 'http' && u.scheme != 'https') {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.url);
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF173F35),
          foregroundColor: Colors.white,
          title: Text(widget.title, style: const TextStyle(fontSize: 17)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'رجوع',
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _back,
            ),
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: _currentUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('تم نسخ الرابط ✓')));
                  }
                } else if (v == 'open') {
                  launchUrl(Uri.parse(_currentUrl), mode: LaunchMode.externalApplication);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'copy', child: Text('نسخ الرابط')),
                PopupMenuItem(value: 'open', child: Text('فتح في المتصفح')),
              ],
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 3,
                    color: const Color(0xFFC9A227),
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
