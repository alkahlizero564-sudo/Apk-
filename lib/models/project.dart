import 'dart:convert';

import 'schema.dart';

enum Lang {
  html('html', 'HTML', 'HTML · CSS · JavaScript + Capacitor', 0xFFF06529),
  php('php', 'PHP', 'PHP 8.3 · PDO · سيرفر + تطبيق أندرويد', 0xFF777BB4),
  flutter('flutter', 'Flutter', 'Dart · Material 3 · Firebase · Supabase', 0xFF42A5F5),
  python('python', 'Python', 'Flet 1.0 · Material 3 · requests', 0xFFFFD43B),
  kotlin('kotlin', 'Kotlin', 'Jetpack Compose · Material 3 · OkHttp', 0xFFA97BFF);

  const Lang(this.id, this.label, this.stack, this.color);
  final String id;
  final String label;
  final String stack;
  final int color;

  static Lang parse(String? v) => Lang.values.firstWhere((l) => l.id == v, orElse: () => Lang.flutter);

  String get workflow => 'build-$id.yml';

  /// Firestore as the database needs the official SDK: only Flutter and HTML engines have it.
  bool get supportsFirestore => this == Lang.flutter || this == Lang.html;

  /// Push notifications (FCM) on the phone.
  bool get supportsPush => this != Lang.python;
}

enum ProjectKind { single, pair }

enum BackendType {
  none('none', 'بدون سيرفر', 'البيانات محفوظة في الجهاز'),
  supabase('supabase', 'Supabase', 'PostgreSQL + صلاحيات RLS + تسجيل دخول + إشعارات'),
  firebase('firebase', 'Firebase', 'Firestore + Auth + قواعد أمان + FCM');

  const BackendType(this.id, this.label, this.hint);
  final String id;
  final String label;
  final String hint;

  static BackendType parse(String? v) =>
      BackendType.values.firstWhere((b) => b.id == v, orElse: () => BackendType.none);
}

enum AuthMode {
  none('none', 'بدون تسجيل دخول', 'حساب مخفي لكل جهاز'),
  emailPassword('email_password', 'بريد + كلمة مرور', 'حساب بالاسم والهاتف والبريد وكلمة مرور'),
  emailCode('email_code', 'بريد + رمز تأكيد', 'حساب بالاسم والهاتف والبريد، ورمز من 6 أرقام يصل للبريد قبل الدخول');

  bool get needsAccount => this != AuthMode.none;

  const AuthMode(this.id, this.label, this.hint);
  final String id;
  final String label;
  final String hint;

  static AuthMode parse(String? v) => AuthMode.values.firstWhere((a) => a.id == v, orElse: () => AuthMode.none);
}

/// How the app code is made: Alpha's tested engine (no AI, no errors) or code written by AI on top of it.
enum CodeMode { engine, ai }

class ThemeSpec {
  ThemeSpec({
    this.preset = 'aurora',
    this.seed = '#6E4BFF',
    this.accent = '#2DD4BF',
    this.mode = 'dark',
    this.style = 'glass',
    this.radius = 18,
    this.layout = 'tabs',
  });

  String preset;
  String seed;
  String accent;
  String mode; // dark | light | system
  String style; // glass | soft | flat
  double radius;
  String layout; // tabs | drawer

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'seed': seed,
        'accent': accent,
        'mode': mode,
        'style': style,
        'radius': radius,
        'layout': layout,
      };

  factory ThemeSpec.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return ThemeSpec(
      preset: '${j['preset'] ?? 'aurora'}',
      seed: '${j['seed'] ?? '#6E4BFF'}',
      accent: '${j['accent'] ?? '#2DD4BF'}',
      mode: '${j['mode'] ?? 'dark'}',
      style: '${j['style'] ?? 'glass'}',
      radius: (j['radius'] as num?)?.toDouble() ?? 18,
      layout: '${j['layout'] ?? 'tabs'}',
    );
  }
}

/// One installable app (a single project has one, a pair has customer + admin).
class AppUnit {
  AppUnit({required this.slug, required this.role, required this.title});
  String slug; // folder under apps/
  String role; // single | customer | admin
  String title; // the name under the icon

  Map<String, dynamic> toJson() => {'slug': slug, 'role': role, 'title': title};
  factory AppUnit.fromJson(Map<String, dynamic> j) =>
      AppUnit(slug: '${j['slug']}', role: '${j['role'] ?? 'single'}', title: '${j['title'] ?? j['slug']}');

  String get roleLabel => switch (role) { 'customer' => 'تطبيق العميل', 'admin' => 'تطبيق الإدارة', _ => 'التطبيق' };
}

class Project {
  Project({
    required this.id,
    required this.base,
    required this.title,
    required this.lang,
    required this.kind,
    this.description = '',
    ThemeSpec? theme,
    DbSchema? schema,
    this.backend = BackendType.none,
    this.auth = AuthMode.none,
    this.push = false,
    this.codeMode = CodeMode.engine,
    this.admins = const [],
    this.serverUrl = '',
    this.headline = '',
    this.subtitle = '',
    List<AppUnit>? apps,
    DateTime? createdAt,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.supabaseRef = '',
    this.brief = '',
    this.customCode = '',
  })  : theme = theme ?? ThemeSpec(),
        schema = schema ?? DbSchema(),
        apps = apps ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String base; // slug, e.g. "bakery"
  String title;
  Lang lang;
  ProjectKind kind;
  String description;
  ThemeSpec theme;
  DbSchema schema;
  BackendType backend;
  AuthMode auth;
  bool push;
  CodeMode codeMode;
  List<String> admins;
  String serverUrl; // PHP: where the PHP code is hosted (the APK opens it)
  String headline;
  String subtitle;
  List<AppUnit> apps;
  DateTime createdAt;

  // Filled by the backend workflow (or by Alpha when it sets Supabase up directly).
  String supabaseUrl;
  String supabaseAnonKey;
  String supabaseRef;

  /// The approved understanding (step "الفهم"): every later step and the AI code work from it.
  String brief;

  /// Code the owner pasted: it becomes the app's own code (custom/), the build fixes it if needed.
  String customCode;

  /// Prefix of every table of this project, so many projects can share one Supabase / Firebase project.
  String get prefix => slugIdent(base, fallback: 'app');

  bool get isPair => kind == ProjectKind.pair;

  Map<String, dynamic> toJson() => {
        'id': id,
        'base': base,
        'title': title,
        'lang': lang.id,
        'kind': kind.name,
        'description': description,
        'theme': theme.toJson(),
        'schema': schema.toJson(),
        'backend': backend.id,
        'auth': auth.id,
        'push': push,
        'codeMode': codeMode.name,
        'admins': admins,
        'serverUrl': serverUrl,
        'headline': headline,
        'subtitle': subtitle,
        'apps': apps.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'supabaseRef': supabaseRef,
        if (brief.isNotEmpty) 'brief': brief,
        if (customCode.isNotEmpty) 'customCode': customCode,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: '${j['id']}',
        base: '${j['base']}',
        title: '${j['title'] ?? j['base']}',
        lang: Lang.parse(j['lang'] as String?),
        kind: j['kind'] == 'pair' ? ProjectKind.pair : ProjectKind.single,
        description: '${j['description'] ?? ''}',
        theme: ThemeSpec.fromJson((j['theme'] as Map?)?.cast<String, dynamic>()),
        schema: DbSchema.fromJson(j['schema'] as List?),
        backend: BackendType.parse(j['backend'] as String?),
        auth: AuthMode.parse(j['auth'] as String?),
        push: j['push'] == true,
        codeMode: j['codeMode'] == 'ai' ? CodeMode.ai : CodeMode.engine,
        admins: ((j['admins'] as List?) ?? const []).map((e) => '$e').toList(),
        serverUrl: '${j['serverUrl'] ?? ''}',
        headline: '${j['headline'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        apps: ((j['apps'] as List?) ?? const []).map((e) => AppUnit.fromJson((e as Map).cast<String, dynamic>())).toList(),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        supabaseUrl: '${j['supabaseUrl'] ?? ''}',
        supabaseAnonKey: '${j['supabaseAnonKey'] ?? ''}',
        supabaseRef: '${j['supabaseRef'] ?? ''}',
        brief: '${j['brief'] ?? ''}',
        customCode: '${j['customCode'] ?? ''}',
      );

  String encode() => jsonEncode(toJson());

  /// The apps of this project, made from its kind.
  static List<AppUnit> unitsFor(String base, String title, ProjectKind kind) => kind == ProjectKind.single
      ? [AppUnit(slug: base, role: 'single', title: title)]
      : [
          AppUnit(slug: '$base-customer', role: 'customer', title: title),
          AppUnit(slug: '$base-admin', role: 'admin', title: '$title - الإدارة'),
        ];
}

/// apps/<slug> folder names: lowercase letters, digits and dashes (same rule as the build workflows).
String slugApp(String input) {
  var s = input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-');
  s = s.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'app-$s'.replaceAll(RegExp(r'-$'), '');
  if (s.length > 30) s = s.substring(0, 30).replaceAll(RegExp(r'-$'), '');
  return s;
}
