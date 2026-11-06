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
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000, int? thinking = 0, Duration perCall = const Duration(seconds: 50), Duration budget = const Duration(seconds: 100)}) async {
    prompts.add(prompt);
    return '```json\n{"title":"متجر ورد","mode":"light","primary":"#E11D48","accent":"#F59E0B","font":"tajawal","radius":18,"nav":"bar",'
        '"tables":[{"name":"products","label":"المنتجات","columns":[{"name":"title","label":"الاسم","type":"text"},{"name":"price","label":"السعر","type":"decimal"}]}],'
        '"screens":[{"name":"الرئيسية","icon":"home","tab":true,"blocks":[{"type":"hero","title":"متجر ورد"},{"type":"grid","table":"products"}]},'
        '{"name":"حسابي","icon":"person","tab":true,"blocks":[{"type":"profile"}]}]}\n```';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('instant preview from the description: a small plan rendered locally, cached', () async {
    SharedPreferences.setMockInitialValues({});
    final ai = _FakeAi();
    final html = await ai.instantPreview(Lang.html, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('متجر ورد')); // rendered from the plan
    expect(html, contains('--p:#E11D48'));
    expect(ai.prompts.single, contains('COMPACT JSON'));
    expect(ai.prompts.single, contains('متجر ورد'));
    await ai.instantPreview(Lang.html, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(ai.prompts.length, 1, reason: 'the same description comes from the cache');
    await ai.instantPreview(Lang.kotlin, 'متجر ورد بسلة وطلب عبر واتساب');
    expect(ai.prompts.last, contains('Kotlin'));
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
