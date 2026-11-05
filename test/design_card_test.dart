import 'package:alpha/models/project.dart';
import 'package:alpha/ui/ai_design_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('design card: empty, then with the two apps\' designs', (t) async {
    t.view.physicalSize = const Size(380 * 2, 1400 * 2);
    t.view.devicePixelRatio = 2;
    final p = Project(id: '1', base: 'shop', title: 'متجر', lang: Lang.kotlin, kind: ProjectKind.pair, apps: Project.unitsFor('shop', 'متجر', ProjectKind.pair));
    Widget host() => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AiDesignCard(draft: () => p, onDesigned: (d) => p.design = d))));
    await t.pumpWidget(host());
    expect(find.text('صمّم التطبيق بالذكاء الاصطناعي'), findsOneWidget);
    expect(t.takeException(), isNull);
    p.design = AiDesign(screens: {'shop-customer': '<html></html>', 'shop-admin': '<html></html>'});
    await t.pumpWidget(Container());
    await t.pumpWidget(host());
    expect(find.text('افتح التصميم وجرّبه'), findsOneWidget);
    expect(find.text('تطبيق الإدارة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
