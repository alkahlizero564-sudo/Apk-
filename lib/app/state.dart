import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../generator/app_files.dart';
import '../generator/custom_code.dart';
import '../generator/ai_edit.dart';
import '../models/project.dart';
import '../services/ai.dart';
import '../services/github.dart';
import '../services/installer.dart';
import '../services/storage.dart';
import '../services/supabase_admin.dart';

class BuildInfo {
  BuildInfo(Map<String, dynamic> j)
      : version = '${j['name'] ?? ''}',
        apk = '${j['apk'] ?? ''}',
        at = DateTime.tryParse('${j['at']}')?.toLocal();
  final String version;
  final String apk;
  final DateTime? at;
}

/// Everything Alpha knows: settings, projects, builds. Screens listen to it.
class AppState extends ChangeNotifier {
  static const defaultRepo = 'alkahlizero564-sudo/Apk-';

  List<Project> projects = [];
  String repo = defaultRepo;
  String branch = '';
  String githubUser = '';
  bool hasGitHub = false;
  bool hasAi = false;
  bool hasSupabase = false;
  bool hasFirebase = false;
  String supabaseRef = '';
  List<WorkflowRun> runs = [];
  final Map<String, BuildInfo> builds = {};
  final Map<String, Map<String, dynamic>> serverStatus = {};
  bool loading = true;
  String? error;

  /// This Alpha's version code (set by the build with --dart-define) and a newer one found in the releases.
  static const alphaVersion = int.fromEnvironment('ALPHA_VERSION');
  String? alphaUpdate;
  String updatesRepo = '';
  String geminiModel = AiDesigner.defaultGeminiModel;
  bool geminiFirst = false;

  Future<void> load() async {
    projects = await Storage.projects();
    repo = await Storage.get('repo', defaultRepo);
    branch = await Storage.get('branch');
    supabaseRef = await Storage.get('supabase_ref');
    updatesRepo = await Storage.get('updates_repo');
    geminiModel = await Storage.get('gemini_model', AiDesigner.defaultGeminiModel);
    geminiFirst = await Storage.get('gemini_first') == 'true';
    await _refreshFlags();
    loading = false;
    notifyListeners();
    if (hasGitHub) {
      checkAlphaUpdate();
      try {
        await refreshRemote();
      } catch (e) {
        error = '$e';
        notifyListeners();
      }
    }
  }

  Future<void> _refreshFlags() async {
    hasGitHub = (await Storage.secret(Storage.githubToken)).isNotEmpty;
    hasAi = (await Storage.secret(Storage.claudeKey)).isNotEmpty || (await Storage.geminiKeyValues()).isNotEmpty;
    hasSupabase = (await Storage.secret(Storage.supabaseToken)).isNotEmpty;
    hasFirebase = (await Storage.secret(Storage.firebaseServiceAccount)).isNotEmpty;
  }

  Future<GitHub> github() async {
    final token = await Storage.secret(Storage.githubToken);
    if (token.isEmpty) throw GitHubError('أضف توكن GitHub في الإعدادات أولاً.');
    return GitHub(token, repo);
  }

  Future<String> _branch(GitHub gh) async {
    if (branch.isEmpty) {
      branch = await gh.defaultBranch();
      await Storage.set('branch', branch);
    }
    return branch;
  }

  Future<Installer> installer() async {
    final token = await Storage.secret(Storage.githubToken);
    if (token.isEmpty) throw GitHubError('أضف توكن GitHub في الإعدادات أولاً.');
    return Installer(token, repo);
  }

  /// Is a newer Alpha published? Shows the update card on the home screen.
  Future<void> checkAlphaUpdate() async {
    try {
      final rel = await (await installer()).latest('alpha-v');
      final v = int.tryParse('${rel?['tag_name'] ?? ''}'.replaceFirst('alpha-v', '')) ?? 0;
      alphaUpdate = alphaVersion > 0 && v > alphaVersion ? '1.0.$v' : null;
      notifyListeners();
    } catch (_) {}
  }

  /// Saves the picked picture as the icon of an app (apps/<slug>/icon.png); the next build uses it.
  Future<void> setIcon(Project p, AppUnit app, List<int> png) async {
    final gh = await github();
    await gh.commit(await _branch(gh), 'Alpha: icon of ${app.title}', {'apps/${app.slug}/icon.png': 'base64:${base64.encode(png)}'});
  }

  /// The icon saved for an app, if any.
  Future<List<int>?> icon(AppUnit app) async {
    final gh = await github();
    return gh.fileBytes('apps/${app.slug}/icon.png', ref: await _branch(gh));
  }

  /// A public repository that only holds the built apps, so installed apps download their updates without a
  /// GitHub account (this repository stays private). The build publishes every new version there.
  Future<String> createUpdatesRepo() async {
    final gh = await github();
    final token = await Storage.secret(Storage.githubToken);
    final name = '${repo.split('/').last}-updates';
    final full = await gh.createPublicRepo(name, 'Built apps and their updates (made by Alpha). No source code.');
    await gh.setVariable('UPDATES_REPO', full);
    await gh.setSecret('UPDATES_TOKEN', token);
    updatesRepo = full;
    await Storage.set('updates_repo', full);
    notifyListeners();
    return full;
  }

  /// The Gemini model used on the phone and in the workflows (repository variable GEMINI_MODEL).
  Future<void> setGeminiModel(String model, {required bool first}) async {
    geminiModel = model;
    geminiFirst = first;
    await Storage.set('gemini_model', model);
    await Storage.set('gemini_first', '$first');
    if (hasGitHub) {
      final gh = await github();
      await gh.setVariable('GEMINI_MODEL', model);
      await gh.setVariable('AI_PROVIDER', first ? 'gemini' : 'claude');
    }
    notifyListeners();
  }

  /// Mail server for the sign-up confirmation codes (Supabase sends them through it).
  Future<void> saveSmtp(Map<String, String> smtp) async {
    final gh = await github();
    await gh.setSecret('SUPABASE_SMTP', jsonEncode(smtp));
    await Storage.set('smtp_host', smtp['host'] ?? '');
  }

  Future<AiDesigner> ai() async =>
      AiDesigner(
        claudeKey: await Storage.secret(Storage.claudeKey),
        geminiKeys: await Storage.geminiKeyValues(),
        geminiModel: geminiModel,
        geminiFirst: geminiFirst,
      );

  // ---------------- settings ----------------

  Future<String> connectGitHub(String token, String newRepo, String newBranch) async {
    final gh = GitHub(token.trim(), newRepo.trim());
    final me = await gh.user();
    final info = await gh.repoInfo();
    await Storage.setSecret(Storage.githubToken, token);
    repo = newRepo.trim();
    branch = newBranch.trim().isEmpty ? '${info['default_branch'] ?? 'main'}' : newBranch.trim();
    githubUser = '${me['login']}';
    await Storage.set('repo', repo);
    await Storage.set('branch', branch);
    await _refreshFlags();
    notifyListeners();
    return githubUser;
  }

  /// Saves the keys on the phone and as repository secrets (encrypted), where the workflows read them.
  Future<List<String>> saveKeys({
    String? claude,
    List<String>? gemini,
    String? supabaseToken,
    String? supabaseProjectRef,
    String? firebaseJson,
  }) async {
    final done = <String>[];
    final gh = hasGitHub ? await github() : null;
    Future<void> put(String local, String? value, String secret) async {
      if (value == null) return;
      await Storage.setSecret(local, value);
      if (gh != null && value.trim().isNotEmpty) {
        await gh.setSecret(secret, value.trim());
        done.add(secret);
      }
    }

    if (firebaseJson != null && firebaseJson.trim().isNotEmpty) {
      final j = jsonDecode(firebaseJson) as Map;
      if (j['private_key'] == null || j['project_id'] == null) {
        throw Exception('هذا ليس ملف Service Account (يجب أن يحتوي project_id و private_key).');
      }
    }
    await put(Storage.claudeKey, claude, 'ANTHROPIC_API_KEY');
    if (gemini != null) {
      for (var i = 0; i < Storage.geminiKeys.length; i++) {
        final k = Storage.geminiKeys[i];
        final value = i < gemini.length ? gemini[i] : '';
        if (value.trim().isEmpty && gh != null && (await Storage.secret(k.local)).isNotEmpty) {
          // A field that was emptied: remove the old key from the repository too.
          await gh.deleteSecret(k.secret);
        }
        await put(k.local, value, k.secret);
      }
    }
    await put(Storage.supabaseToken, supabaseToken, 'SUPABASE_ACCESS_TOKEN');
    await put(Storage.firebaseServiceAccount, firebaseJson, 'FIREBASE_SERVICE_ACCOUNT');
    if (supabaseProjectRef != null) {
      supabaseRef = supabaseProjectRef.trim();
      await Storage.set('supabase_ref', supabaseRef);
      if (gh != null && supabaseRef.isNotEmpty) {
        await gh.setVariable('SUPABASE_PROJECT_REF', supabaseRef);
        done.add('SUPABASE_PROJECT_REF');
      }
    }
    await _refreshFlags();
    notifyListeners();
    return done;
  }

  // ---------------- projects ----------------

  Project? byId(String id) => projects.where((p) => p.id == id).firstOrNull;

  String newId() => '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';

  Future<void> _persist() async {
    await Storage.saveProjects(projects);
    notifyListeners();
  }

  /// Stores the project and writes all of its files to the repository in one commit.
  Future<void> save(Project p, {String message = ''}) async {
    final errors = p.schema.validate();
    if (errors.isNotEmpty) throw Exception(errors.join('\n'));
    final i = projects.indexWhere((x) => x.id == p.id);
    if (i < 0) {
      projects.insert(0, p);
    } else {
      projects[i] = p;
    }
    await _persist();
    if (!hasGitHub) return;
    final gh = await github();
    final b = await _branch(gh);
    // Keep the server connection the backend workflow already wrote into each app.
    final connections = <String, Map<String, dynamic>>{};
    for (final a in p.apps) {
      try {
        final raw = await gh.file('apps/${a.slug}/alpha.json', ref: b);
        if (raw != null) {
          final be = ((jsonDecode(raw) as Map)['backend'] as Map?)?.cast<String, dynamic>();
          if (be != null) connections[a.slug] = be;
        }
      } catch (_) {}
    }
    final files = projectFiles(p, connections: connections);
    if (p.customCode.trim().isNotEmpty && p.apps.isNotEmpty) {
      // Pasted code is the app's own code (the customer app of a pair); the build checks and fixes it.
      final libs = parseLibraries(await rootBundle.loadString('factory/libraries.json'));
      files.addAll(customFiles(p.apps.first.slug, p.lang, p.customCode, libs));
    }
    await gh.commit(b, message.isEmpty ? 'Alpha: ${p.title}' : message, files);
  }

  Future<void> remove(Project p, {bool fromRepo = false}) async {
    projects.removeWhere((x) => x.id == p.id);
    await _persist();
    if (fromRepo && hasGitHub) {
      final gh = await github();
      final b = await _branch(gh);
      final files = <String, String?>{};
      for (final f in await gh.list('projects/${p.base}', ref: b)) {
        files['projects/${p.base}/${f.name}'] = null;
      }
      for (final a in p.apps) {
        for (final f in await gh.list('apps/${a.slug}', ref: b)) {
          if (f.type == 'file') files['apps/${a.slug}/${f.name}'] = null;
        }
      }
      if (files.isNotEmpty) await gh.commit(b, 'Alpha: remove ${p.title}', files);
    }
  }

  /// Projects saved in the repository (made on another phone) that this phone does not have yet.
  Future<int> importFromRepo() async {
    final gh = await github();
    final b = await _branch(gh);
    var added = 0;
    for (final d in await gh.list('projects', ref: b)) {
      if (d.type != 'dir' || projects.any((p) => p.base == d.name)) continue;
      final raw = await gh.file('projects/${d.name}/alpha-project.json', ref: b);
      if (raw == null) continue;
      projects.add(Project.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()));
      added++;
    }
    await _persist();
    return added;
  }

  // ---------------- builds and servers ----------------

  Future<void> build(AppUnit app, {bool store = false, String notes = ''}) async {
    final gh = await github();
    await gh.dispatch('build.yml', await _branch(gh), {'app': app.slug, 'store': '$store', 'notes': notes});
    await Future<void>.delayed(const Duration(seconds: 3));
    await refreshRuns();
  }

  Future<void> buildAll(Project p) async {
    for (final a in p.apps) {
      await build(a);
    }
  }

  /// Full server setup in GitHub Actions (tables, sign-in, push), then builds the apps.
  Future<void> setupServer(Project p, {bool buildAfter = true}) async {
    if (p.backend == BackendType.supabase && !p.forClient && (!hasSupabase || supabaseRef.isEmpty && p.supabaseRef.isEmpty)) {
      throw Exception('أضف توكن Supabase ومعرّف المشروع (Project ref) في الإعدادات.');
    }
    if (p.backend == BackendType.supabase && p.forClient && (await tokenFor(p.supabaseRef)).isEmpty) {
      throw Exception('مفتاح قاعدة بيانات الزبون غير محفوظ على هذا الهاتف: أضفها من جديد (لمين ← لزبون).');
    }
    if (p.backend == BackendType.firebase && !hasFirebase) throw Exception('أضف ملف Firebase Service Account في الإعدادات.');
    final gh = await github();
    await gh.dispatch('backend.yml', await _branch(gh), {
      'base': p.base,
      'build': '$buildAfter',
      // A client's database: the workflow uses that client's token (secret SUPABASE_TOKEN_<REF>).
      if (p.forClient && p.supabaseRef.isNotEmpty) 'ref': p.supabaseRef,
    });
    await Future<void>.delayed(const Duration(seconds: 3));
    await refreshRuns();
  }

  /// Runs the project's SQL on Supabase right now from the phone (no workflow), and saves the keys.
  Future<String> applySqlNow(Project p) async {
    final ref = p.supabaseRef.isNotEmpty ? p.supabaseRef : supabaseRef;
    final token = await tokenFor(ref);
    if (token.isEmpty || ref.isEmpty) throw Exception('أضف توكن Supabase ومعرّف المشروع في الإعدادات.');
    final admin = SupabaseAdmin(token);
    await admin.sql(ref, projectSql(p));
    await admin.configureAuth(ref, mode: p.auth.id);
    final key = await admin.anonKey(ref);
    p.supabaseUrl = 'https://$ref.supabase.co';
    if (key != null) p.supabaseAnonKey = key;
    await save(p, message: 'Alpha: database of ${p.title} applied');
    final rows = await admin.sql(ref,
        "select table_name from information_schema.tables where table_schema='public' and table_name like '${p.prefix}\\_%' order by 1");
    return rows.map((r) => r['table_name']).join('، ');
  }

  Future<void> sendTestNotification(Project p, {required String toRole, required String title, required String body}) async {
    final ref = p.supabaseRef.isNotEmpty ? p.supabaseRef : supabaseRef;
    final token = await tokenFor(ref);
    if (token.isEmpty || ref.isEmpty) throw Exception('أضف توكن Supabase ومعرّف المشروع في الإعدادات.');
    String q(String s) => "'${s.replaceAll("'", "''")}'";
    await SupabaseAdmin(token).sql(ref,
        'insert into public.${p.prefix}_notifications (to_role, title, body, created_by) values (${q(toRole)}, ${q(title)}, ${q(body)}, null);');
  }

  // ---------- client databases ----------
  // Besides the main Supabase project (settings), each client can have its own database: a project in the client's
  // own Supabase account (its ref + that account's access token) or one Alpha creates in the owner's account.
  // The token stays on the phone and goes to the repository as SUPABASE_TOKEN_<REF> (backend.yml reads it).

  static const supabaseRegions = {
    'eu-central-1': 'فرانكفورت (الأقرب للشرق الأوسط)',
    'ap-south-1': 'مومباي',
    'eu-west-2': 'لندن',
    'us-east-1': 'أمريكا (شرق)',
  };

  static bool validRef(String ref) => RegExp(r'^[a-z]{20}$').hasMatch(ref);

  Future<List<ClientDb>> clientDbs() async {
    try {
      return (jsonDecode(await Storage.get('client_dbs', '[]')) as List)
          .map((e) => ClientDb.fromJson((e as Map).cast<String, dynamic>()))
          .where((c) => validRef(c.ref))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// The access token that manages a Supabase project: the client's own one when it was added, else the main one.
  Future<String> tokenFor(String ref) async {
    if (ref.isNotEmpty) {
      final own = await Storage.secret('supabase_token_$ref');
      if (own.isNotEmpty) return own;
    }
    return Storage.secret(Storage.supabaseToken);
  }

  Future<ClientDb> _remember(ClientDb c, String token) async {
    await Storage.setSecret('supabase_token_${c.ref}', token);
    if (hasGitHub) await (await github()).setSecret('SUPABASE_TOKEN_${c.ref.toUpperCase()}', token);
    final list = (await clientDbs()).where((x) => x.ref != c.ref).toList()..add(c);
    await Storage.set('client_dbs', jsonEncode(list.map((x) => x.toJson()).toList()));
    notifyListeners();
    return c;
  }

  /// A project in the client's own Supabase account: checked with Supabase before it is saved.
  Future<ClientDb> addClientDb(String label, String ref, String token) async {
    ref = ref.trim().toLowerCase();
    token = token.trim();
    if (!validRef(ref)) throw Exception('رمز المشروع (Project Ref) 20 حرفاً إنجليزياً صغيراً، من رابط المشروع: supabase.com/dashboard/project/<الرمز>');
    if (!token.startsWith('sbp_')) throw Exception('مفتاح الوصول يبدأ بـ sbp_ (من حساب الزبون: Account ← Access Tokens)، وليس مفتاح anon.');
    final info = await SupabaseAdmin(token).project(ref);
    final name = label.trim().isNotEmpty ? label.trim() : (info.name.isNotEmpty ? info.name : ref);
    return _remember(ClientDb(ref: ref, label: name, inClientAccount: true, region: info.region), token);
  }

  /// A new project in the owner's account (the main token), for a client.
  Future<ClientDb> createClientDb(String label, String region, {void Function(String step)? onStep}) async {
    final token = await Storage.secret(Storage.supabaseToken);
    if (token.isEmpty) throw Exception('أضف توكن Supabase الخاص بك في الإعدادات أولاً.');
    final name = label.trim().replaceAll(RegExp('[<>"\'`\\\\]'), '');
    final p = await SupabaseAdmin(token).createProject(name.isEmpty ? 'alpha-client' : name, region, onStep: onStep);
    return _remember(ClientDb(ref: p.ref, label: name.isEmpty ? p.ref : name, inClientAccount: false, region: region), token);
  }

  /// Removes it from Alpha only; the project and its data stay in Supabase.
  Future<void> removeClientDb(String ref) async {
    final list = (await clientDbs()).where((x) => x.ref != ref).toList();
    await Storage.set('client_dbs', jsonEncode(list.map((x) => x.toJson()).toList()));
    await Storage.setSecret('supabase_token_$ref', '');
    notifyListeners();
  }

  // ---------- AI edits of an existing app ----------

  /// The last AI edits of a project (newest first), each with the project as it was before (for undo).
  Future<List<Map<String, dynamic>>> edits(Project p) async {
    try {
      return (jsonDecode(await Storage.get('edits_${p.id}', '[]')) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the edited project, updates the server when the data changed, then rebuilds every app (or has the AI write
  /// code first): the installed apps then show «تحديث جديد» and update in place. Returns what was started.
  Future<String> applyEdit(Project before, Project after, AiEdit edit, {List<AppUnit>? codeApps}) async {
    final history = await edits(before);
    history.insert(0, {
      'at': DateTime.now().toIso8601String(),
      'request': edit.request,
      'summary': edit.summary,
      'before': before.toJson(),
    });
    await Storage.set('edits_${before.id}', jsonEncode(history.take(15).toList()));
    await save(after, message: 'Alpha: AI edit of ${after.title}: ${edit.request.split('\n').first}');
    if (!hasGitHub) return 'حُفظ التعديل على الهاتف. اربط GitHub لتحديث التطبيقات المثبتة.';
    final code = edit.codeRequest.trim();
    final steps = <String>[];
    if (needsServer(before, after)) {
      await setupServer(after, buildAfter: code.isEmpty);
      steps.add('تحديث السيرفر (الجداول والصلاحيات)');
    } else if (code.isEmpty) {
      await buildAll(after);
    }
    if (code.isNotEmpty) {
      for (final a in codeApps ?? after.apps) {
        await generateWithAi(a, '$code\n\n(طلب صاحب التطبيق: ${edit.request})');
      }
      steps.add('كتابة الكود بالذكاء الاصطناعي');
    }
    steps.add('بناء ${after.apps.length == 1 ? 'التطبيق' : '${after.apps.length} تطبيقات'}');
    return 'بدأ: ${steps.join(' ← ')}. التطبيقات المثبتة سيظهر فيها «تحديث جديد» عند انتهاء البناء.';
  }

  /// Puts the project back as it was before its last AI edit, and rebuilds.
  Future<String> undoEdit(Project p) async {
    final history = await edits(p);
    if (history.isEmpty) throw Exception('لا يوجد تعديل للتراجع عنه');
    final last = history.removeAt(0);
    final before = Project.fromJson((last['before'] as Map).cast<String, dynamic>());
    await Storage.set('edits_${p.id}', jsonEncode(history));
    await save(before, message: 'Alpha: undo AI edit of ${before.title}');
    if (!hasGitHub) return 'رجع التطبيق كما كان على الهاتف.';
    if (needsServer(p, before)) {
      await setupServer(before);
    } else {
      await buildAll(before);
    }
    return 'رجع التطبيق كما كان قبل «${last['request']}»، وبدأ البناء.';
  }

  Future<void> generateWithAi(AppUnit app, String request) async {
    final gh = await github();
    await gh.dispatch('generate.yml', await _branch(gh), {'app': app.slug, 'request': request, 'build': 'true'});
    await Future<void>.delayed(const Duration(seconds: 3));
    await refreshRuns();
  }

  Future<void> refreshRuns() async {
    try {
      final gh = await github();
      runs = await gh.runs();
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> refreshRemote() async {
    final gh = await github();
    final b = await _branch(gh);
    runs = await gh.runs();
    for (final p in projects) {
      final status = await gh.file('projects/${p.base}/status.json', ref: b);
      if (status != null) serverStatus[p.base] = (jsonDecode(status) as Map).cast<String, dynamic>();
      for (final a in p.apps) {
        final info = await gh.file('apps/${a.slug}/build.json', ref: b);
        if (info != null) builds[a.slug] = BuildInfo((jsonDecode(info) as Map).cast<String, dynamic>());
        final cfg = await gh.file('apps/${a.slug}/alpha.json', ref: b);
        if (cfg != null) {
          final be = ((jsonDecode(cfg) as Map)['backend'] as Map?) ?? const {};
          if ('${be['url'] ?? ''}'.isNotEmpty) p.supabaseUrl = '${be['url']}';
          if ('${be['anonKey'] ?? ''}'.isNotEmpty) p.supabaseAnonKey = '${be['anonKey']}';
        }
      }
    }
    error = null;
    await _persist();
  }

  List<WorkflowRun> runsFor(Project p) {
    final names = {p.base, ...p.apps.map((a) => a.slug)};
    return runs.where((r) => names.any((n) => r.title.endsWith(' $n') || r.title.contains(' $n '))).toList();
  }

  bool serverReady(Project p) =>
      p.backend == BackendType.none ||
      serverStatus[p.base]?['ready'] == true ||
      (p.backend == BackendType.supabase && p.supabaseAnonKey.isNotEmpty);
}

/// A client's database (a Supabase project).
class ClientDb {
  ClientDb({required this.ref, required this.label, required this.inClientAccount, this.region = ''});
  final String ref;
  final String label;
  final bool inClientAccount; // true: the client's own Supabase account; false: created in the owner's account
  final String region;

  Map<String, dynamic> toJson() => {'ref': ref, 'label': label, 'client': inClientAccount, 'region': region};
  factory ClientDb.fromJson(Map<String, dynamic> j) =>
      ClientDb(ref: '${j['ref'] ?? ''}', label: '${j['label'] ?? ''}', inClientAccount: j['client'] != false, region: '${j['region'] ?? ''}');
}
