import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/presets.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
import '../widgets.dart';
import 'design_studio.dart';
import 'project.dart';

/// New project in six steps: language, name, design, data, server, review.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key, required this.kind});
  final ProjectKind kind;

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
  ThemeSpec _theme = themePresets.first.toSpec();
  DbSchema _schema = schemaPresets.first.build();
  String _schemaPreset = schemaPresets.first.id;
  BackendType _backend = BackendType.none;
  AuthMode _auth = AuthMode.none;
  bool _push = false;
  bool _busy = false;
  bool _aiBusy = false;

  bool get _pair => widget.kind == ProjectKind.pair;

  static const _steps = ['اللغة', 'الاسم', 'التصميم', 'البيانات', 'السيرفر', 'المراجعة'];

  @override
  void initState() {
    super.initState();
    if (_pair) {
      _backend = BackendType.supabase;
      _auth = AuthMode.emailPassword;
      _push = true;
    }
  }

  String? _stepError() {
    switch (_step) {
      case 1:
        if (_title.text.trim().isEmpty) return 'اكتب اسم التطبيق';
        final slug = slugApp(_slug.text);
        if (slug != _slug.text.trim()) return 'المعرّف بالإنجليزي الصغير والأرقام و - فقط (مثلاً: $slug)';
        if (context.read<AppState>().projects.any((p) => p.base == slug)) return 'يوجد مشروع بنفس المعرّف';
        return null;
      case 3:
        final errors = _schema.validate();
        return errors.isEmpty ? null : errors.first;
      case 4:
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
    if (_step < _steps.length - 1) setState(() => _step++);
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
      kind: widget.kind,
      description: _desc.text.trim(),
      theme: _theme,
      schema: _schema,
      backend: _backend,
      auth: _auth,
      push: _push && _backend != BackendType.none && _lang.supportsPush,
      admins: _admins.text.split(RegExp(r'[,\s]+')).where((e) => e.contains('@')).toList(),
      apps: Project.unitsFor(base, title, widget.kind),
    );
  }

  Future<void> _create() async {
    final s = context.read<AppState>();
    final p = _build();
    setState(() => _busy = true);
    try {
      await s.save(p, message: 'Alpha: new project ${p.title}');
      var note = 'تم إنشاء المشروع';
      if (s.hasGitHub) {
        if (p.backend == BackendType.none) {
          await s.buildAll(p);
          note = 'تم الإنشاء وبدأ البناء في GitHub Actions';
        } else if ((p.backend == BackendType.supabase && s.hasSupabase && s.supabaseRef.isNotEmpty) ||
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

  Future<void> _designWithAi() async {
    final s = context.read<AppState>();
    final ai = await s.ai();
    if (!ai.available) {
      if (mounted) showMessage(context, 'أضف مفتاح Claude أو Gemini في الإعدادات', error: true);
      return;
    }
    final text = _desc.text.trim().isEmpty ? _title.text.trim() : _desc.text.trim();
    if (text.isEmpty) {
      if (mounted) showMessage(context, 'اكتب وصف التطبيق في خطوة الاسم أولاً', error: true);
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final schema = await ai.designSchema(text, pair: _pair);
      if (schema.tables.isEmpty) throw Exception('لم يقترح الذكاء الاصطناعي جداول، جرّب وصفاً أوضح');
      setState(() {
        _schema = schema;
        _schemaPreset = 'ai';
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pair ? 'تطبيقين متصلين' : 'تطبيق جديد')),
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
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
        1 => _nameStep(),
        2 => _designStep(),
        3 => _dataStep(),
        4 => _serverStep(),
        _ => _reviewStep(),
      };

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
                        Text(l.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
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
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'وصف النشاط (يستخدمه الذكاء الاصطناعي لتصميم الجداول)',
              alignLabelWithHint: true,
              hintText: 'مثال: مخبز يستقبل طلبات التوصيل، العميل يطلب ويتابع الحالة والإدارة تغيّر الحالة وتضيف المنتجات',
            ),
          ),
        ],
      );

  Widget _designStep() => DesignEditor(
        theme: _theme,
        title: _title.text,
        schema: _schema,
        pair: _pair,
        onChanged: (t) => setState(() => _theme = t),
      );

  Widget _dataStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('قاعدة البيانات', subtitle: 'اختر بداية جاهزة أو دع الذكاء الاصطناعي يصمّمها؛ تعدّلها لاحقاً في استوديو البيانات'),
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
            label: Text(_aiBusy ? 'يصمّم الجداول…' : 'صمّم الجداول بالذكاء الاصطناعي من الوصف'),
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
        const SectionTitle('جاهز للبناء'),
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

class _Stepper extends StatefulWidget {
  const _Stepper({required this.steps, required this.current, required this.onTap});
  final List<String> steps;
  final int current;
  final void Function(int) onTap;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final _keys = List.generate(widget.steps.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant _Stepper old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.current].currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 300));
      });
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              for (var i = 0; i < widget.steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                GestureDetector(
                  key: _keys[i],
                  onTap: () => widget.onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: i == widget.current ? AlphaColors.aurora : null,
                      color: i == widget.current
                          ? null
                          : (i < widget.current ? AlphaColors.violet.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        if (i < widget.current) const Icon(Icons.check_rounded, size: 16, color: AlphaColors.teal),
                        if (i < widget.current) const SizedBox(width: 4),
                        Text('${i + 1}. ${widget.steps[i]}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: i == widget.current ? Colors.white : AlphaColors.muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
