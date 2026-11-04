import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../generator/app_files.dart';
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

  Future<void> load() async {
    projects = await Storage.projects();
    repo = await Storage.get('repo', defaultRepo);
    branch = await Storage.get('branch');
    supabaseRef = await Storage.get('supabase_ref');
    updatesRepo = await Storage.get('updates_repo');
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

  /// Mail server for the sign-up confirmation codes (Supabase sends them through it).
  Future<void> saveSmtp(Map<String, String> smtp) async {
    final gh = await github();
    await gh.setSecret('SUPABASE_SMTP', jsonEncode(smtp));
    await Storage.set('smtp_host', smtp['host'] ?? '');
  }

  Future<AiDesigner> ai() async =>
      AiDesigner(claudeKey: await Storage.secret(Storage.claudeKey), geminiKeys: await Storage.geminiKeyValues());

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
    await gh.commit(b, message.isEmpty ? 'Alpha: ${p.title}' : message, projectFiles(p, connections: connections));
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
    if (p.backend == BackendType.supabase && (!hasSupabase || supabaseRef.isEmpty && p.supabaseRef.isEmpty)) {
      throw Exception('أضف توكن Supabase ومعرّف المشروع (Project ref) في الإعدادات.');
    }
    if (p.backend == BackendType.firebase && !hasFirebase) throw Exception('أضف ملف Firebase Service Account في الإعدادات.');
    final gh = await github();
    await gh.dispatch('backend.yml', await _branch(gh), {'base': p.base, 'build': '$buildAfter'});
    await Future<void>.delayed(const Duration(seconds: 3));
    await refreshRuns();
  }

  /// Runs the project's SQL on Supabase right now from the phone (no workflow), and saves the keys.
  Future<String> applySqlNow(Project p) async {
    final token = await Storage.secret(Storage.supabaseToken);
    final ref = p.supabaseRef.isNotEmpty ? p.supabaseRef : supabaseRef;
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
    final token = await Storage.secret(Storage.supabaseToken);
    final ref = p.supabaseRef.isNotEmpty ? p.supabaseRef : supabaseRef;
    if (token.isEmpty || ref.isEmpty) throw Exception('أضف توكن Supabase ومعرّف المشروع في الإعدادات.');
    String q(String s) => "'${s.replaceAll("'", "''")}'";
    await SupabaseAdmin(token).sql(ref,
        'insert into public.${p.prefix}_notifications (to_role, title, body, created_by) values (${q(toRole)}, ${q(title)}, ${q(body)}, null);');
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
