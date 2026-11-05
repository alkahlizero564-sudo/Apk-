import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/ai_edit.dart';
import '../../models/project.dart';
import '../widgets.dart';
import 'preview.dart';

/// Change an app that is already built (and installed) by writing what you want: the AI proposes, Alpha shows exactly
/// what will be added, removed or changed, and on «طبّق» it saves, updates the server and rebuilds; the installed apps
/// then get «تحديث جديد» and update in place.
class AiEditScreen extends StatefulWidget {
  const AiEditScreen({super.key, required this.project});
  final Project project;

  @override
  State<AiEditScreen> createState() => _AiEditScreenState();
}

const _ideas = [
  'أضف حقل صورة للمنتجات واجعل القائمة شبكة صور',
  'أضف قسم تقييمات: النجوم والتعليق، وأرسل إشعاراً للإدارة',
  'احذف حقل العنوان من الطلبات',
  'غيّر الألوان إلى أخضر وذهبي واجعل التصميم Glassmorphism',
  'أضف حالة «في الطريق» لحالة الطلب',
  'اجعل التسجيل بالبريد مع رمز تأكيد',
  'أضف سلة مشتريات وزر طلب عبر واتساب',
];

class _AiEditScreenState extends State<AiEditScreen> {
  final _text = TextEditingController();
  bool _thinking = false;
  bool _applying = false;
  AiEdit? _edit;
  Project? _draft;
  List<Change> _changes = const [];
  List<Map<String, dynamic>> _history = const [];
  String _codeTarget = 'all';

  Project get _p => context.read<AppState>().byId(widget.project.id) ?? widget.project;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await context.read<AppState>().edits(widget.project);
    if (mounted) setState(() => _history = h);
  }

  Future<void> _plan() async {
    final request = _text.text.trim();
    if (request.isEmpty) return showMessage(context, 'اكتب ما تريد تغييره', error: true);
    FocusScope.of(context).unfocus();
    setState(() {
      _thinking = true;
      _edit = null;
    });
    try {
      final ai = await context.read<AppState>().ai();
      final p = _p;
      final edit = await ai.planEdit(p, request);
      final draft = edit.applyTo(p);
      final errors = draft.schema.validate();
      if (errors.isNotEmpty) throw Exception('الاقتراح فيه مشكلة في البيانات:\n${errors.join('\n')}\nجرّب صياغة أوضح.');
      if (!mounted) return;
      setState(() {
        _edit = edit;
        _draft = draft;
        _changes = describeChanges(p, draft);
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _apply() async {
    final edit = _edit, draft = _draft;
    if (edit == null || draft == null) return;
    setState(() => _applying = true);
    try {
      final s = context.read<AppState>();
      final apps = _codeTarget == 'all' ? draft.apps : draft.apps.where((a) => a.slug == _codeTarget).toList();
      final msg = await s.applyEdit(_p, draft, edit, codeApps: apps);
      if (!mounted) return;
      showMessage(context, msg);
      setState(() {
        _edit = null;
        _draft = null;
        _text.clear();
      });
      await _loadHistory();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _undo() async {
    final last = _history.isEmpty ? null : _history.first;
    if (last == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تراجع عن آخر تعديل؟'),
        content: Text('يرجع التطبيق كما كان قبل:\n«${last['request']}»\nثم يُبنى من جديد ويصل التحديث للتطبيقات المثبتة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تراجع')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _applying = true);
    try {
      final msg = await context.read<AppState>().undoEdit(_p);
      if (mounted) showMessage(context, msg);
      await _loadHistory();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().byId(widget.project.id) ?? widget.project;
    final edit = _edit;
    return Scaffold(
      appBar: AppBar(title: const Text('عدّل تطبيقك بالذكاء')),
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              GlassCard(
                child: Row(children: [
                  const Icon(Icons.system_update_rounded, color: AlphaColors.teal, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'اكتب ما تريد في «${p.title}»: إضافة أو حذف أو تعديل. ترى كل تغيير قبل تطبيقه، ثم يُحدَّث السيرفر ويُبنى التطبيق، '
                      'وتصل التحديثات للتطبيقات المثبتة على الهواتف (يظهر فيها «تحديث جديد»).',
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'مثال: أضف قسم عروض فيه صورة وسعر قبل وبعد، واحذف قسم الحجوزات'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final idea in _ideas)
                  ActionChip(
                    label: Text(idea, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _text.text = _text.text.trim().isEmpty ? idea : '${_text.text.trim()}، و$idea'),
                  ),
              ]),
              const SizedBox(height: 12),
              GradientButton(label: _thinking ? 'يفهم طلبك…' : 'اقترح التعديل', icon: Icons.auto_awesome_rounded, busy: _thinking, onPressed: _thinking ? null : _plan),
              if (edit != null) ..._proposal(p, edit),
              if (_history.isNotEmpty) ...[
                SectionTitle('آخر التعديلات',
                    trailing: TextButton.icon(onPressed: _applying ? null : _undo, icon: const Icon(Icons.undo_rounded, size: 18), label: const Text('تراجع'))),
                for (final h in _history.take(6))
                  GlassCard(
                    child: Row(children: [
                      const Icon(Icons.history_rounded, color: AlphaColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${h['request']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_when('${h['at']}'), style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _when(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'الآن';
    if (m < 60) return 'قبل $m دقيقة';
    if (m < 1440) return 'قبل ${m ~/ 60} ساعة';
    return '${d.year}/${d.month}/${d.day}';
  }

  List<Widget> _proposal(Project p, AiEdit edit) {
    final nothing = _changes.isEmpty && edit.codeRequest.isEmpty;
    return [
      const SectionTitle('التعديل المقترح'),
      GlassCard(
        gradient: LinearGradient(colors: [AlphaColors.violet.withValues(alpha: 0.22), AlphaColors.teal.withValues(alpha: 0.08)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (edit.summary.isNotEmpty) Text(edit.summary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.6)),
            if (nothing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('لم يجد الذكاء الاصطناعي شيئاً يتغيّر. أعد صياغة الطلب بتفصيل أكثر.', style: TextStyle(color: AlphaColors.amber)),
              ),
            const SizedBox(height: 6),
            for (final c in _changes) _ChangeRow(c),
            if (edit.codeRequest.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AlphaColors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.code_rounded, color: AlphaColors.amber, size: 18),
                    SizedBox(width: 6),
                    Text('يحتاج كوداً مخصصاً', style: TextStyle(fontWeight: FontWeight.w800, color: AlphaColors.amber)),
                  ]),
                  const SizedBox(height: 4),
                  Text(edit.codeRequest, style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 4),
                  const Text('يكتبه الذكاء الاصطناعي فوق التطبيق (البيانات والدخول والإشعارات تبقى) ويصلح أي خطأ في البناء.',
                      style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
                  if (p.apps.length > 1) ...[
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 'all', label: Text('الاثنين')),
                        for (final a in p.apps) ButtonSegment(value: a.slug, label: Text(a.roleLabel)),
                      ],
                      selected: {_codeTarget},
                      onSelectionChanged: (v) => setState(() => _codeTarget = v.first),
                    ),
                  ],
                ]),
              ),
            ],
            for (final q in edit.questions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.help_outline_rounded, size: 18, color: AlphaColors.blue),
                  const SizedBox(width: 6),
                  Expanded(child: Text(q, style: const TextStyle(fontSize: 13))),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _draft == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(project: _draft!))),
            icon: const Icon(Icons.play_circle_rounded, color: AlphaColors.teal),
            label: const Text('معاينة'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GradientButton(
            label: 'طبّق وحدّث التطبيقات',
            icon: Icons.system_update_alt_rounded,
            busy: _applying,
            onPressed: nothing || _applying ? null : _apply,
          ),
        ),
      ]),
      TextButton(onPressed: () => setState(() => _edit = null), child: const Text('إلغاء هذا الاقتراح')),
    ];
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow(this.change);
  final Change change;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (change.kind) {
      ChangeKind.add => (Icons.add_circle_rounded, AlphaColors.ok),
      ChangeKind.remove => (Icons.remove_circle_rounded, AlphaColors.bad),
      ChangeKind.change => (Icons.edit_rounded, AlphaColors.amber),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(change.text, style: const TextStyle(fontSize: 13.5, height: 1.5))),
        if (change.warning) const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.warning_amber_rounded, color: AlphaColors.amber, size: 18)),
      ]),
    );
  }
}
