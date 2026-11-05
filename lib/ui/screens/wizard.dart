import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/custom_code.dart';
import '../../generator/presets.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
import '../../services/ai.dart';
import '../ai_design_card.dart';
import '../widgets.dart';
import 'design_studio.dart';
import 'instant_preview.dart';
import 'preview.dart';
import 'project.dart';

/// New project, one focus per step: description (or code), understanding, language, name, design, data, server, review.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key, required this.kind, this.clientName = '', this.clientRef = ''});
  final ProjectKind kind;

  /// For a client: the client's name and (when it has one) its own Supabase project. Empty: the owner's own project.
  final String clientName;
  final String clientRef;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _step = 0;
  Lang _lang = Lang.flutter;
  final _title = TextEditingController();
  final _slug = TextEditingController(text: 'app-${Random().nextInt(9000) + 1000}');
  final _desc = TextEditingController();
  final _admins = TextEditingController();
  ThemeSpec _theme = lookById('material')!.apply(ThemeSpec());
  DbSchema _schema = schemaPresets.first.build();
  String _schemaPreset = schemaPresets.first.id;
  bool _schemaTouched = false; // the owner chose the tables themself (a ready-made start, or edits)
  BackendType _backend = BackendType.none;
  AuthMode _auth = AuthMode.none;
  bool _push = false;
  bool _busy = false;
  bool _aiBusy = false;
  late ProjectKind _kind = widget.kind;
  final _code = TextEditingController();
  bool _hasCode = false;
  final _brief = TextEditingController();
  Understanding? _understood;
  bool _understandBusy = false;
  bool _themeBusy = false;
  String _themeReason = '';
  String _headline = '';
  String _subtitle = '';
  AiDesign _design = AiDesign();

  bool get _pair => _kind == ProjectKind.pair;
  bool get _clientDb => widget.clientRef.isNotEmpty;

  static const _steps = ['اللغة', 'الوصف', 'الفهم', 'الاسم', 'البيانات', 'التصميم', 'السيرفر', 'المراجعة'];

  @override
  void initState() {
    super.initState();
    _setKind(widget.kind);
    if (_clientDb) {
      // The apps live in the client's database (Supabase), separate from the owner's and the other clients'.
      _backend = BackendType.supabase;
      if (_auth == AuthMode.none && _pair) _auth = AuthMode.emailPassword;
    }
  }

  void _setKind(ProjectKind k) {
    _kind = k;
    if (k == ProjectKind.pair) {
      _backend = _backend == BackendType.none ? BackendType.supabase : _backend;
      if (_auth == AuthMode.none) _auth = AuthMode.emailPassword;
      _push = true;
    }
  }

  /// What every later step works from: the owner's own words always first, then the approved checklist.
  String get _briefText {
    final words = _hasCode ? '${_desc.text.trim()}\n(بناء الكود الذي ألصقه صاحب التطبيق)' : _desc.text.trim();
    final u = _understood;
    final base = u == null ? words : u.toBrief(words);
    final notes = _brief.text.trim();
    return notes.isEmpty ? base : '$base\n\nملاحظات صاحب التطبيق (طبّقها):\n$notes';
  }

  final Map<String, String> _answers = {}; // question → chosen answer
  bool _refineBusy = false;
  String _understandError = '';

  /// Step "الفهم": the AI only understands the description (and the pasted code).
  Future<void> _understand({bool fresh = false}) async {
    final s = context.read<AppState>();
    final ai = await s.ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات ليفهم الذكاء الاصطناعي فكرتك', error: true);
      return;
    }
    setState(() {
      _understandBusy = true;
      _understandError = '';
    });
    try {
      final u = await ai.understand(_desc.text.trim(), code: _hasCode ? _code.text : '', kind: _kind, lang: _lang, fresh: fresh);
      setState(() {
        _understood = u;
        _answers.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _understandError = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _understandBusy = false);
    }
  }

  /// The owner's answers and corrections applied to the checklist (APK Fact's «حدّث الفهم»).
  Future<void> _refine() async {
    final u = _understood;
    if (u == null) return;
    final ai = await context.read<AppState>().ai();
    setState(() => _refineBusy = true);
    try {
      final v = await ai.refine(_desc.text.trim(), u,
          answers: [for (final e in _answers.entries) (e.key, e.value)], notes: _brief.text.trim(), kind: _kind);
      setState(() {
        _understood = v;
        _answers.clear();
        _brief.clear();
      });
      if (mounted) showMessage(context, 'تحدّث الفهم');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _refineBusy = false);
    }
  }

  /// Applies the approved understanding to the next steps (language, kind, name, sign-in).
  void _applyUnderstanding() {
    final u = _understood;
    if (u == null) return;
    // The language was chosen first (like APK Fact); the understanding only suggests one.
    if (_title.text.trim().isEmpty && u.title.isNotEmpty) _title.text = u.title;
    if (u.slug.isNotEmpty && RegExp(r'^app-\d+$').hasMatch(_slug.text)) _slug.text = slugApp(u.slug);
    if (u.auth != AuthMode.none || !_pair) _auth = u.auth;
  }

  /// Step "التصميم": the AI only designs the look, from the approved understanding.
  Future<void> _suggestDesign() async {
    final ai = await context.read<AppState>().ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات', error: true);
      return;
    }
    setState(() => _themeBusy = true);
    try {
      final d = await ai.designTheme(_briefText);
      setState(() {
        _theme = d.theme;
        _headline = d.headline;
        _subtitle = d.subtitle;
        _themeReason = d.reason;
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _themeBusy = false);
    }
  }

  void _preview() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PreviewScreen(project: _build(), customCode: _hasCode && _lang == Lang.html ? _code.text : '')),
      );

  String? _stepError() {
    switch (_step) {
      case 1:
        if (_desc.text.trim().length < 8 && !(_hasCode && _code.text.trim().isNotEmpty)) return 'اكتب وصفاً لما تريد، أو الصق الكود';
        return null;
      case 2:
        if (_understood == null && !_understandBusy) return 'اضغط «افهم فكرتي» أولاً: التصميم والكود يُبنون على هذا الفهم';
        if (_understandBusy || _refineBusy) return 'انتظر حتى ينتهي الفهم';
        return null;
      case 3:
        if (_title.text.trim().isEmpty) return 'اكتب اسم التطبيق';
        final slug = slugApp(_slug.text);
        if (slug != _slug.text.trim()) return 'المعرّف بالإنجليزي الصغير والأرقام و - فقط (مثلاً: $slug)';
        if (context.read<AppState>().projects.any((p) => p.base == slug)) return 'يوجد مشروع بنفس المعرّف';
        return null;
      case 4:
        final errors = _schema.validate();
        return errors.isEmpty ? null : errors.first;
      case 6:
        if (_backend == BackendType.firebase && !_lang.supportsFirestore) return 'Firebase كقاعدة بيانات متاح لـ Flutter و HTML فقط';
        if (_pair && _backend == BackendType.none) return 'التطبيقان المتصلان يحتاجان سيرفر (Supabase أو Firebase)';
        if (_pair && !_admins.text.contains('@')) return 'اكتب بريد المدير (أو أكثر) لتطبيق الإدارة';
        return null;
    }
    return null;
  }

  void _next() {
    final err = _stepError();
    if (err != null) {
      showMessage(context, err, error: true);
      return;
    }
    if (_step == 2) {
      _applyUnderstanding();
      // The data starts right away, in the background, while the owner names the app.
      if (!_schemaTouched && !_aiBusy) {
        context.read<AppState>().ai().then((ai) {
          if (mounted && ai.available && !_schemaTouched && !_aiBusy) _designWithAi();
        });
      }
    }
    if (_step < _steps.length - 1) setState(() => _step++);
    // Entering "الفهم" starts the understanding by itself the first time.
    if (_step == 2 && _understood == null && _brief.text.isEmpty) _understand();
    // Entering «البيانات»: the tables come from the approved understanding (not a ready-made store).
    if (_step == 4 && !_schemaTouched && !_aiBusy) {
      context.read<AppState>().ai().then((ai) {
        if (mounted && ai.available) _designWithAi();
      });
    }
  }

  Project _build() {
    final s = context.read<AppState>();
    final base = slugApp(_slug.text);
    final title = _title.text.trim();
    return Project(
      id: s.newId(),
      base: base,
      title: title,
      lang: _lang,
      kind: _kind,
      description: _desc.text.trim(),
      brief: _briefText,
      customCode: _hasCode ? _code.text : '',
      design: _design,
      clientName: widget.clientName,
      supabaseRef: _clientDb ? widget.clientRef : '',
      headline: _headline,
      subtitle: _subtitle,
      theme: _theme,
      schema: _schema,
      backend: _backend,
      auth: _auth,
      push: _push && _backend != BackendType.none && _lang.supportsPush,
      admins: _admins.text.split(RegExp(r'[,\s]+')).where((e) => e.contains('@')).toList(),
      apps: Project.unitsFor(base, title, _kind),
    );
  }

  Future<void> _create() async {
    final s = context.read<AppState>();
    final p = _build();
    setState(() => _busy = true);
    try {
      await s.save(p, message: 'Alpha: new project ${p.title}');
      var note = 'تم إنشاء المشروع';
      final fromDesign = p.design.hasPrototype;
      if (s.hasGitHub && fromDesign) {
        // The approved design becomes the real ${p.lang.label} app (written and built in GitHub Actions, errors fixed by itself).
        final server = p.forClient && p.supabaseRef.isNotEmpty ||
            (p.backend == BackendType.supabase && s.hasSupabase && s.supabaseRef.isNotEmpty) ||
            (p.backend == BackendType.firebase && s.hasFirebase);
        if (server) await s.setupServer(p, buildAfter: false);
        for (final a in p.apps) {
          await s.generateWithAi(a, buildFromDesignRequest);
        }
        note = server || p.backend == BackendType.none
            ? 'تم الإنشاء: الذكاء الاصطناعي يكتب كود ${p.lang.label} مطابقاً للتصميم المعتمد ثم يبنيه'
            : 'تم الإنشاء ويُكتب الكود. أضف مفاتيح ${p.backend.label} في الإعدادات ثم اضغط «تجهيز السيرفر»';
      } else if (s.hasGitHub) {
        if (p.backend == BackendType.none) {
          await s.buildAll(p);
          note = 'تم الإنشاء وبدأ البناء في GitHub Actions';
        } else if (p.forClient && p.supabaseRef.isNotEmpty ||
            (p.backend == BackendType.supabase && s.hasSupabase && s.supabaseRef.isNotEmpty) ||
            (p.backend == BackendType.firebase && s.hasFirebase)) {
          await s.setupServer(p);
          note = 'تم الإنشاء: تجهيز السيرفر ثم البناء يعملان الآن';
        } else {
          note = 'تم الإنشاء. أضف مفاتيح ${p.backend.label} في الإعدادات ثم اضغط «تجهيز السيرفر»';
        }
      } else {
        note = 'حُفظ على الهاتف. اربط GitHub لبناء الـ APK';
      }
      if (!mounted) return;
      showMessage(context, note);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProjectScreen(projectId: p.id)));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The interface is drawn in the background as soon as the data is ready (an assembly line): by the time the
  /// owner reaches «التصميم» it is ready or nearly ready.
  String _designStatus = '';
  Future<void> _prefetchDesign() async {
    if (_design.hasPrototype || _designStatus.isNotEmpty || _hasCode) return;
    final ai = await context.read<AppState>().ai();
    if (!ai.available || !mounted) return;
    var p = _build();
    final d = AiDesign.fromJson(_design.toJson());
    var brand = '';
    try {
      for (final a in p.apps) {
        setState(() => _designStatus = p.apps.length > 1 ? 'يصمّم ${a.roleLabel} في الخلفية…' : 'يصمّم الشاشات في الخلفية…');
        final html = await ai.designPrototype(p, a, brandFrom: brand);
        d.screens[a.slug] = html;
        brand = brand.isEmpty ? html : brand;
        if (!mounted) return;
        if (_design.hasPrototype) return; // the owner already designed it meanwhile
        setState(() => _design = AiDesign.fromJson(d.toJson()));
        p = _build();
      }
    } catch (_) {
      // The design step starts it again with a visible error.
    } finally {
      if (mounted) setState(() => _designStatus = '');
    }
  }

  Future<void> _designWithAi() async {
    final s = context.read<AppState>();
    final ai = await s.ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات', error: true);
      return;
    }
    final text = _briefText.isEmpty ? _title.text.trim() : _briefText;
    if (text.isEmpty) {
      if (mounted) showMessage(context, 'اكتب الوصف في الخطوة الأولى', error: true);
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final schema = await ai.designSchema(text, pair: _pair);
      if (schema.tables.isEmpty) throw Exception('لم يقترح الذكاء الاصطناعي جداول، جرّب وصفاً أوضح');
      setState(() {
        _schema = schema;
        _schemaPreset = 'ai';
        _schemaTouched = true;
      });
      _prefetchDesign();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_pair ? 'تطبيقين متصلين' : 'تطبيق جديد', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text(
                        widget.clientName.isEmpty ? 'لي (المشروع الأساسي)' : 'للزبون: ${widget.clientName}',
                        style: const TextStyle(color: AlphaColors.muted, fontSize: 13),
                      ),
                    ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(backgroundColor: AlphaColors.surface, side: const BorderSide(color: AlphaColors.line), fixedSize: const Size(46, 46)),
                  ),
                ]),
              ),
              _Stepper(steps: _steps, current: _step, onTap: (i) => i < _step ? setState(() => _step = i) : null),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: ListView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [_body()],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: IconButton.filledTonal(
                          onPressed: () => setState(() => _step--),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
                        ),
                      ),
                    Expanded(
                      child: _step == _steps.length - 1
                          ? GradientButton(label: 'أنشئ وابنِ', icon: Icons.rocket_launch_rounded, busy: _busy, onPressed: _create)
                          : GradientButton(label: 'التالي', icon: Icons.arrow_forward_rounded, onPressed: _next),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
        0 => _langStep(),
        1 => _describeStep(),
        2 => _understandStep(),
        3 => _nameStep(),
        4 => _dataStep(),
        5 => _designStep(),
        6 => _serverStep(),
        _ => _reviewStep(),
      };

  static const _ideas = <(String, IconData, String)>[
    ('وضع ليلي', Icons.dark_mode_rounded, 'زر للتبديل بين الوضع الفاتح والليلي.'),
    ('بحث', Icons.search_rounded, 'بحث فوري في كل البيانات.'),
    ('مفضلة', Icons.favorite_border_rounded, 'إضافة العناصر للمفضلة وصفحة للمفضلة.'),
    ('إحصائيات', Icons.bar_chart_rounded, 'شاشة إحصائيات برسوم بيانية.'),
    ('واتساب', Icons.chat_rounded, 'زر تواصل عبر واتساب.'),
    ('تنبيهات', Icons.notifications_rounded, 'رسائل تنبيه داخل التطبيق بعد كل عملية.'),
    ('مشاركة', Icons.share_rounded, 'زر لمشاركة العنصر مع الآخرين.'),
    ('سلة مشتريات', Icons.shopping_cart_rounded, 'سلة مشتريات بتعديل الكمية والإجمالي.'),
  ];

  /// «معاينة فورية قبل الإنشاء»: the AI draws the app from the description now; the owner can keep it as the design.
  Future<void> _instantPreview() async {
    final html = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => InstantPreviewScreen(lang: _lang, description: _desc.text.trim(), title: _title.text.trim().isEmpty ? 'معاينة فورية' : _title.text.trim())),
    );
    if (html == null || !mounted) return;
    final apps = Project.unitsFor(slugApp(_slug.text), _title.text.trim(), _kind);
    setState(() => _design = AiDesign.fromJson(_design.toJson())..screens[apps.first.slug] = html);
    showMessage(context, 'اعتُمدت المعاينة تصميماً للتطبيق${_pair ? ' (تطبيق العميل)' : ''}');
  }

  Widget _describeStep() {
    final detected = _hasCode ? detectLang(_code.text) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('اكتب ما تريد', subtitle: 'هذه الخطوة للكتابة فقط: صف التطبيق بكلامك، والخطوة التالية تفهمه'),
        TextField(
          controller: _desc,
          minLines: 6,
          maxLines: 14,
          onChanged: (_) => setState(() => _understood = null),
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            hintText: 'مثال: مخبز يستقبل طلبات التوصيل. العميل يسجّل بالاسم والهاتف والبريد، يختار المنتجات ويطلب ويتابع الحالة. '
                'الإدارة تضيف المنتجات وتغيّر حالة الطلب، ويصل للعميل إشعار عند كل تغيير.',
          ),
        ),
        const SizedBox(height: 10),
        if (!_hasCode) ...[
          OutlinedButton.icon(
            onPressed: _desc.text.trim().length < 10 ? null : _instantPreview,
            icon: Icon(_lang == Lang.html || _lang == Lang.php ? Icons.flash_on_rounded : Icons.auto_awesome_rounded, color: AlphaColors.teal),
            label: Text(_design.hasPrototype ? 'معاينة فورية (معتمدة كتصميم ✓)' : 'معاينة فورية قبل الإنشاء'),
          ),
          const SectionTitle('أضف ميزة بضغطة'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final idea in _ideas)
              FilterChip(
                avatar: Icon(idea.$2, size: 16),
                label: Text(idea.$1),
                selected: _desc.text.contains(idea.$3),
                onSelected: (on) => setState(() {
                  final t = _desc.text.trim();
                  _desc.text = on ? (t.isEmpty ? idea.$3 : '$t\n${idea.$3}') : t.replaceAll(idea.$3, '').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
                  _understood = null;
                }),
              ),
          ]),
          const SizedBox(height: 6),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _hasCode,
          onChanged: (v) => setState(() => _hasCode = v),
          title: const Text('عندي كود جاهز أريد بناءه', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('يصبح كود التطبيق، ويُفحص ويُصلَح تلقائياً عند البناء', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
        ),
        if (_hasCode) ...[
          TextField(
            controller: _code,
            minLines: 8,
            maxLines: 20,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            onChanged: (v) => setState(() {
              final l = detectLang(v);
              if (l != null) _lang = l;
              _understood = null;
            }),
            decoration: const InputDecoration(alignLabelWithHint: true, hintText: 'الصق الكود هنا (HTML، PHP، Dart/Flutter، Python/Flet، Kotlin)'),
          ),
          const SizedBox(height: 8),
          if (_code.text.trim().isNotEmpty)
            Row(
              children: [
                Icon(detected == null ? Icons.help_outline_rounded : Icons.check_circle_rounded,
                    color: detected == null ? AlphaColors.amber : AlphaColors.ok, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    detected == null ? 'لم أتعرّف على اللغة: اخترها في خطوة اللغة' : 'اللغة: ${detected.label} · يُحفظ في ${customPath(detected)}',
                    style: const TextStyle(color: AlphaColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _understandStep() {
    final u = _understood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('فهمتك صح؟',
            subtitle: 'هذا ما فهمه الذكاء الاصطناعي من فكرتك. احذف أي بند غلط بـ ✕، جاوب الأسئلة، واكتب أي تصحيح ثم «حدّث الفهم». '
                'التصميم والبيانات والكود يُبنون على هذه القائمة بنداً بنداً.'),
        if (_understandBusy)
          const GlassCard(
            padding: EdgeInsets.all(26),
            child: Column(children: [CircularProgressIndicator(), SizedBox(height: 14), Text('يقرأ فكرتك ويفهمها…'), SizedBox(height: 4), ElapsedText()]),
          ),
        if (u == null && !_understandBusy)
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('لم يصل الفهم بعد.', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_understandError.isEmpty ? 'اضغط ليفهم الذكاء الاصطناعي فكرتك:' : 'السبب: $_understandError',
                  style: TextStyle(color: _understandError.isEmpty ? AlphaColors.muted : AlphaColors.amber, height: 1.5)),
              const SizedBox(height: 10),
              GradientButton(label: _understandError.isEmpty ? 'افهم فكرتي' : 'حاول مرة أخرى', icon: Icons.psychology_rounded, onPressed: _understand),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _desc.text.trim().isEmpty
                    ? null
                    : () => setState(() {
                          _understood = Understanding.fromOwnerWords(_desc.text.trim());
                          _understandError = '';
                        }),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('تابع بكلماتي (أصحّح الفهم بنفسي)'),
              ),
            ]),
          ),
        if (u != null && !_understandBusy) ...[
          GlassCard(
            gradient: LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.3), AlphaColors.teal.withValues(alpha: 0.12)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.title.isEmpty ? 'تطبيقك' : u.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(u.summary, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill('يقترح: ${u.kind.label}', color: AlphaColors.blue),
                  Pill('اللغة المقترحة: ${u.lang.label}', color: Color(u.lang.color)),
                  Pill(u.auth.label, color: AlphaColors.pink),
                ]),
              ],
            ),
          ),
          const SectionTitle('لمن التطبيق؟'),
          KindPicker(value: _kind, suggested: u.kind, onPick: (k) => setState(() => _setKind(k))),
          for (final e in Understanding.sections.entries)
            if (u.list(e.key).isNotEmpty)
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final item in List.of(u.list(e.key)))
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 9), child: Icon(Icons.check_rounded, size: 16, color: AlphaColors.teal)),
                      const SizedBox(width: 6),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(item, style: const TextStyle(height: 1.5)))),
                      IconButton(
                        tooltip: 'احذف هذا البند',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => u.list(e.key).remove(item)),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AlphaColors.muted),
                      ),
                    ]),
                ]),
              ),
          if (u.questions.isNotEmpty) ...[
            const SectionTitle('أسئلة تحتاج قرارك'),
            for (final q in u.questions)
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q.q, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in q.options)
                      ChoiceChip(
                        label: Text(o),
                        selected: _answers[q.q] == o,
                        onSelected: (on) => setState(() => on ? _answers[q.q] = o : _answers.remove(q.q)),
                      ),
                  ]),
                ]),
              ),
          ],
        ],
        const SectionTitle('تصحيح أو إضافة', subtitle: 'اكتب أي شيء ناقص أو غلط، ثم «حدّث الفهم»'),
        TextField(
          controller: _brief,
          minLines: 2,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(alignLabelWithHint: true, hintText: 'مثلاً: الأسعار بالجنيه، أضف شاشة للعروض، اللون الأساسي أخضر…'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: u == null || _refineBusy || (_answers.isEmpty && _brief.text.trim().isEmpty) ? null : _refine,
              icon: _refineBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, color: AlphaColors.teal),
              label: Text(_refineBusy ? 'يحدّث…' : 'حدّث الفهم'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _understandBusy ? null : () => _understand(fresh: true),
            icon: const Icon(Icons.refresh_rounded, color: AlphaColors.amber),
            label: const Text('أعد الفهم'),
          ),
        ]),
      ],
    );
  }

  Widget _langStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('بأي لغة نبني؟', subtitle: 'كل لغة معها محرّك Alpha المختبَر وكل مكتباتها جاهزة'),
          for (final l in Lang.values)
            GlassCard(
              onTap: () => setState(() {
                _lang = l;
                if (_backend == BackendType.firebase && !l.supportsFirestore) _backend = BackendType.supabase;
              }),
              gradient: _lang == l
                  ? LinearGradient(colors: [Color(l.color).withValues(alpha: 0.35), Color(l.color).withValues(alpha: 0.08)])
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: Color(l.color).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(15)),
                    child: Icon(langIcon(l), color: Color(l.color), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(l.stack, style: const TextStyle(color: AlphaColors.muted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(_langNote(l), style: const TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.5)),
                      ],
                    ),
                  ),
                  Icon(_lang == l ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: _lang == l ? Color(l.color) : AlphaColors.muted),
                ],
              ),
            ),
        ],
      );

  String _langNote(Lang l) => switch (l) {
        Lang.html => 'أسرع بناء، 16 مكتبة مدمجة بدون إنترنت، Supabase أو Firebase وإشعارات.',
        Lang.php => 'تطبيق سيرفر (SQLite أو Supabase) + ملف رفع للاستضافة + APK يفتحه.',
        Lang.flutter => 'الأقوى للأداء والتصميم، 37 حزمة مختبرة، Supabase أو Firebase وإشعارات.',
        Lang.python => 'بايثون مع Flet بواجهات Material 3، Supabase أو بيانات على الجهاز.',
        Lang.kotlin => 'أندرويد أصلي بـ Jetpack Compose، Supabase وإشعارات FCM.',
      };

  Widget _nameStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('اسم التطبيق ووصفه'),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'الاسم تحت الأيقونة (عربي أو إنجليزي)', prefixIcon: Icon(Icons.badge_rounded)),
            onChanged: (v) {
              final ascii = slugApp(v);
              if (RegExp(r'[a-zA-Z]').hasMatch(v)) _slug.text = ascii;
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'المعرّف (إنجليزي): اسم المجلد وبادئة الجداول',
              prefixIcon: Icon(Icons.tag_rounded),
              helperText: 'مثلاً: bakery ← التطبيقات bakery-customer و bakery-admin',
            ),
          ),
        ],
      );

  Widget _designStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('التصميم', subtitle: 'هذه الخطوة للشكل فقط: الذكاء الاصطناعي يصمّم الواجهات، أو اختر مدرسة جاهزة'),
          AiDesignCard(
            draft: _build,
            autoStart: _designStatus.isEmpty,
            busyElsewhere: _designStatus,
            onDesigned: (d) => setState(() => _design = d),
          ),
          if (!_design.hasPrototype) ...[
            const SectionTitle('أو اختر مدرسة تصميم جاهزة'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _themeBusy ? null : _suggestDesign,
                    icon: _themeBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, color: AlphaColors.amber),
                    label: Text(_themeBusy ? 'يختار…' : 'اختر المدرسة بالذكاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.play_circle_rounded),
                    label: const Text('معاينة فورية'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ],
            ),
            if (_themeReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_themeReason, style: const TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.5)),
              ),
            const SizedBox(height: 10),
            DesignEditor(
              theme: _theme,
              title: _headline.isNotEmpty ? _headline : _title.text,
              schema: _schema,
              pair: _pair,
              onChanged: (t) => setState(() => _theme = t),
            ),
          ],
        ],
      );

  Widget _dataStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('البيانات', subtitle: 'هذه الخطوة للجداول فقط: صمّمها من الفهم بالذكاء الاصطناعي أو اختر بداية جاهزة'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pr in schemaPresets)
                ChoiceChip(
                  avatar: Icon(tableIcon(pr.icon), size: 18),
                  label: Text(pr.name),
                  selected: _schemaPreset == pr.id,
                  onSelected: (_) => setState(() {
                    _schemaPreset = pr.id;
                    _schemaTouched = true;
                    _schema = pr.build();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _aiBusy ? null : _designWithAi,
            icon: _aiBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded, color: AlphaColors.amber),
            label: Text(_aiBusy ? 'يصمّم الجداول…' : 'صمّم الجداول من الفهم'),
          ),
          const SizedBox(height: 8),
          if (_schema.tables.isEmpty)
            const GlassCard(child: Text('بدون جداول: يمكنك إضافتها لاحقاً من استوديو البيانات.', style: TextStyle(color: AlphaColors.muted))),
          for (final t in _schema.tables)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(tableIcon(t.icon), color: AlphaColors.teal),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Pill(t.owner.label, color: AlphaColors.blue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in t.columns)
                        Pill('${c.label}${c.adminOnly ? ' (للإدارة)' : ''}', color: c.required ? AlphaColors.violet : AlphaColors.muted),
                    ],
                  ),
                  if (t.notifyOnInsert != NotifyTarget.none || t.notifyOnUpdate != NotifyTarget.none) ...[
                    const SizedBox(height: 8),
                    Text(
                      'إشعار عند الإضافة: ${t.notifyOnInsert.label} · عند التعديل: ${t.notifyOnUpdate.label}',
                      style: const TextStyle(color: AlphaColors.pink, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );

  Widget _serverStep() {
    final backends = BackendType.values.where((b) => b != BackendType.firebase || _lang.supportsFirestore).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('السيرفر والصلاحيات', subtitle: 'Alpha يكتب SQL الجداول والصلاحيات RLS والأدوار تلقائياً'),
        if (_clientDb)
          GlassCard(
            gradient: LinearGradient(colors: [AlphaColors.amber.withValues(alpha: 0.22), AlphaColors.teal.withValues(alpha: 0.08)]),
            child: Row(children: [
              const Icon(Icons.person_pin_rounded, color: AlphaColors.amber, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('قاعدة بيانات الزبون: ${widget.clientName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Supabase · ${widget.clientRef} — الجداول والصلاحيات والدخول تُجهَّز فيها، منفصلة عن مشروعك',
                      style: const TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.5)),
                ]),
              ),
            ]),
          ),
        if (!_clientDb)
        for (final b in backends)
          GlassCard(
            onTap: _pair && b == BackendType.none ? null : () => setState(() => _backend = b),
            gradient: _backend == b ? LinearGradient(colors: [AlphaColors.teal.withValues(alpha: 0.28), AlphaColors.blue.withValues(alpha: 0.1)]) : null,
            child: Row(
              children: [
                Icon(switch (b) { BackendType.none => Icons.phone_android_rounded, BackendType.supabase => Icons.bolt_rounded, BackendType.firebase => Icons.local_fire_department_rounded },
                    color: _pair && b == BackendType.none ? AlphaColors.muted : AlphaColors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(_lang == Lang.php && b == BackendType.none ? 'قاعدة SQLite على سيرفر PHP' : b.hint,
                          style: const TextStyle(color: AlphaColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(_backend == b ? Icons.check_circle_rounded : Icons.circle_outlined, color: _backend == b ? AlphaColors.teal : AlphaColors.muted),
              ],
            ),
          ),
        if (_backend != BackendType.none || _lang == Lang.php) ...[
          const SectionTitle('تسجيل الدخول'),
          RadioGroup<AuthMode>(
            groupValue: _auth,
            onChanged: (v) => setState(() => _auth = v!),
            child: Column(
              children: [
                for (final a in AuthMode.values)
                  RadioListTile<AuthMode>(
                    contentPadding: EdgeInsets.zero,
                    value: a,
                    title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(a.hint, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (_auth == AuthMode.emailCode)
            const Text('للرموز الحقيقية للعملاء أضف خادم البريد في الإعدادات > البريد (Gmail يعمل). بدونه يرسل Supabase رموزاً قليلة في الساعة.',
                style: TextStyle(color: AlphaColors.amber, fontSize: 12, height: 1.5)),
        ],
        if (_backend != BackendType.none && _lang.supportsPush)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _push,
            onChanged: (v) => setState(() => _push = v),
            title: const Text('إشعارات Push بين التطبيقين', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('طلب جديد ← الإدارة، تغيير الحالة ← العميل (Firebase Cloud Messaging)', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
          ),
        if (_backend != BackendType.none || _lang == Lang.php) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _admins,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: _pair ? 'بريد المدير (لتطبيق الإدارة)' : 'بريد المدير (اختياري)',
              helperText: 'أكثر من بريد: افصل بفاصلة',
              prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewStep() {
    final p = _build();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('جاهز للبناء',
            trailing: TextButton.icon(onPressed: _preview, icon: const Icon(Icons.play_circle_rounded), label: const Text('معاينة فورية'))),
        Center(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final a in p.apps)
                Column(
                  children: [
                    PhonePreview(theme: p.theme, title: a.title, schema: p.schema, role: a.role, width: _pair ? 150 : 190),
                    const SizedBox(height: 8),
                    Text(a.roleLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _row('لمين', p.forClient ? 'الزبون: ${p.clientName}${p.supabaseRef.isNotEmpty ? ' (قاعدة بياناته ${p.supabaseRef})' : ''}' : 'لي (المشروع الأساسي)'),
              _row('اللغة', p.lang.label),
              _row('التطبيقات', p.apps.map((a) => a.slug).join('، ')),
              _row('الجداول', p.schema.tables.isEmpty ? 'لا شيء' : p.schema.tables.map((t) => t.label).join('، ')),
              _row('السيرفر', p.backend == BackendType.none && p.lang == Lang.php ? 'SQLite على السيرفر' : p.backend.label),
              _row('الدخول', p.auth.label),
              _row('الإشعارات', p.push ? 'Push + داخل التطبيق' : (p.backend == BackendType.none ? 'لا' : 'داخل التطبيق')),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'عند الإنشاء: تُكتب الملفات في المستودع بـ commit واحد، ثم يُجهَّز السيرفر (SQL + الصلاحيات + الإشعارات) ويُبنى الـ APK في GitHub Actions.',
          style: TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AlphaColors.muted))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

/// Progress as segments with the step names under them (APK Fact's design language): done = violet, now = gradient.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.steps, required this.current, required this.onTap});
  final List<String> steps;
  final int current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: i == current ? AlphaColors.aurora : null,
                      color: i == current ? null : (i < current ? AlphaColors.violet.withValues(alpha: 0.55) : AlphaColors.line),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    child: Text(steps[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                          color: i == current ? AlphaColors.text : AlphaColors.muted,
                        )),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      );
}
