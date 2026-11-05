import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../models/project.dart';
import '../widgets.dart';

/// «معاينة فورية قبل الإنشاء»: the app drawn by the AI straight from the description, to try right away.
/// Pops with the page when the owner takes it as the app's design.
class InstantPreviewScreen extends StatefulWidget {
  const InstantPreviewScreen({super.key, required this.lang, required this.description, this.title = 'معاينة فورية'});
  final Lang lang;
  final String description;
  final String title;

  @override
  State<InstantPreviewScreen> createState() => _InstantPreviewScreenState();
}

class _InstantPreviewScreenState extends State<InstantPreviewScreen> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AlphaColors.bg);
  String? _html;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ai = await context.read<AppState>().ai();
      if (!ai.available) throw Exception('أضف مفتاح Claude أو Gemini في الإعدادات أولاً.');
      final html = await ai.instantPreview(widget.lang, widget.description, fresh: fresh);
      await _web.loadHtmlString(html, baseUrl: 'https://preview.alpha.app/instant/');
      if (mounted) setState(() => _html = html);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final native = widget.lang == Lang.flutter || widget.lang == Lang.kotlin || widget.lang == Lang.python;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(tooltip: 'ارسم من جديد', onPressed: _busy ? null : () => _load(fresh: true), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if (native)
            Container(
              width: double.infinity,
              color: AlphaColors.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('معاينة بالذكاء الاصطناعي لشكل تطبيق ${widget.lang.label} (Material 3)',
                  style: const TextStyle(color: AlphaColors.muted, fontSize: 12.5)),
            ),
          Expanded(
            child: _busy
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('الذكاء الاصطناعي يرسم التطبيق من وصفك…', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('قد يأخذ دقيقة', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
                    ]),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded, color: AlphaColors.bad, size: 40),
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            FilledButton(onPressed: () => _load(fresh: true), child: const Text('حاول مرة أخرى')),
                          ]),
                        ),
                      )
                    : WebViewWidget(controller: _web),
          ),
          if (_html != null && !_busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GradientButton(
                label: 'اعتمده تصميماً للتطبيق',
                icon: Icons.check_circle_rounded,
                onPressed: () => Navigator.pop(context, _html),
              ),
            ),
        ]),
      ),
    );
  }
}
