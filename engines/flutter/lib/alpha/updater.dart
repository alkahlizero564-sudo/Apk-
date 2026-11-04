// In-app updates: the build publishes each version (public link, no GitHub account needed); the app checks
// it when it opens, offers the update, downloads it and opens Android's installer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';

class UpdateInfo {
  UpdateInfo(this.version, this.name, this.apk, this.notes);
  final int version;
  final String name;
  final String apk;
  final String notes;
}

Future<UpdateInfo?> checkForUpdate(AlphaConfig config) async {
  final u = ((config.raw['update'] as Map?) ?? const {}).cast<String, dynamic>();
  final url = '${u['url'] ?? ''}';
  final current = (u['version'] as num?)?.toInt() ?? 0;
  if (url.isEmpty || current == 0) return null;
  try {
    final res = await http.get(Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final j = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
    final v = (j['version'] as num?)?.toInt() ?? 0;
    if (v <= current || '${j['apk'] ?? ''}'.isEmpty) return null;
    return UpdateInfo(v, '${j['name'] ?? '1.0.$v'}', '${j['apk']}', '${j['notes'] ?? ''}');
  } catch (_) {
    return null;
  }
}

/// Asks the user, then downloads and installs.
Future<void> offerUpdate(BuildContext context, UpdateInfo info) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded, size: 36),
      title: const Text('تحديث جديد'),
      content: Text('النسخة ${info.name} جاهزة.${info.notes.isEmpty ? '' : '\n\n${info.notes}'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لاحقاً')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حدّث الآن')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final progress = ValueNotifier<double?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('يحمّل التحديث…'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: p),
            const SizedBox(height: 8),
            Text(p == null ? '' : '${(p * 100).round()}%'),
          ],
        ),
      ),
    ),
  );
  try {
    final client = http.Client();
    final res = await client.send(http.Request('GET', Uri.parse(info.apk)));
    if (res.statusCode != 200) throw Exception('${res.statusCode}');
    final file = File('${(await getTemporaryDirectory()).path}/update-${info.version}.apk');
    final sink = file.openWrite();
    final total = res.contentLength ?? 0;
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress.value = got / total;
    }
    await sink.close();
    client.close();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تحميل التحديث: $e')));
    }
  }
}
