// Every file Alpha writes to the repository for a project (one atomic commit).
import 'dart:convert';

import '../models/project.dart';
import 'firestore_rules.dart';
import 'sql_generator.dart';

String packageFor(String slug) => 'com.alpha.${slug.replaceAll('-', '_')}';

const _json = JsonEncoder.withIndent(' ');

/// apps/<slug>/alpha.json: what the engine of that app reads. [connection] keeps what the server setup
/// already wrote (URL, keys, Firebase options), so saving a design never disconnects an app.
Map<String, dynamic> appConfig(Project p, AppUnit unit, {Map<String, dynamic>? connection}) {
  final backend = <String, dynamic>{
    'type': p.backend.id,
    'prefix': p.prefix,
    'auth': p.auth.id,
    'push': p.push && p.lang.supportsPush,
    if (p.backend == BackendType.none && p.lang == Lang.php) 'admins': p.admins,
    if (p.supabaseUrl.isNotEmpty) 'url': p.supabaseUrl,
    if (p.supabaseAnonKey.isNotEmpty) 'anonKey': p.supabaseAnonKey,
  };
  if (connection != null) {
    for (final k in ['url', 'anonKey', 'firebase']) {
      if (connection[k] != null && '${connection[k]}'.isNotEmpty) backend[k] = connection[k];
    }
  }
  return {
    'alpha': 1,
    'project': p.base,
    'lang': p.lang.id,
    'app': {
      'title': unit.title,
      'slug': unit.slug,
      'role': unit.role,
      'rtl': true,
      'package': packageFor(unit.slug),
      if (p.headline.isNotEmpty) 'headline': p.headline,
      if (p.subtitle.isNotEmpty) 'subtitle': p.subtitle,
    },
    if (p.lang == Lang.php && p.serverUrl.isNotEmpty) 'server': p.serverUrl,
    'theme': p.theme.toJson(),
    'backend': backend,
    'tables': p.schema.toJson(),
  };
}

/// projects/<base>/project.json: what factory/backend_setup.py reads.
Map<String, dynamic> factoryProject(Project p) => {
      'base': p.base,
      'prefix': p.prefix,
      'lang': p.lang.id,
      'backend': p.backend.id,
      'auth': p.auth.id,
      'push': p.push && p.lang.supportsPush,
      'admins': p.admins,
      if (p.supabaseRef.isNotEmpty) 'supabaseRef': p.supabaseRef,
      'apps': [
        for (final a in p.apps) {'slug': a.slug, 'role': a.role, 'title': a.title, 'package': packageFor(a.slug)}
      ],
    };

String projectSql(Project p) => SqlGenerator(p.prefix, p.schema, admins: p.admins).build();

Map<String, String?> projectFiles(Project p, {Map<String, Map<String, dynamic>> connections = const {}}) {
  final files = <String, String?>{
    'projects/${p.base}/alpha-project.json': _json.convert(p.toJson()),
    'projects/${p.base}/project.json': _json.convert(factoryProject(p)),
  };
  if (p.backend == BackendType.supabase) {
    files['projects/${p.base}/schema.sql'] = projectSql(p);
  }
  if (p.backend == BackendType.firebase) {
    final rules = FirestoreRulesGenerator(p.prefix, p.schema);
    files['projects/${p.base}/firestore.rules'] = rules.build();
    files['projects/${p.base}/firestore.indexes.json'] = rules.indexes();
  }
  for (final a in p.apps) {
    files['apps/${a.slug}/alpha.json'] = '${_json.convert(appConfig(p, a, connection: connections[a.slug]))}\n';
  }
  return files;
}
