import 'package:alpha/app/state.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/services/ai.dart';
import 'package:alpha/ui/screens/wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAi extends AiDesigner {
  _FakeAi() : super(claudeKey: 'x', geminiKeys: const []);
  final prompts = <String>[];
  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000, int? thinking = 1024}) async {
    prompts.add(prompt);
    return '```html\n<!doctype html><html dir="rtl"><body>${List.filled(200, '<p>شاشة</p>').join()}</body></html>\n```';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('instant preview straight from the description: the app (HTML) or a Material 3 imitation (native), cached', () async {
    SharedPreferences.setMockInitialValues({});
    final ai = _FakeAi();
    final html = await ai.instantPreview(Lang.html, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(html, startsWith('<!doctype html>'));
    expect(ai.prompts.single, contains('Build the app itself'));
    expect(ai.prompts.single, contains('PROFESSIONAL DESIGN STANDARD'));
    expect(ai.prompts.single, contains('متجر ورد'));
    await ai.instantPreview(Lang.html, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(ai.prompts.length, 1, reason: 'the same description comes from the cache');
    await ai.instantPreview(Lang.kotlin, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(ai.prompts.last, contains('Jetpack Compose (Material 3)'));
    await ai.instantPreview(Lang.html, 'متجر ورد بسلة وطلب عبر واتساب', fresh: true);
    expect(ai.prompts.length, 3);
  });

  testWidgets('wizard: language first, then the description with «معاينة فورية قبل الإنشاء» and feature chips', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(400 * 2, 1600 * 2);
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(ChangeNotifierProvider(create: (_) => AppState(), child: const MaterialApp(home: WizardScreen(kind: ProjectKind.single))));
    await t.pumpAndSettle();
    expect(find.text('بأي لغة نبني؟'), findsOneWidget);
    await t.tap(find.text('التالي'));
    await t.pumpAndSettle();
    expect(find.text('معاينة فورية قبل الإنشاء'), findsOneWidget);
    expect(find.text('أضف ميزة بضغطة'), findsOneWidget);
    await t.tap(find.text('واتساب'));
    await t.pumpAndSettle();
    expect(find.textContaining('زر تواصل عبر واتساب'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
