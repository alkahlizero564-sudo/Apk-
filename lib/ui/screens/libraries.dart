import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../models/project.dart';
import '../widgets.dart';

/// Every library installed for each language (factory/libraries.json, the same file the builds use).
class LibrariesScreen extends StatefulWidget {
  const LibrariesScreen({super.key});

  @override
  State<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends State<LibrariesScreen> {
  Map<String, dynamic>? _libs;
  Lang _lang = Lang.flutter;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('factory/libraries.json').then((t) {
      if (mounted) setState(() => _libs = (jsonDecode(t) as Map).cast<String, dynamic>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = (_libs?[_lang.id] as Map?)?.cast<String, dynamic>();
    final packages = ((info?['packages'] as List?) ?? const []).cast<Map>();
    final c = Color(_lang.color);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text('المكتبات المثبّتة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const Text('كل لغة معها مكتباتها بإصدارات مختبرة معاً؛ البناء يثبّتها والذكاء الاصطناعي يستخدمها فقط، فلا أخطاء إصدارات.',
              style: TextStyle(color: AlphaColors.muted, height: 1.6)),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in Lang.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      avatar: Icon(langIcon(l), size: 18, color: Color(l.color)),
                      label: Text(l.label),
                      selected: _lang == l,
                      onSelected: (_) => setState(() => _lang = l),
                    ),
                  ),
              ],
            ),
          ),
          if (info != null)
            GlassCard(
              gradient: LinearGradient(colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.05)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(langIcon(_lang), color: c), const SizedBox(width: 8), Text(_lang.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
                  const SizedBox(height: 8),
                  Text('${info['runtime']}', style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 4),
                  Text('${info['files']}', style: const TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.5)),
                  const SizedBox(height: 8),
                  Pill('${packages.length} مكتبة', color: c),
                ],
              ),
            ),
          if (_libs == null) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          for (final p in packages)
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.extension_rounded, color: c, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['name']}', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 13)),
                        Text('${p['use']}', style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('${p['version']}', textDirection: TextDirection.ltr, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
