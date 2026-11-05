import 'package:alpha/generator/app_files.dart';
import 'package:alpha/generator/design_contract.dart';
import 'package:alpha/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the AI answer is split into its files; the CSS cannot reach the network', () {
    const answer = 'Here:\n```json design.json\n{"school":"glass"}\n```\ntext\n```css design.css\n@import url(https://x.y/a.css);\n'
        ':root.ai .hero{background:url("https://evil/a.png") center, url(data:image/svg+xml;utf8,<svg/>)}\n```\n'
        '```js design.js\nwindow.AlphaDesign={onRender(){}}\n```\n```markdown spec.md\n# Spec\n```';
    final f = codeFiles(answer);
    expect(f.keys, containsAll(['design.json', 'design.css', 'design.js', 'spec.md', 'css', 'js']));
    final css = sanitizeDesignCss(f['design.css']!);
    expect(css, isNot(contains('@import')));
    expect(css, isNot(contains('evil')));
    expect(css, contains('data:image/svg+xml'));
  });

  test('one app or both; a project for a client keeps the client and its own database', () {
    expect(Project.unitsFor('shop', 'متجر', ProjectKind.single).single.role, 'single');
    expect(Project.unitsFor('shop', 'متجر', ProjectKind.pair).map((a) => a.role), ['customer', 'admin']);
    expect(ProjectKind.parse('nonsense'), ProjectKind.single);
    final p = Project(id: '1', base: 'roses', title: 'ورد', lang: Lang.html, kind: ProjectKind.pair, backend: BackendType.supabase,
        clientName: 'محل الورد', supabaseRef: 'abcdefghijklmnopqrst', apps: Project.unitsFor('roses', 'ورد', ProjectKind.pair));
    final again = Project.fromJson(p.toJson());
    expect(again.forClient, isTrue);
    expect(again.clientName, 'محل الورد');
    expect(again.supabaseRef, 'abcdefghijklmnopqrst');
    expect(Project.fromJson({...p.toJson()}..remove('client')).forClient, isFalse);
  });

  test('an AI design travels with the project and into each app folder', () {
    final p = Project(id: '1', base: 'cafe', title: 'مقهى', lang: Lang.flutter, kind: ProjectKind.single,
        apps: Project.unitsFor('cafe', 'مقهى', ProjectKind.single),
        design: AiDesign(css: ':root.ai .card{color:red}', js: 'window.AlphaDesign={}', spec: '# spec', summary: 's'));
    final again = Project.fromJson(p.toJson());
    expect(again.design.css, contains('color:red'));
    final files = projectFiles(again);
    expect(files['apps/cafe/design/spec.md'], '# spec');
    expect(files['apps/cafe/alpha.json'], contains('"ai": true'));
    final plain = Project.fromJson({...p.toJson()}..remove('design'));
    expect(projectFiles(plain).keys.where((k) => k.contains('/design/')), isEmpty);
  });
}
