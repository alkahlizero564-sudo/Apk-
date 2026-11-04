import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
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
  final _gemini = TextEditingController();

  @override
  void initState() {
    super.initState();
    Storage.secret(Storage.claudeKey).then((t) => _claude.text = t);
    Storage.secret(Storage.geminiKey).then((t) => _gemini.text = t);
  }

  @override
  Widget build(BuildContext context) => frame(
        'الذكاء الاصطناعي',
        'Claude (الأفضل للكود) أو Gemini (مجاني بحدود) أو الاثنين: إن نفد أحدهما يُستخدم الآخر تلقائياً.',
        link: 'https://console.anthropic.com/settings/keys',
        linkLabel: 'مفتاح Claude',
        [
          TextField(controller: _claude, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Claude API key (sk-ant-…)')),
          TextField(controller: _gemini, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Gemini API key (AIza…)')),
        ],
        onSave: () => run(() async {
          final done = await context.read<AppState>().saveKeys(claude: _claude.text, gemini: _gemini.text);
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
