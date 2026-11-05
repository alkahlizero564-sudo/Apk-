import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/theme.dart';
import '../../generator/app_files.dart';
import '../../models/project.dart';
import '../widgets.dart';

/// The app running inside Alpha before any build: the same engine screens with the project's design, tables and
/// sample data. Everything works (add, edit, filters, forms); the data stays in the preview.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.project, this.customCode = ''});
  final Project project;

  /// Pasted HTML code of the app: shown as it is.
  final String customCode;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AlphaColors.bg);
  late AppUnit _app = widget.project.apps.isEmpty
      ? AppUnit(slug: widget.project.base, role: 'single', title: widget.project.title)
      : widget.project.apps.first;
  bool _admin = false;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final html = widget.customCode.trim().isNotEmpty
        ? widget.customCode
        : await buildPreviewHtml(widget.project, _app, admin: _admin, seed: _reload);
    await _web.loadHtmlString(html, baseUrl: 'https://preview.alpha.app/${_app.slug}/');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة فورية'),
        actions: [
          IconButton(
            tooltip: 'بيانات جديدة',
            onPressed: () {
              setState(() => _reload++);
              _load();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  children: [
                    if (p.apps.length > 1)
                      SegmentedButton<String>(
                        segments: [for (final a in p.apps) ButtonSegment(value: a.slug, label: Text(a.roleLabel))],
                        selected: {_app.slug},
                        onSelectionChanged: (v) {
                          setState(() => _app = p.apps.firstWhere((a) => a.slug == v.first));
                          _load();
                        },
                      )
                    else if (widget.customCode.trim().isEmpty)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _admin,
                        onChanged: (v) {
                          setState(() => _admin = v);
                          _load();
                        },
                        title: const Text('عرض كمدير', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    Text(
                      widget.customCode.trim().isNotEmpty
                          ? 'كودك كما هو (HTML)'
                          : 'نفس الشاشات والجداول والتصميم، ببيانات تجريبية. جرّب الإضافة والتعديل والفلاتر.',
                      style: const TextStyle(color: AlphaColors.muted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 18.5,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D2B),
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(color: hexColor(p.theme.seed).withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(31),
                        child: WebViewWidget(controller: _web),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The preview page: the HTML engine with the project's design and tables, data on the phone, sample rows.
Future<String> buildPreviewHtml(Project p, AppUnit app, {required bool admin, int seed = 0}) async {
  final css = (await rootBundle.loadString('engines/html/style.css')).replaceFirst('@import url("fonts/fonts.css");', await _inlineFonts());
  final backend = await rootBundle.loadString('engines/html/backend.js');
  final js = await rootBundle.loadString('engines/html/app.js');
  final cfg = appConfig(p, app);
  // Data on the phone in the preview (no server needed); the owner sees the admin side when asked.
  cfg['backend'] = {'type': 'none', 'prefix': p.prefix, 'auth': 'none'};
  cfg['preview'] = true;
  final role = app.role == 'single' ? (admin ? 'single' : 'customer') : app.role;
  (cfg['app'] as Map)['role'] = role;
  (cfg['app'] as Map)['slug'] = '${app.slug}-preview$seed';
  String safe(String code) => code.replaceAll('</script', '<\\/script');
  // The AI-designed interface: its CSS after the engine's, its JS (and the libraries it names) before app.js.
  var designCss = '', designJs = '';
  if (!p.design.isEmpty) {
    designCss = '<style>${p.design.css.replaceAll('</style', '<\\/style')}</style>';
    final js = p.design.js;
    if (js.trim().isNotEmpty) {
      for (final lib in designLibs.entries) {
        if (!RegExp('\\b${lib.key}\\b').hasMatch(js)) continue;
        for (final f in lib.value) {
          final code = await rootBundle.loadString('engines/html/design-libs/$f');
          if (f.endsWith('.css')) {
            designCss += '<style>$code</style>';
          } else {
            designJs += '<script>${safe(code)}</script>';
          }
        }
      }
      designJs += '<script>${safe(js)}</script>';
    }
  }
  return '''<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><title>${p.title}</title>
<style>$css</style><script>window.ALPHA = ${safe(jsonEncode(cfg))};
try { if (localStorage.getItem("alpha_preview_seed") !== "$seed") { localStorage.clear(); localStorage.setItem("alpha_preview_seed", "$seed"); } } catch (e) {}
</script>$designCss</head><body>
<div id="app"><div class="boot"><div class="spinner"></div></div></div>
<div id="sheet" class="sheet" hidden><div class="sheet-card"><div class="handle"></div><div id="sheet-body"></div></div></div>
<div id="toast" class="toast" hidden></div>
<script>${safe(backend)}</script>$designJs<script>${safe(js)}</script></body></html>''';
}

/// Libraries an AI design may use (global name → files in engines/html/design-libs), same list as factory/prepare.py.
const designLibs = {
  'gsap': ['gsap.min.js'],
  'ScrollTrigger': ['ScrollTrigger.min.js'],
  'AOS': ['aos.css', 'aos.js'],
  'Typed': ['typed.umd.js'],
  'VanillaTilt': ['vanilla-tilt.min.js'],
  'confetti': ['confetti.js'],
  'rough': ['rough.js'],
};

/// The engine's fonts as data URLs (the preview page has no files next to it). Read once.
String? _fontsCss;
Future<String> _inlineFonts() async {
  if (_fontsCss != null) return _fontsCss!;
  try {
    var css = await rootBundle.loadString('engines/html/fonts/fonts.css');
    final files = RegExp(r"url\('([\w.-]+\.woff2)'\)").allMatches(css).map((m) => m.group(1)!).toSet();
    for (final f in files) {
      final bytes = await rootBundle.load('engines/html/fonts/$f');
      css = css.replaceAll("url('$f')", "url('data:font/woff2;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}')");
    }
    return _fontsCss = css;
  } catch (_) {
    return _fontsCss = ''; // system fonts
  }
}
