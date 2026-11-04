import 'package:alpha/generator/app_files.dart';
import 'package:alpha/generator/firestore_rules.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/generator/sql_generator.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/models/schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset is a valid schema', () {
    for (final p in schemaPresets) {
      expect(p.build().validate(), isEmpty, reason: p.id);
    }
  });

  test('identifiers are made safe', () {
    expect(slugIdent('Order Items'), 'order_items');
    expect(slugIdent('طلبات', fallback: 'table'), startsWith('table'));
    expect(slugApp('My Bakery!'), 'my-bakery');
    expect(isIdent(slugIdent('123abc')), isTrue);
  });

  test('validation catches broken schemas', () {
    final s = DbSchema(tables: [
      DbTable(name: 'orders', label: 'x', columns: [DbColumn(name: 'id', label: 'id')]),
      DbTable(name: 'orders', label: 'y', columns: [DbColumn(name: 'status', label: 's', type: ColumnType.choice)]),
    ]);
    final errors = s.validate();
    expect(errors.any((e) => e.contains('محجوز')), isTrue);
    expect(errors.any((e) => e.contains('مكرر')), isTrue);
    expect(errors.any((e) => e.contains('خيارات')), isTrue);
  });

  test('SQL has RLS, guards, notifications and realtime for every table', () {
    final schema = schemaPresets.firstWhere((p) => p.id == 'store').build();
    final sql = SqlGenerator('bakery', schema, admins: ['Owner@Example.com']).build();
    for (final t in schema.tables) {
      expect(sql, contains('alter table public.bakery_${t.name} enable row level security'));
    }
    expect(sql, contains("insert into public.bakery_admins (email) values ('owner@example.com')"));
    expect(sql, contains('bakery_orders_guard'));
    expect(sql, contains('new.status := old.status'));
    expect(sql, contains("values ('admin', 'الطلبات: جديد'"));
    expect(sql, contains('new.customer_id is distinct from auth.uid()'));
    expect(sql, contains("alter publication supabase_realtime add table public.bakery_orders"));
    expect(sql, contains('create or replace function public.bakery_stats()'));
    // Quotes in labels can never break the script.
    final tricky = DbSchema(tables: [
      DbTable(name: 'notes', label: "it's", notifyOnInsert: NotifyTarget.admin, columns: [
        DbColumn(name: 'kind', label: 'k', type: ColumnType.choice, options: ["a'b", 'c'], defaultValue: "a'b"),
      ]),
    ]);
    final s2 = SqlGenerator('p', tricky).build();
    expect(s2, contains("'it''s: جديد'"));
    expect(s2, contains("in ('a''b', 'c')"));
  });

  test('firestore rules cover every collection', () {
    final schema = schemaPresets.firstWhere((p) => p.id == 'store').build();
    final rules = FirestoreRulesGenerator('bakery', schema).build();
    expect(rules, startsWith("rules_version = '2';"));
    for (final t in schema.tables) {
      expect(rules, contains('match /bakery_${t.name}/{id}'));
    }
    expect(rules, contains('affectedKeys().hasAny(["status"])'));
    expect('{'.allMatches(rules).length, '}'.allMatches(rules).length);
  });

  test('project files: one config per app, server files per backend', () {
    final p = Project(
      id: '1',
      base: 'bakery',
      title: 'مخبز',
      lang: Lang.flutter,
      kind: ProjectKind.pair,
      backend: BackendType.supabase,
      auth: AuthMode.emailPassword,
      push: true,
      schema: schemaPresets.first.build(),
      apps: Project.unitsFor('bakery', 'مخبز', ProjectKind.pair),
    );
    final files = projectFiles(p, connections: {
      'bakery-admin': {'url': 'https://x.supabase.co', 'anonKey': 'k'}
    });
    expect(files.keys, containsAll(['apps/bakery-customer/alpha.json', 'apps/bakery-admin/alpha.json', 'projects/bakery/schema.sql']));
    expect(files['apps/bakery-admin/alpha.json'], contains('"anonKey": "k"'));
    expect(files['apps/bakery-customer/alpha.json'], contains('"role": "customer"'));
    final roundTrip = Project.fromJson(p.toJson());
    expect(roundTrip.schema.tables.length, p.schema.tables.length);
    expect(roundTrip.apps.map((a) => a.slug), ['bakery-customer', 'bakery-admin']);
  });
}
