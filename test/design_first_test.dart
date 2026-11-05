import 'package:alpha/generator/app_files.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/services/ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI is replaced by a stand-in that records the prompts and answers with a prototype.
class _FakeAi extends AiDesigner {
  _FakeAi() : super(claudeKey: 'x', geminiKeys: const []);
  final prompts = <String>[];

  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000}) async {
    prompts.add(prompt);
    final body = List.filled(80, '<div class="card">منتج</div>').join();
    return 'Here it is:\n```html\n<!doctype html><html dir="rtl"><body><nav id="alpha-screens"></nav>$body</body></html>\n```';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('design first: each app drawn as a whole prototype, the admin app takes the customer brand, files written per app', () async {
    final p = Project(
      id: '1', base: 'bakery', title: 'مخبز', lang: Lang.flutter, kind: ProjectKind.pair, backend: BackendType.supabase,
      auth: AuthMode.emailCode, brief: 'مخبز يستقبل طلبات التوصيل',
      schema: schemaPresets.firstWhere((x) => x.id == 'store').build(),
      apps: Project.unitsFor('bakery', 'مخبز', ProjectKind.pair),
    );
    final ai = _FakeAi();
    final customer = await ai.designPrototype(p, p.apps[0]);
    final admin = await ai.designPrototype(p, p.apps[1], brandFrom: customer);
    expect(customer, startsWith('<!doctype html>'));
    final first = ai.prompts[0], second = ai.prompts[1];
    expect(first, contains('PROFESSIONAL DESIGN STANDARD'));
    expect(first, contains('alpha-screens'));
    expect(first, contains('Flutter Material 3'));
    expect(first, contains('CUSTOMER app'));
    expect(first, contains('6-digit email code'));
    expect(first, contains('المنتجات'));
    expect(second, contains('ADMIN'));
    expect(second, contains('Use the SAME brand'));

    final revised = await ai.designPrototype(p, p.apps[0], current: customer, change: 'ألوان ذهبية');
    expect(ai.prompts.last, contains('Change requested by the owner'));
    expect(ai.prompts.last, contains('ألوان ذهبية'));

    p.design = AiDesign(screens: {p.apps[0].slug: revised, p.apps[1].slug: admin});
    expect(p.design.hasPrototype, isTrue);
    expect(p.design.hasSkin, isFalse);
    final again = Project.fromJson(p.toJson());
    final files = projectFiles(again);
    expect(files['apps/bakery-customer/design/design.html'], contains('alpha-screens'));
    expect(files['apps/bakery-admin/design/design.html'], isNotNull);
    expect(files['apps/bakery-customer/alpha.json'], isNot(contains('"ai": true')), reason: 'a prototype is built as code, not as a skin');
  });

  test('a design answer without a real page is refused', () async {
    final p = Project(id: '1', base: 'x', title: 'x', lang: Lang.html, kind: ProjectKind.single, apps: Project.unitsFor('x', 'x', ProjectKind.single));
    final ai = _BadAi();
    expect(() => ai.designPrototype(p, p.apps.first), throwsException);
  });
}

class _BadAi extends AiDesigner {
  _BadAi() : super(claudeKey: 'x', geminiKeys: const []);
  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000}) async => 'sorry';
}
