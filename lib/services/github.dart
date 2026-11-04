import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pinenacl/x25519.dart';

class GitHubError implements Exception {
  GitHubError(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class WorkflowRun {
  WorkflowRun(Map<String, dynamic> j)
      : id = j['id'] as int,
        title = '${j['display_title'] ?? j['name'] ?? ''}',
        workflow = '${j['path'] ?? ''}'.split('/').last,
        status = '${j['status'] ?? ''}',
        conclusion = '${j['conclusion'] ?? ''}',
        url = '${j['html_url'] ?? ''}',
        createdAt = DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
        updatedAt = DateTime.tryParse('${j['updated_at']}')?.toLocal() ?? DateTime.now();

  final int id;
  final String title;
  final String workflow;
  final String status; // queued | in_progress | completed
  final String conclusion; // success | failure | cancelled | ''
  final String url;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get running => status != 'completed';
  bool get ok => conclusion == 'success';
}

class JobStep {
  JobStep(this.name, this.status, this.conclusion);
  final String name;
  final String status;
  final String conclusion;
}

/// The GitHub REST API: files, atomic multi-file commits, workflows, runs, releases and encrypted secrets.
class GitHub {
  GitHub(this.token, this.repo);
  final String token;
  final String repo; // owner/name

  static const _api = 'https://api.github.com';

  Map<String, String> get _h => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _req(String method, String path, {Object? body, bool allow404 = false}) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$_api$path');
    final req = http.Request(method, uri)..headers.addAll(_h);
    if (body != null) req.body = jsonEncode(body);
    late http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
    } catch (e) {
      throw GitHubError('لا يوجد اتصال بـ GitHub ($e)');
    }
    if (allow404 && res.statusCode == 404) return null;
    if (res.statusCode >= 300) {
      var msg = res.body;
      try {
        msg = '${(jsonDecode(res.body) as Map)['message']}';
      } catch (_) {}
      throw GitHubError(switch (res.statusCode) {
        401 => 'توكن GitHub غير صحيح أو منتهي.',
        403 => 'GitHub رفض العملية: $msg (تأكد أن التوكن فيه صلاحيات repo و workflow).',
        404 => 'غير موجود على GitHub: $path',
        _ => 'GitHub (${res.statusCode}): $msg',
      }, res.statusCode);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> user() async => (await _req('GET', '/user') as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> repoInfo() async => (await _req('GET', '/repos/$repo') as Map).cast<String, dynamic>();

  Future<String> defaultBranch() async => '${(await repoInfo())['default_branch'] ?? 'main'}';

  /// A text file of the repository, or null when it does not exist.
  Future<String?> file(String path, {String? ref}) async {
    final j = await _req('GET', '/repos/$repo/contents/$path${ref == null ? '' : '?ref=$ref'}', allow404: true);
    if (j == null || j is! Map || j['content'] == null) return null;
    return utf8.decode(base64.decode('${j['content']}'.replaceAll('\n', '')));
  }

  /// Names in a folder ([] when it does not exist).
  Future<List<({String name, String type})>> list(String path, {String? ref}) async {
    final j = await _req('GET', '/repos/$repo/contents/$path${ref == null ? '' : '?ref=$ref'}', allow404: true);
    if (j is! List) return [];
    return j.map((e) => (name: '${e['name']}', type: '${e['type']}')).toList();
  }

  /// Writes many files in ONE commit (git data API): no half-written project if the network drops.
  /// A null value deletes the file. Binary files are passed base64 with a "base64:" prefix.
  Future<String> commit(String branch, String message, Map<String, String?> files) async {
    final ref = await _req('GET', '/repos/$repo/git/ref/heads/$branch') as Map;
    final parent = '${(ref['object'] as Map)['sha']}';
    final head = await _req('GET', '/repos/$repo/git/commits/$parent') as Map;
    final baseTree = '${(head['tree'] as Map)['sha']}';
    final tree = <Map<String, dynamic>>[];
    for (final e in files.entries) {
      final v = e.value;
      if (v == null) {
        tree.add({'path': e.key, 'mode': '100644', 'type': 'blob', 'sha': null});
      } else if (v.startsWith('base64:')) {
        final blob = await _req('POST', '/repos/$repo/git/blobs', body: {'content': v.substring(7), 'encoding': 'base64'}) as Map;
        tree.add({'path': e.key, 'mode': '100644', 'type': 'blob', 'sha': blob['sha']});
      } else {
        tree.add({'path': e.key, 'mode': '100644', 'type': 'blob', 'content': v});
      }
    }
    final newTree = await _req('POST', '/repos/$repo/git/trees', body: {'base_tree': baseTree, 'tree': tree}) as Map;
    final c = await _req('POST', '/repos/$repo/git/commits',
        body: {'message': message, 'tree': newTree['sha'], 'parents': [parent]}) as Map;
    await _req('PATCH', '/repos/$repo/git/refs/heads/$branch', body: {'sha': c['sha']});
    return '${c['sha']}';
  }

  Future<void> dispatch(String workflow, String branch, Map<String, String> inputs) =>
      _req('POST', '/repos/$repo/actions/workflows/$workflow/dispatches', body: {'ref': branch, 'inputs': inputs});

  Future<List<WorkflowRun>> runs({int perPage = 40}) async {
    final j = await _req('GET', '/repos/$repo/actions/runs?per_page=$perPage') as Map;
    return ((j['workflow_runs'] as List?) ?? const []).map((e) => WorkflowRun((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<JobStep>> steps(int runId) async {
    final j = await _req('GET', '/repos/$repo/actions/runs/$runId/jobs') as Map;
    final out = <JobStep>[];
    for (final job in (j['jobs'] as List? ?? const [])) {
      for (final s in (job['steps'] as List? ?? const [])) {
        out.add(JobStep('${s['name']}', '${s['status']}', '${s['conclusion'] ?? ''}'));
      }
    }
    return out;
  }

  /// The end of the log of a failed run (the error), as plain text.
  Future<String> failureLog(int runId) async {
    final j = await _req('GET', '/repos/$repo/actions/runs/$runId/jobs') as Map;
    for (final job in (j['jobs'] as List? ?? const [])) {
      if (job['conclusion'] == 'failure') {
        final res = await http.get(Uri.parse('$_api/repos/$repo/actions/jobs/${job['id']}/logs'), headers: _h);
        final text = utf8.decode(res.bodyBytes, allowMalformed: true);
        final lines = text.split('\n');
        final errs = lines.where((l) => RegExp(r'error|Error|ERROR|failed|FAILED').hasMatch(l)).toList();
        return (errs.isEmpty ? lines.skip(lines.length > 60 ? lines.length - 60 : 0) : errs.skip(errs.length > 40 ? errs.length - 40 : 0))
            .map((l) => l.length > 28 && RegExp(r'^\d{4}-').hasMatch(l) ? l.substring(29) : l)
            .join('\n');
      }
    }
    return '';
  }

  Future<void> rerun(int runId) => _req('POST', '/repos/$repo/actions/runs/$runId/rerun-failed-jobs');

  /// Saves a repository secret encrypted with the repository's public key (libsodium sealed box).
  Future<void> setSecret(String name, String value) async {
    final key = await _req('GET', '/repos/$repo/actions/secrets/public-key') as Map;
    final pub = PublicKey(Uint8List.fromList(base64.decode('${key['key']}')));
    final sealed = SealedBox(pub).encrypt(Uint8List.fromList(utf8.encode(value)));
    await _req('PUT', '/repos/$repo/actions/secrets/$name',
        body: {'encrypted_value': base64.encode(sealed), 'key_id': '${key['key_id']}'});
  }

  Future<void> deleteSecret(String name) async {
    try {
      await _req('DELETE', '/repos/$repo/actions/secrets/$name');
    } on GitHubError catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  Future<Set<String>> secretNames() async {
    final j = await _req('GET', '/repos/$repo/actions/secrets?per_page=100') as Map;
    return ((j['secrets'] as List?) ?? const []).map((e) => '${e['name']}').toSet();
  }

  Future<void> setVariable(String name, String value) async {
    try {
      await _req('PATCH', '/repos/$repo/actions/variables/$name', body: {'name': name, 'value': value});
    } on GitHubError catch (e) {
      if (e.status != 404) rethrow;
      await _req('POST', '/repos/$repo/actions/variables', body: {'name': name, 'value': value});
    }
  }
}
