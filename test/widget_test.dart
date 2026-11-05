import 'package:alpha/generator/app_files.dart';
import 'package:alpha/generator/firestore_rules.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/generator/sql_generator.dart';
import 'package:alpha/models/project.dart';
import 'dart:io';

import 'package:alpha/generator/custom_code.dart';
import 'package:alpha/models/schema.dart';
import 'package:alpha/services/ai.dart';
import 'package:alpha/ui/screens/preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('understanding: a checklist (like APK Fact); the brief keeps the owner\'s words first, then the approved list', () {
    final u = Understanding.fromJson({
      'title': 'مخبز الأمل', 'slug': 'amal-bakery', 'summary': 'طلبات توصيل خبز', 'kind': 'pair', 'lang': 'kotlin',
      'screens': ['الزبون: المنتجات بالصور والأسعار', 'الإدارة: الطلبات وتغيير الحالة', ''],
      'features': ['الاثنين: إشعار عند كل تغيير في الطلب'],
      'data': ['المنتجات: الاسم، السعر بالجنيه'], 'texts': ['الرغيف بـ 50 جنيه'], 'auth': 'email_code',
      'questions': [{'q': 'التوصيل مجاني؟', 'options': ['نعم', 'لا', 'فوق مبلغ معيّن']}],
    });
    expect(u.kind, ProjectKind.pair);
    expect(u.lang, Lang.kotlin);
    expect(u.auth, AuthMode.emailCode);
    expect(u.screens.length, 2);
    expect(u.questions.single.options.length, 3);
    final brief = u.toBrief('مخبز يستقبل طلبات الرغيف بـ 50 جنيه');
    expect(brief.indexOf('مخبز يستقبل طلبات'), lessThan(brief.indexOf('=== المواصفات')));
    expect(brief, contains('- الرغيف بـ 50 جنيه'));
    // Each app of a pair reads its own items and the shared ones.
    final admin = forApp(brief, 'admin');
    expect(admin, contains('الإدارة: الطلبات'));
    expect(admin, isNot(contains('الزبون: المنتجات')));
    expect(admin, contains('الاثنين: إشعار'));
    expect(() => Understanding.fromJson({'title': 'x'}), throwsException);
  });

  test('pasted code: language, file and packages', () {
    const dart = "import 'package:flutter/material.dart';\nimport 'package:fl_chart/fl_chart.dart';\nimport 'package:not_allowed/x.dart';\nvoid main() => runApp(const App());";
    expect(detectLang(dart), Lang.flutter);
    expect(detectLang('<?php echo 1;'), Lang.php);
    expect(detectLang('import flet as ft\nft.run(main)'), Lang.python);
    expect(detectLang('<!doctype html><html></html>'), Lang.html);
    expect(detectLang('package app.main\nimport androidx.compose.material3.Text\nfun x() {}'), Lang.kotlin);
    final libs = {
      'flutter': {'packages': [{'name': 'fl_chart'}, {'name': 'provider'}]},
    };
    final files = customFiles('shop', Lang.flutter, dart, libs);
    expect(files.keys, containsAll(['apps/shop/custom/lib/main.dart', 'apps/shop/custom/packages.txt']));
    expect(files['apps/shop/custom/packages.txt'], 'fl_chart\n');
  });

  test('instant preview page: engine + config + sample data, customer side', () async {
    final p = Project(
      id: '1', base: 'shop', title: 'متجر', lang: Lang.kotlin, kind: ProjectKind.single,
      schema: schemaPresets.firstWhere((x) => x.id == 'store').build(),
      apps: Project.unitsFor('shop', 'متجر', ProjectKind.single),
    );
    final html = await buildPreviewHtml(p, p.apps.first, admin: false);
    expect(html, contains('"preview":true'));
    expect(html, contains('"role":"customer"'));
    expect(html, contains('window.AlphaBackend'));
    expect(html, isNot(contains('gsap')));
    final out = Platform.environment['ALPHA_PREVIEW_OUT'];
    if (out != null) File(out).writeAsStringSync(html);
    // With an AI design: its CSS, the libraries its JS names (and only those), then its JS before app.js.
    p.design = AiDesign(css: ':root.ai .card{outline:1px solid gold}', js: 'window.AlphaDesign={onRender(){ if (window.gsap) gsap.to({}, {}); }}');
    final designed = await buildPreviewHtml(p, p.apps.first, admin: false);
    expect(designed, contains('outline:1px solid gold'));
    expect(designed, contains('GreenSock'));
    expect(designed, isNot(contains('VanillaTilt')));
    expect(designed.indexOf('window.AlphaDesign'), lessThan(designed.indexOf('Alpha HTML engine: screens')));
    expect(designed, contains('"ai":true'));
  });
}
