// Editing an existing app with AI: the AI proposes the new state, Alpha applies it to a copy of the project and
// works out itself what really changed (so the owner sees exactly what will happen before anything is saved).

import '../models/project.dart';
import '../models/schema.dart';
import 'presets.dart';

/// What the AI proposed for one request.
class AiEdit {
  AiEdit({
    required this.request,
    this.summary = '',
    this.notes = const [],
    this.title,
    this.headline,
    this.subtitle,
    this.theme = const {},
    this.tables,
    this.auth,
    this.push,
    this.codeRequest = '',
    this.questions = const [],
  });

  final String request;
  final String summary;
  final List<String> notes;
  final String? title;
  final String? headline;
  final String? subtitle;
  final Map<String, dynamic> theme; // only the parts to change
  final List<dynamic>? tables; // the whole new list of tables, or null when the data does not change
  final String? auth;
  final bool? push;
  final String codeRequest; // screens or behaviour the engine cannot express: written as code by the AI build
  final List<String> questions;

  factory AiEdit.fromJson(String request, Map<String, dynamic> j) {
    List<String> strings(Object? v) => (v as List? ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    String? text(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    return AiEdit(
      request: request,
      summary: '${j['summary'] ?? ''}',
      notes: strings(j['changes']),
      title: text(j['title']),
      headline: text(j['headline']),
      subtitle: text(j['subtitle']),
      theme: (j['theme'] as Map?)?.cast<String, dynamic>() ?? const {},
      tables: j['tables'] is List ? j['tables'] as List : null,
      auth: text(j['auth']),
      push: j['push'] is bool ? j['push'] as bool : null,
      codeRequest: '${j['code_request'] ?? ''}'.trim(),
      questions: strings(j['questions']),
    );
  }

  /// A copy of [p] with the proposal applied (the original is untouched).
  Project applyTo(Project p) {
    final d = Project.fromJson(p.toJson());
    if (title != null) d.title = title!;
    if (headline != null) d.headline = headline!;
    if (subtitle != null) d.subtitle = subtitle!;
    final t = theme;
    if (t.isNotEmpty) {
      var spec = d.theme;
      final school = lookById('${t['school'] ?? ''}');
      if (school != null && school.id != spec.school) spec = school.apply(spec, keepColors: true);
      String? hex(Object? v) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('$v') ? '$v'.toUpperCase() : null;
      String? one(Object? v, Map<String, String> ok) => v != null && ok.containsKey('$v') ? '$v' : null;
      spec = spec.copyWith(
        seed: hex(t['seed']),
        accent: hex(t['accent']),
        mode: const ['dark', 'light', 'system'].contains(t['mode']) ? '${t['mode']}' : null,
        home: one(t['home'], homeLayouts),
        list: one(t['list'], listStyles),
        nav: one(t['nav'], navStyles),
        sheet: one(t['sheet'], sheetStyles),
        font: one(t['font'], fontChoices),
        onboarding: t['onboarding'] is bool ? t['onboarding'] as bool : null,
        radius: (t['radius'] as num?)?.toDouble().clamp(0, 40),
      );
      if (hex(t['seed']) != null || hex(t['accent']) != null) spec = spec.copyWith(preset: 'custom');
      d.theme = spec;
    }
    if (tables != null) d.schema = DbSchema.fromJson(tables);
    if (auth != null) d.auth = AuthMode.parse(auth);
    if (push != null) d.push = push!;
    if (request.trim().isNotEmpty) {
      // The understanding grows with every change, so the next AI step (and the AI code) knows the app as it is now.
      d.brief = '${d.brief.trim()}\n- تعديل: ${request.trim()}'.trim();
    }
    return d;
  }
}

enum ChangeKind { add, remove, change }

class Change {
  const Change(this.kind, this.text, {this.warning = false});
  final ChangeKind kind;
  final String text;
  final bool warning; // e.g. hiding a column that has data

  @override
  String toString() => '${kind.name}: $text';
}

String _colType(DbColumn c) => c.type.label;

/// Everything that differs between two versions of a project, in words the owner understands.
List<Change> describeChanges(Project a, Project b) {
  final out = <Change>[];
  void ch(String what, Object? x, Object? y) {
    if ('$x' != '$y') out.add(Change(ChangeKind.change, '$what: «$x» ← «$y»'));
  }

  ch('اسم التطبيق', a.title, b.title);
  ch('العنوان الكبير', a.headline, b.headline);
  ch('السطر الثاني', a.subtitle, b.subtitle);
  final ta = a.theme, tb = b.theme;
  if (ta.school != tb.school) {
    out.add(Change(ChangeKind.change, 'مدرسة التصميم: ${lookById(ta.school.isEmpty ? ta.look : ta.school)?.name ?? '-'} ← ${lookById(tb.school)?.name ?? tb.school}'));
  }
  ch('اللون الأساسي', ta.seed, tb.seed);
  ch('اللون الثاني', ta.accent, tb.accent);
  if (ta.mode != tb.mode) out.add(Change(ChangeKind.change, 'الوضع: ${tb.mode == 'light' ? 'فاتح' : tb.mode == 'dark' ? 'داكن' : 'حسب الهاتف'}'));
  if (ta.home != tb.home) out.add(Change(ChangeKind.change, 'الشاشة الرئيسية: ${homeLayouts[tb.home] ?? tb.home}'));
  if (ta.list != tb.list) out.add(Change(ChangeKind.change, 'شكل القوائم: ${listStyles[tb.list] ?? tb.list}'));
  if (ta.nav != tb.nav) out.add(Change(ChangeKind.change, 'شريط التنقل: ${navStyles[tb.nav] ?? tb.nav}'));
  if (ta.sheet != tb.sheet) out.add(Change(ChangeKind.change, 'التفاصيل تفتح في: ${sheetStyles[tb.sheet] ?? tb.sheet}'));
  if (ta.font != tb.font) out.add(Change(ChangeKind.change, 'الخط: ${fontChoices[tb.font] ?? tb.font}'));
  if (ta.onboarding != tb.onboarding) out.add(Change(tb.onboarding ? ChangeKind.add : ChangeKind.remove, 'شاشات الترحيب'));
  if (a.auth != b.auth) out.add(Change(ChangeKind.change, 'تسجيل الدخول: ${b.auth.label}'));
  if (a.push != b.push) out.add(Change(b.push ? ChangeKind.add : ChangeKind.remove, 'الإشعارات حتى والتطبيق مغلق'));

  final oldTables = {for (final t in a.schema.tables) t.name: t};
  final newTables = {for (final t in b.schema.tables) t.name: t};
  for (final t in b.schema.tables) {
    final o = oldTables[t.name];
    if (o == null) {
      out.add(Change(ChangeKind.add, 'قسم جديد «${t.label}»: ${t.columns.map((c) => c.label).join('، ')}'));
      continue;
    }
    if (o.label != t.label) out.add(Change(ChangeKind.change, 'اسم القسم «${o.label}» ← «${t.label}»'));
    if (o.owner != t.owner) out.add(Change(ChangeKind.change, 'صلاحيات «${t.label}»: ${t.owner.label}', warning: true));
    if (o.icon != t.icon) out.add(Change(ChangeKind.change, 'أيقونة «${t.label}»'));
    if (o.notifyOnInsert != t.notifyOnInsert || o.notifyOnUpdate != t.notifyOnUpdate) {
      out.add(Change(ChangeKind.change, 'إشعارات «${t.label}»: عند الإضافة ← ${t.notifyOnInsert.label}، عند التعديل ← ${t.notifyOnUpdate.label}'));
    }
    final oc = {for (final c in o.columns) c.name: c};
    final nc = {for (final c in t.columns) c.name: c};
    for (final c in t.columns) {
      final x = oc[c.name];
      if (x == null) {
        out.add(Change(ChangeKind.add, 'حقل «${c.label}» (${_colType(c)}) في «${t.label}»${c.required ? '، مطلوب' : ''}'));
      } else {
        final parts = <String>[
          if (x.label != c.label) 'الاسم «${x.label}» ← «${c.label}»',
          if (x.type != c.type) 'النوع ${_colType(x)} ← ${_colType(c)}',
          if (x.required != c.required) c.required ? 'صار مطلوباً' : 'صار اختيارياً',
          if (x.options.join('|') != c.options.join('|')) 'الخيارات: ${c.options.join('، ')}',
          if (x.adminOnly != c.adminOnly) c.adminOnly ? 'للإدارة فقط' : 'يعدّله العميل',
          if (x.showInList != c.showInList) c.showInList ? 'يظهر في القائمة' : 'يختفي من القائمة',
          if ((x.defaultValue ?? '') != (c.defaultValue ?? '')) 'القيمة الافتراضية «${c.defaultValue ?? ''}»',
        ];
        if (parts.isNotEmpty) {
          out.add(Change(ChangeKind.change, 'حقل «${c.label}» في «${t.label}»: ${parts.join('، ')}', warning: x.type != c.type));
        }
      }
    }
    for (final c in o.columns) {
      if (!nc.containsKey(c.name)) {
        out.add(Change(ChangeKind.remove, 'حقل «${c.label}» من «${t.label}» (يختفي من التطبيق، وبياناته تبقى محفوظة في السيرفر)', warning: true));
      }
    }
  }
  for (final t in a.schema.tables) {
    if (!newTables.containsKey(t.name)) {
      out.add(Change(ChangeKind.remove, 'قسم «${t.label}» (يختفي من التطبيق، وبياناته تبقى محفوظة في السيرفر)', warning: true));
    }
  }
  return out;
}

/// Whether the server needs the new tables / columns / permissions.
bool needsServer(Project a, Project b) =>
    b.backend != BackendType.none &&
    (a.auth != b.auth || a.push != b.push || '${a.schema.toJson()}' != '${b.schema.toJson()}');
