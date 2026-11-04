import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../services/ai.dart';
import '../../services/storage.dart';
import '../../services/supabase_admin.dart';
import '../widgets.dart';

/// GitHub (where apps are built), AI keys, Supabase and Firebase. Keys stay encrypted on the phone and are
/// copied as encrypted repository secrets for the workflows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const Text('المفاتيح تُحفظ مشفّرة في الهاتف، وتُنسخ مشفّرة كـ Secrets في المستودع لتستخدمها عمليات البناء.',
              style: TextStyle(color: AlphaColors.muted, height: 1.6)),
          const SizedBox(height: 10),
          _Item(
            icon: Icons.code_rounded,
            color: AlphaColors.text,
            title: 'GitHub',
            subtitle: s.hasGitHub ? '${s.repo} · ${s.branch}' : 'مطلوب: التوكن والمستودع',
            ok: s.hasGitHub,
            onTap: () => _sheet(context, const _GitHubForm()),
          ),
          _Item(
            icon: Icons.auto_awesome_rounded,
            color: AlphaColors.amber,
            title: 'الذكاء الاصطناعي',
            subtitle: s.hasAi ? 'متصل (Claude / Gemini)' : 'اختياري: لتصميم الجداول وكتابة الكود وإصلاح الأخطاء',
            ok: s.hasAi,
            onTap: () => _sheet(context, const _AiForm()),
          ),
          _Item(
            icon: Icons.bolt_rounded,
            color: AlphaColors.teal,
            title: 'Supabase',
            subtitle: s.hasSupabase ? 'متصل · ${s.supabaseRef.isEmpty ? 'اختر المشروع' : s.supabaseRef}' : 'لقاعدة البيانات PostgreSQL والصلاحيات والدخول',
            ok: s.hasSupabase && s.supabaseRef.isNotEmpty,
            onTap: () => _sheet(context, const _SupabaseForm()),
          ),
          _Item(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFFA000),
            title: 'Firebase',
            subtitle: s.hasFirebase ? 'متصل (Service Account)' : 'للإشعارات Push، أو Firestore كقاعدة بيانات',
            ok: s.hasFirebase,
            onTap: () => _sheet(context, const _FirebaseForm()),
          ),
          _Item(
            icon: Icons.mark_email_unread_rounded,
            color: AlphaColors.pink,
            title: 'البريد (رموز التأكيد)',
            subtitle: 'خادم بريد SMTP لإرسال رمز تأكيد الحساب للعملاء (Gmail يعمل)',
            ok: false,
            onTap: () => _sheet(context, const _SmtpForm()),
          ),
          _Item(
            icon: Icons.system_update_rounded,
            color: AlphaColors.blue,
            title: 'التحديثات والتثبيت',
            subtitle: s.updatesRepo.isNotEmpty
                ? 'التطبيقات المثبتة تتحدّث من ${s.updatesRepo}'
                : 'لتصل التحديثات للتطبيقات المثبتة بدون حساب GitHub',
            ok: s.updatesRepo.isNotEmpty,
            onTap: () => _sheet(context, const _UpdatesForm()),
          ),
          const SectionTitle('عن Alpha'),
          const GlassCard(
            child: Text(
              'Alpha يبني تطبيقات HTML و PHP و Flutter و Python و Kotlin بمحرّك مختبر لكل لغة، ويكتب قاعدة البيانات '
              '(الجداول، الصلاحيات RLS، الأدوار، الإشعارات) تلقائياً لـ Supabase أو Firebase، ويبني ويوقّع الـ APK في GitHub Actions.',
              style: TextStyle(color: AlphaColors.muted, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  static void _sheet(BuildContext context, Widget child) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom), child: child),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.color, required this.title, required this.subtitle, required this.ok, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: ok ? AlphaColors.ok : AlphaColors.muted),
          ],
        ),
      );
}

abstract class _FormState<T extends StatefulWidget> extends State<T> {
  bool busy = false;

  Future<void> run(Future<String> Function() action) async {
    setState(() => busy = true);
    try {
      final msg = await action();
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, msg);
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget frame(String title, String help, List<Widget> fields, {String? link, String? linkLabel, required VoidCallback onSave}) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(help, style: const TextStyle(color: AlphaColors.muted, height: 1.6, fontSize: 13)),
          if (link != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(linkLabel ?? 'افتح'),
              ),
            ),
          const SizedBox(height: 8),
          ...fields.expand((f) => [f, const SizedBox(height: 10)]),
          GradientButton(label: 'حفظ', icon: Icons.save_rounded, busy: busy, onPressed: onSave),
        ],
      );
}

class _GitHubForm extends StatefulWidget {
  const _GitHubForm();
  @override
  State<_GitHubForm> createState() => _GitHubFormState();
}

class _GitHubFormState extends _FormState<_GitHubForm> {
  final _token = TextEditingController();
  late final _repo = TextEditingController(text: context.read<AppState>().repo);
  late final _branch = TextEditingController(text: context.read<AppState>().branch);

  @override
  void initState() {
    super.initState();
    Storage.secret(Storage.githubToken).then((t) => _token.text = t);
  }

  @override
  Widget build(BuildContext context) => frame(
        'GitHub',
        'التوكن (Fine-grained أو Classic) يحتاج صلاحيات: Contents و Actions و Secrets و Variables (قراءة وكتابة) للمستودع. المستودع يحتوي محرّكات Alpha وعمليات البناء.',
        link: 'https://github.com/settings/tokens/new?scopes=repo,workflow&description=Alpha',
        linkLabel: 'أنشئ توكن',
        [
          TextField(controller: _token, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Token')),
          TextField(controller: _repo, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'المستودع owner/name')),
          TextField(controller: _branch, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الفرع (فارغ = الافتراضي)')),
        ],
        onSave: () => run(() async {
          final s = context.read<AppState>();
          final user = await s.connectGitHub(_token.text, _repo.text, _branch.text);
          s.refreshRemote().ignore();
          return 'متصل كـ $user';
        }),
      );
}

class _AiForm extends StatefulWidget {
  const _AiForm();
  @override
  State<_AiForm> createState() => _AiFormState();
}

class _AiFormState extends _FormState<_AiForm> {
  final _claude = TextEditingController();
  final _gemini = List.generate(Storage.geminiKeys.length, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    Storage.secret(Storage.claudeKey).then((t) => _claude.text = t);
    for (var i = 0; i < Storage.geminiKeys.length; i++) {
      Storage.secret(Storage.geminiKeys[i].local).then((t) => _gemini[i].text = t);
    }
  }

  @override
  Widget build(BuildContext context) => frame(
        'الذكاء الاصطناعي',
        'Claude (الأفضل للكود) أو Gemini (مجاني بحدود) أو الاثنين. حتى 4 مفاتيح Gemini: إذا نفد مفتاح يُستخدم التالي، ثم Claude تلقائياً.',
        link: 'https://console.anthropic.com/settings/keys',
        linkLabel: 'مفتاح Claude',
        [
          TextField(controller: _claude, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Claude API key (sk-ant-…)')),
          _GeminiModelTile(keyOf: () => _gemini.map((c) => c.text.trim()).firstWhere((k) => k.isNotEmpty, orElse: () => '')),
          for (var i = 0; i < _gemini.length; i++)
            TextField(
              controller: _gemini[i],
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: i == 0 ? 'Gemini API key (AIza…)' : 'Gemini API key ${i + 1} (اختياري)'),
            ),
        ],
        onSave: () => run(() async {
          final done = await context.read<AppState>().saveKeys(claude: _claude.text, gemini: [for (final c in _gemini) c.text]);
          return done.isEmpty ? 'حُفظ في الهاتف' : 'حُفظ في الهاتف وفي المستودع: ${done.join('، ')}';
        }),
      );
}

class _SupabaseForm extends StatefulWidget {
  const _SupabaseForm();
  @override
  State<_SupabaseForm> createState() => _SupabaseFormState();
}

class _SupabaseFormState extends _FormState<_SupabaseForm> {
  final _token = TextEditingController();
  late final _ref = TextEditingController(text: context.read<AppState>().supabaseRef);
  List<SupabaseProject>? _projects;

  @override
  void initState() {
    super.initState();
    Storage.secret(Storage.supabaseToken).then((t) => _token.text = t);
  }

  Future<void> _load() async {
    try {
      final list = await SupabaseAdmin(_token.text.trim()).projects();
      setState(() => _projects = list);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => frame(
        'Supabase',
        'Access Token من حسابك (Account > Access Tokens)، ثم اختر المشروع. Alpha ينشئ فيه الجداول والصلاحيات والدخول ودوال الإشعارات.',
        link: 'https://supabase.com/dashboard/account/tokens',
        linkLabel: 'أنشئ Access Token',
        [
          TextField(controller: _token, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Access token (sbp_…)')),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.list_rounded), label: const Text('اعرض مشاريعي')),
          if (_projects != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _projects!)
                  ChoiceChip(label: Text('${p.name} (${p.region})'), selected: _ref.text == p.ref, onSelected: (_) => setState(() => _ref.text = p.ref)),
              ],
            ),
          TextField(controller: _ref, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Project ref')),
        ],
        onSave: () => run(() async {
          final done = await context.read<AppState>().saveKeys(supabaseToken: _token.text, supabaseProjectRef: _ref.text);
          return done.isEmpty ? 'حُفظ في الهاتف' : 'حُفظ: ${done.join('، ')}';
        }),
      );
}

class _FirebaseForm extends StatefulWidget {
  const _FirebaseForm();
  @override
  State<_FirebaseForm> createState() => _FirebaseFormState();
}

class _FirebaseFormState extends _FormState<_FirebaseForm> {
  final _json = TextEditingController();

  @override
  void initState() {
    super.initState();
    Storage.secret(Storage.firebaseServiceAccount).then((t) => _json.text = t);
  }

  @override
  Widget build(BuildContext context) => frame(
        'Firebase',
        'Firebase console > Project settings > Service accounts > Generate new private key، ثم الصق محتوى الملف كاملاً. '
            'Alpha يسجّل تطبيقاتك فيه ويجهّز الإشعارات وقواعد Firestore. (Cloud Functions للإشعارات مع Firestore تحتاج خطة Blaze.)',
        link: 'https://console.firebase.google.com/',
        linkLabel: 'Firebase console',
        [
          TextField(
            controller: _json,
            minLines: 4,
            maxLines: 8,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(labelText: 'Service account JSON', alignLabelWithHint: true),
          ),
        ],
        onSave: () => run(() async {
          final done = await context.read<AppState>().saveKeys(firebaseJson: _json.text);
          return done.isEmpty ? 'حُفظ في الهاتف' : 'حُفظ: ${done.join('، ')}';
        }),
      );
}

class _SmtpForm extends StatefulWidget {
  const _SmtpForm();
  @override
  State<_SmtpForm> createState() => _SmtpFormState();
}

class _SmtpFormState extends _FormState<_SmtpForm> {
  final _host = TextEditingController(text: 'smtp.gmail.com');
  final _port = TextEditingController(text: '587');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) => frame(
        'البريد (رموز التأكيد)',
        'عند اختيار «بريد + رمز تأكيد» يرسل Supabase رمزاً من 6 أرقام إلى بريد العميل عبر هذا الخادم. '
            'مع Gmail: فعّل التحقق بخطوتين ثم أنشئ «كلمة مرور تطبيق» وضعها هنا (ليست كلمة مرور حسابك). '
            'يُحفظ مشفّراً في المستودع ويُطبَّق عند «تجهيز السيرفر».',
        link: 'https://myaccount.google.com/apppasswords',
        linkLabel: 'كلمة مرور تطبيق Gmail',
        [
          TextField(controller: _host, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'SMTP host')),
          TextField(controller: _port, textDirection: TextDirection.ltr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port (587 أو 465)')),
          TextField(controller: _user, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد المرسِل')),
          TextField(controller: _pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة مرور التطبيق')),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المرسِل (يظهر للعميل)')),
        ],
        onSave: () => run(() async {
          if (_user.text.trim().isEmpty || _pass.text.trim().isEmpty) throw Exception('اكتب البريد وكلمة مرور التطبيق');
          await context.read<AppState>().saveSmtp({
            'host': _host.text.trim(),
            'port': _port.text.trim(),
            'user': _user.text.trim(),
            'pass': _pass.text.trim(),
            'from': _user.text.trim(),
            'name': _name.text.trim().isEmpty ? 'Alpha' : _name.text.trim(),
          });
          return 'حُفظ. اضغط «تجهيز السيرفر» في المشروع ليُطبَّق';
        }),
      );
}

class _UpdatesForm extends StatefulWidget {
  const _UpdatesForm();
  @override
  State<_UpdatesForm> createState() => _UpdatesFormState();
}

class _UpdatesFormState extends _FormState<_UpdatesForm> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return frame(
      'التحديثات والتثبيت',
      'مستودعك خاص (للحماية)، لذلك ينشئ Alpha مستودعاً عاماً صغيراً لا يحتوي أي كود، فقط ملفات APK وأرقام النسخ. '
          'منه تتحدّث التطبيقات المثبتة على هواتف عملائك: عند كل بناء جديد يظهر لهم «تحديث جديد» ويُثبَّت من داخل التطبيق بدون GitHub، '
          'ومع Supabase يصلهم إشعار Push حتى والتطبيق مغلق. '
          'أنت تثبّت تطبيقاتك من داخل Alpha بزر «تثبيت» مباشرة.\n\nالتوكن يحتاج صلاحية إنشاء مستودعات (repo).',
      [
        if (s.updatesRepo.isNotEmpty) GlassCard(child: Text('مفعّل: ${s.updatesRepo}', style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      onSave: () => run(() async {
        final repo = await context.read<AppState>().createUpdatesRepo();
        return 'جاهز: $repo. التطبيقات التي تُبنى من الآن تتحدّث تلقائياً';
      }),
    );
  }
}

/// The Gemini model in use, and a button that lists every model the key can use.
class _GeminiModelTile extends StatelessWidget {
  const _GeminiModelTile({required this.keyOf});
  final String Function() keyOf;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return GlassCard(
      onTap: () => _pick(context),
      child: Row(
        children: [
          const Icon(Icons.model_training_rounded, color: AlphaColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نموذج Gemini', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(s.geminiModel + (s.geminiFirst ? ' · الأساسي' : ''),
                    textDirection: TextDirection.ltr, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const Text('اختر', style: TextStyle(color: AlphaColors.violet, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    var key = keyOf();
    if (key.isEmpty) {
      final saved = await Storage.geminiKeyValues();
      key = saved.isEmpty ? '' : saved.first;
    }
    if (!context.mounted) return;
    if (key.isEmpty) {
      showMessage(context, 'اكتب مفتاح Gemini أولاً', error: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GeminiModelSheet(apiKey: key),
    );
  }
}

class _GeminiModelSheet extends StatefulWidget {
  const _GeminiModelSheet({required this.apiKey});
  final String apiKey;

  @override
  State<_GeminiModelSheet> createState() => _GeminiModelSheetState();
}

class _GeminiModelSheetState extends State<_GeminiModelSheet> {
  List<({String id, String name, String description})>? _models;
  String? _error;
  String _query = '';
  late String _selected = context.read<AppState>().geminiModel;
  late bool _first = context.read<AppState>().geminiFirst;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AiDesigner.listGeminiModels(widget.apiKey).then((m) {
      if (mounted) setState(() => _models = m);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().setGeminiModel(_selected, first: _first);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'النموذج: $_selected');
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = (_models ?? const []).where((m) => q.isEmpty || m.id.toLowerCase().contains(q) || m.name.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('اختر نموذج Gemini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('يُستخدم في الفهم والتصميم والبيانات على الهاتف، وفي كتابة الكود وإصلاحه في GitHub Actions. إذا لم ينجح يُجرَّب غيره تلقائياً.',
              style: TextStyle(color: AlphaColors.muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 10),
          TextField(
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'بحث: pro، flash…'),
            onChanged: (v) => setState(() => _query = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _first,
            onChanged: (v) => setState(() => _first = v),
            title: const Text('Gemini هو النموذج الأساسي', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('إذا أطفأته يُجرَّب Claude أولاً (عند وجود مفتاحه)', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: _error != null
                ? Text(_error!, style: const TextStyle(color: AlphaColors.bad))
                : _models == null
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    : RadioGroup<String>(
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v!),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final m in shown)
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: m.id,
                                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(m.id, textDirection: TextDirection.ltr, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                              ),
                            if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا نتائج', textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
          ),
          const SizedBox(height: 10),
          GradientButton(label: 'استخدم هذا النموذج', icon: Icons.check_rounded, busy: _saving, onPressed: _models == null ? null : _save),
        ],
      ),
    );
  }
}
