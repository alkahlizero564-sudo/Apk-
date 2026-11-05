import 'package:alpha/app/state.dart';
import 'package:alpha/models/project.dart';
import 'package:alpha/ui/owner_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('«لمين؟»: mine → one app or both; a client → its database or a name', (t) async {
    SharedPreferences.setMockInitialValues({
      'client_dbs': '[{"ref":"abcdefghijklmnopqrst","label":"محل الورد","client":true,"region":"eu-central-1"}]',
    });
    t.view.physicalSize = const Size(400 * 2, 900 * 2);
    t.view.devicePixelRatio = 2;
    NewProjectChoice? got;
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () async => got = await pickNewProject(c), child: const Text('go'))))),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('لمين التطبيق؟'), findsOneWidget);
    await t.tap(find.text('لزبون'));
    await t.pumpAndSettle();
    expect(find.text('محل الورد'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('محل الورد'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('التطبيقين'));
    await t.pumpAndSettle();
    expect(got?.kind, ProjectKind.pair);
    expect(got?.client?.ref, 'abcdefghijklmnopqrst');
    expect(got?.clientName, 'محل الورد');

    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('لي (المشروع الأساسي)'));
    await t.pumpAndSettle();
    await t.tap(find.text('تطبيق واحد'));
    await t.pumpAndSettle();
    expect(got?.kind, ProjectKind.single);
    expect(got?.clientName, '');

    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('لزبون'));
    await t.pumpAndSettle();
    await t.tap(find.text('أضف زبوناً جديداً'));
    await t.pumpAndSettle();
    expect(find.text('تحقّق وأضف المشروع'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
