import 'package:alpha/generator/app_files.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/services/ai.dart';
import 'package:flutter_test/flutter_test.dart';

// The new design engine: the AI returns a small JSON PLAN; Alpha renders the screens locally.
const _plan = '{"title":"مخبز","mode":"light","primary":"#C8873A","accent":"#F2C14E","font":"readex","radius":22,'
    '"nav":"floating","screens":[{"name":"الرئيسية","icon":"home","tab":true,"blocks":[{"type":"hero","title":"صباحك أحلى"},'
    '{"type":"grid","table":"products"}]},{"name":"حسابي","icon":"person","tab":true,"blocks":[{"type":"profile"}]}]}';

class _FakeAi extends AiDesigner {
  _FakeAi() : super(claudeKey: 'x', geminiKeys: const []);
  final prompts = <String>[];
  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000, int? thinking = 0, Duration perCall = const Duration(seconds: 50), Duration budget = const Duration(seconds: 100)}) async {
    prompts.add(prompt);
    return '```json\n$_plan\n```';
  }
}

class _BadAi extends AiDesigner {
  _BadAi() : super(claudeKey: 'x', geminiKeys: const []);
  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000, int? thinking = 0, Duration perCall = const Duration(seconds: 50), Duration budget = const Duration(seconds: 100)}) async => 'عذراً';
}

void main() {
  test('design first: a plan becomes a full rendered prototype, the admin app takes the customer brand, files per app', () async {
    final p = Project(
      id: '1', base: 'bakery', title: 'مخبز', lang: Lang.flutter, kind: ProjectKind.pair, backend: BackendType.supabase,
      auth: AuthMode.emailCode, brief: 'مخبز يستقبل طلبات التوصيل',
      schema: schemaPresets.firstWhere((x) => x.id == 'store').build(),
      apps: Project.unitsFor('bakery', 'مخبز', ProjectKind.pair),
    );
    final ai = _FakeAi();
    final customer = await ai.designPrototype(p, p.apps[0]);
    final admin = await ai.designPrototype(p, p.apps[1], brandFrom: customer);
    // The rendered prototype is a full interactive page with the review switcher and the owner's data.
    expect(customer, startsWith('<!doctype html>'));
    expect(customer, contains('alpha-screens'));
    expect(customer, contains('--p:#C8873A'));
    expect(customer, contains('صباحك أحلى'));
    // The plan prompt states the platform, role, the owner's data and the block guide.
    final first = ai.prompts[0];
    expect(first, contains('Flutter'));
    expect(first, contains('CUSTOMER'));
    expect(first, contains('products'));
    expect(first, contains('"type":"grid"'));
    // The admin app is asked to reuse the customer's primary color.
    expect(ai.prompts[1], contains('#C8873A'));

    p.design = AiDesign(screens: {p.apps[0].slug: customer, p.apps[1].slug: admin});
    expect(p.design.hasPrototype, isTrue);
    expect(p.design.hasSkin, isFalse);
    final files = projectFiles(Project.fromJson(p.toJson()));
    expect(files['apps/bakery-customer/design/design.html'], contains('alpha-screens'));
    expect(files['apps/bakery-admin/design/design.html'], isNotNull);
    expect(files['apps/bakery-customer/alpha.json'], isNot(contains('"ai": true')));
  });

  test('a plan with no screens is refused (so a broken answer never produces an empty design)', () async {
    final p = Project(id: '1', base: 'x', title: 'x', lang: Lang.html, kind: ProjectKind.single, apps: Project.unitsFor('x', 'x', ProjectKind.single));
    expect(() => _BadAi().designPrototype(p, p.apps.first), throwsA(anything));
  });
}
