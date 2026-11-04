import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an APK from a release of the (private) repository with the user's token and opens Android's
/// installer, so apps are installed from Alpha without opening GitHub.
class Installer {
  Installer(this.token, this.repo);
  final String token;
  final String repo;

  Map<String, String> get _h => {
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// The release with this tag, or null.
  Future<Map<String, dynamic>?> release(String tag) async {
    final res = await http.get(Uri.parse('https://api.github.com/repos/$repo/releases/tags/$tag'),
        headers: {..._h, 'Accept': 'application/vnd.github+json'});
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 300) throw Exception('GitHub (${res.statusCode})');
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
  }

  /// The newest release whose tag starts with [prefix] (e.g. "alpha-v").
  Future<Map<String, dynamic>?> latest(String prefix) async {
    final res = await http.get(Uri.parse('https://api.github.com/repos/$repo/releases?per_page=50'),
        headers: {..._h, 'Accept': 'application/vnd.github+json'});
    if (res.statusCode >= 300) return null;
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Map>();
    int version(Map r) => int.tryParse('${r['tag_name']}'.replaceFirst(prefix, '')) ?? 0;
    final matching = list.where((r) => '${r['tag_name']}'.startsWith(prefix) && r['draft'] != true).toList()
      ..sort((a, b) => version(b).compareTo(version(a)));
    return matching.isEmpty ? null : matching.first.cast<String, dynamic>();
  }

  /// Downloads the first .apk of [rel]; [onProgress] gets 0..1.
  Future<File> download(Map<String, dynamic> rel, {void Function(double)? onProgress}) async {
    final assets = ((rel['assets'] as List?) ?? const []).cast<Map>();
    final apk = assets.firstWhere((a) => '${a['name']}'.endsWith('.apk'), orElse: () => throw Exception('لا يوجد APK في هذا الإصدار'));
    final client = http.Client();
    try {
      // The asset API answers with a redirect to signed storage; that second request must not carry the token.
      final first = http.Request('GET', Uri.parse('${apk['url']}'))
        ..followRedirects = false
        ..headers.addAll({..._h, 'Accept': 'application/octet-stream'});
      var res = await client.send(first);
      if (res.isRedirect || res.statusCode == 302 || res.statusCode == 301) {
        final location = res.headers['location'];
        await res.stream.drain<void>();
        if (location == null) throw Exception('رابط التحميل غير موجود');
        res = await client.send(http.Request('GET', Uri.parse(location)));
      }
      if (res.statusCode >= 300) throw Exception('فشل التحميل (${res.statusCode})');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${apk['name']}');
      final sink = file.openWrite();
      final total = res.contentLength ?? (apk['size'] as num?)?.toInt() ?? 0;
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call(got / total);
      }
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Opens Android's installer for [file]. Android asks once to allow installs from Alpha.
  static Future<void> install(File file) async {
    final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (r.type != ResultType.done) throw Exception('تعذّر فتح المثبّت: ${r.message}');
  }
}
