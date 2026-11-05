import 'package:alpha/generator/presets.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/models/schema.dart';
import 'package:alpha/ui/screens/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('design editor lays out', (t) async {
    t.view.physicalSize = const Size(420 * 2, 3200 * 2);
    t.view.devicePixelRatio = 2;
    var theme = lookById('glass')!.apply(ThemeSpec());
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DesignEditor(theme: theme, title: 'x', schema: DbSchema(), onChanged: (v) => theme = v)))));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await t.tap(find.text('Neo-Brutalism'));
    expect(theme.school, 'brutal');
    expect(theme.home, 'bento');
  });
}
