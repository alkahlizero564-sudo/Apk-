import 'package:alpha/models/project.dart';
import 'package:alpha/services/ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with the given replies in turn and records the prompts.
class _Scripted extends AiDesigner {
  _Scripted(this.replies) : super(claudeKey: 'x', geminiKeys: const []);
  final List<String> replies;
  final prompts = <String>[];
  @override
  Future<String> ask(String prompt, {bool json = true, double temperature = 0.3, int maxTokens = 8000}) async {
    prompts.add(prompt);
    return replies.removeAt(0);
  }
}

const _good = '{"title":"درع الشبكة","summary":"تطبيق يفحص أجهزة شبكتي المنزلية ويحذرني من الأجهزة الغريبة",'
    '"screens":["فحص الشبكة","الأجهزة"],"features":["فحص كل الأجهزة المتصلة"],"data":["الأجهزة: الاسم، العنوان"],'
    '"texts":[],"notifications":[],"kind":"single","lang":"flutter","auth":"none","questions":[]}';

void main() {
  const idea = 'تطبيق Cybersecurity يفحص شبكة البيت ويعرض الأجهزة المتصلة وينبهني لو جهاز غريب دخل';

  test('every shape of answer is understood: fences, text around, a list, a wrapper, trailing commas, Arabic keys', () async {
    final shapes = [
      'هذا الفهم:\n```json\n$_good\n```\nأتمنى أن يفيد',
      '[$_good]',
      '{"understanding": $_good}',
      _good.replaceFirst('"questions":[]}', '"questions":[],}'),
      '{"الفكرة":"فاحص شبكة","الشاشات":["الفحص"],"الميزات":["تنبيه عند جهاز غريب"]}',
    ];
    for (final a in shapes) {
      final u = await _Scripted([a]).understand(idea);
      expect(u.summary.isNotEmpty || u.screens.isNotEmpty, isTrue, reason: a);
    }
  });

  test('cybersecurity and any other idea: the analyst is told every kind of app is valid', () async {
    final ai = _Scripted([_good]);
    final u = await ai.understand(idea, kind: ProjectKind.single, lang: Lang.flutter);
    expect(u.title, 'درع الشبكة');
    expect(ai.prompts.single, contains('cybersecurity'));
    expect(ai.prompts.single, contains(idea));
  });

  test('an unreadable answer: one repair round, then (if still unreadable) never blocked: understanding from the owner\'s words', () async {
    final repaired = _Scripted(['عذراً، هذا وصف التطبيق بدون JSON', _good]);
    expect((await repaired.understand(idea)).title, 'درع الشبكة');
    expect(repaired.prompts.last, contains('could not be read'));

    final never = _Scripted(['كلام', 'كلام أيضاً']);
    final u = await never.understand(idea);
    expect(u.features, isNotEmpty);
    expect(u.summary, contains('Cybersecurity'));
    expect(u.questions.single.q, contains('كتبنا الفهم من كلماتك'));
  });
}
