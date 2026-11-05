import 'package:alpha/generator/ai_edit.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Project store() => Project(
        id: '1',
        base: 'shop',
        title: 'متجر',
        lang: Lang.html,
        kind: ProjectKind.pair,
        backend: BackendType.supabase,
        schema: schemaPresets.firstWhere((p) => p.id == 'store').build(),
        theme: lookById('material')!.apply(ThemeSpec()),
        apps: Project.unitsFor('shop', 'متجر', ProjectKind.pair),
      );

  test('an AI edit: add a table and a field, remove a field, recolor; the original is untouched', () {
    final p = store();
    final tables = p.schema.toJson();
    final products = tables.firstWhere((t) => t['name'] == 'products');
    (products['columns'] as List).add({'name': 'discount', 'label': 'الخصم', 'type': 'decimal'});
    final orders = tables.firstWhere((t) => t['name'] == 'orders');
    (orders['columns'] as List).removeWhere((c) => c['name'] == 'address');
    tables.add({'name': 'offers', 'label': 'العروض', 'icon': 'star', 'owner': 'catalog', 'columns': [{'name': 'title', 'label': 'العرض', 'type': 'text'}]});
    final edit = AiEdit.fromJson('أضف عروض وخصم واحذف العنوان وغيّر اللون', {
      'summary': 'x',
      'tables': tables,
      'theme': {'school': 'glass', 'seed': '#10b981', 'home': 'bento', 'list': 'nonsense'},
      'headline': 'عروض اليوم',
      'code_request': '',
    });
    final d = edit.applyTo(p);
    expect(d.schema.validate(), isEmpty);
    expect(d.theme.school, 'glass');
    expect(d.theme.seed, '#10B981');
    expect(d.theme.home, 'bento');
    expect(d.theme.list, isNot('nonsense'));
    expect(d.headline, 'عروض اليوم');
    expect(d.brief, contains('أضف عروض'));
    expect(p.schema.tables.length, 3, reason: 'the original project is not changed');
    final changes = describeChanges(p, d).map((c) => c.toString()).join('\n');
    expect(changes, contains('add: قسم جديد «العروض»'));
    expect(changes, contains('add: حقل «الخصم»'));
    expect(changes, contains('remove: حقل «العنوان»'));
    expect(changes, contains('مدرسة التصميم'));
    expect(needsServer(p, d), isTrue);
  });

  test('a design-only edit does not touch the server', () {
    final p = store();
    final d = AiEdit.fromJson('داكن', {'theme': {'mode': 'dark'}}).applyTo(p);
    expect(needsServer(p, d), isFalse);
    expect(describeChanges(p, d).single.kind, ChangeKind.change);
  });
}
