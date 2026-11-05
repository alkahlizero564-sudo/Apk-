import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/state.dart';
import '../app/theme.dart';
import '../models/project.dart';
import 'widgets.dart';

/// Who the new project is for, and how many apps.
class NewProjectChoice {
  const NewProjectChoice({required this.kind, this.client, this.clientName = ''});
  final ProjectKind kind;
  final ClientDb? client; // the client's database (null: the owner's main project, or a client without a database)
  final String clientName; // empty: the owner's own project
}

/// «أنشئ تطبيقاً»: first «لمين؟» (mine / a client → the client's database), then one app or both.
Future<NewProjectChoice?> pickNewProject(BuildContext context) => showModalBottomSheet<NewProjectChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: const SafeArea(child: _NewProjectSheet()),
      ),
    );

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

enum _Stage { owner, client, addDb, kind }

class _NewProjectSheetState extends State<_NewProjectSheet> {
  _Stage _stage = _Stage.owner;
  List<ClientDb> _dbs = [];
  ClientDb? _client;
  String _clientName = '';
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AppState>().clientDbs().then((v) => mounted ? setState(() => _dbs = v) : null);
  }

  Widget _big(IconData icon, String title, String sub, VoidCallback onTap, {Color color = AlphaColors.violet}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AlphaColors.surface2,
              border: Border.all(color: AlphaColors.line),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.4)),
                ]),
              ),
              const Icon(Icons.chevron_left_rounded, color: AlphaColors.muted),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final title = switch (_stage) {
      _Stage.owner => 'لمين التطبيق؟',
      _Stage.client => 'قاعدة بيانات الزبون',
      _Stage.addDb => 'أضف قاعدة بيانات زبون',
      _Stage.kind => _clientName.isEmpty ? 'كم تطبيق؟' : 'كم تطبيق لـ «$_clientName»؟',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            if (_stage != _Stage.owner)
              IconButton(
                onPressed: () => setState(() => _stage = _stage == _Stage.addDb ? _Stage.client : _Stage.owner),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          ...switch (_stage) {
            _Stage.owner => [
                _big(Icons.home_rounded, 'لي (المشروع الأساسي)', 'في مشروع Supabase الأساسي الخاص بك (من الإعدادات)', () => setState(() {
                      _client = null;
                      _clientName = '';
                      _stage = _Stage.kind;
                    })),
                _big(Icons.person_rounded, 'لزبون', 'في قاعدة بيانات خاصة بالزبون: منفصلة عن مشروعك وعن باقي الزبائن', () => setState(() => _stage = _Stage.client),
                    color: AlphaColors.amber),
              ],
            _Stage.client => [
                if (_dbs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('لا توجد قواعد بيانات زبائن بعد. أضف أول واحدة:', style: TextStyle(color: AlphaColors.muted)),
                  ),
                for (final d in _dbs)
                  _big(d.inClientAccount ? Icons.person_rounded : Icons.dns_rounded, d.label,
                      '${d.inClientAccount ? 'حساب الزبون' : 'في حسابك'} · ${d.ref}', () => setState(() {
                            _client = d;
                            _clientName = d.label;
                            _stage = _Stage.kind;
                          }),
                      color: AlphaColors.teal),
                GradientButton(label: 'أضف زبوناً جديداً', icon: Icons.add_circle_rounded, onPressed: () => setState(() => _stage = _Stage.addDb)),
                const SizedBox(height: 14),
                const Text('أو زبون بدون قاعدة بيانات (تطبيق يحفظ على الجهاز):', style: TextStyle(color: AlphaColors.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'اسم الزبون، مثلاً: محل الورد'))),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final n = _name.text.trim();
                      if (n.isEmpty) return;
                      setState(() {
                        _client = null;
                        _clientName = n;
                        _stage = _Stage.kind;
                      });
                    },
                    child: const Text('تمام'),
                  ),
                ]),
              ],
            _Stage.addDb => [
                ClientDbPanel(onAdded: (d) {
                  setState(() {
                    _dbs = [..._dbs.where((x) => x.ref != d.ref), d];
                    _client = d;
                    _clientName = d.label;
                    _stage = _Stage.kind;
                  });
                }),
              ],
            _Stage.kind => [
                if (_client != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      const Icon(Icons.dns_rounded, color: AlphaColors.teal, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('قاعدة البيانات: ${_client!.label} (${_client!.ref})',
                            style: const TextStyle(color: AlphaColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ]),
                  ),
                _big(Icons.add_to_home_screen_rounded, 'تطبيق واحد', 'تطبيق واحد يدير كل شيء',
                    () => Navigator.pop(context, NewProjectChoice(kind: ProjectKind.single, client: _client, clientName: _clientName))),
                _big(Icons.connecting_airports_rounded, 'التطبيقين', 'تطبيق للزبائن + تطبيق للإدارة، متصلان بالإشعارات',
                    () => Navigator.pop(context, NewProjectChoice(kind: ProjectKind.pair, client: _client, clientName: _clientName)),
                    color: AlphaColors.pink),
              ],
          },
        ],
      ),
    );
  }
}

/// Add a client's database: a project in the client's own Supabase account (ref + access token, checked with Supabase),
/// or a new project Alpha creates in the owner's account. Also used in the settings.
class ClientDbPanel extends StatefulWidget {
  const ClientDbPanel({super.key, this.onAdded});
  final ValueChanged<ClientDb>? onAdded;

  @override
  State<ClientDbPanel> createState() => _ClientDbPanelState();
}

class _ClientDbPanelState extends State<ClientDbPanel> {
  bool _inClientAccount = true;
  final _label = TextEditingController();
  final _ref = TextEditingController();
  final _token = TextEditingController();
  String _region = AppState.supabaseRegions.keys.first;
  bool _busy = false;
  String _step = '';

  Future<void> _run(Future<ClientDb> Function() fn) async {
    setState(() {
      _busy = true;
      _step = '';
    });
    try {
      final d = await fn();
      if (!mounted) return;
      showMessage(context, 'أُضيفت «${d.label}» (${d.ref})');
      widget.onAdded?.call(d);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('حساب الزبون')),
            ButtonSegment(value: false, label: Text('جديد في حسابي')),
          ],
          selected: {_inClientAccount},
          onSelectionChanged: _busy ? null : (v) => setState(() => _inClientAccount = v.first),
        ),
        const SizedBox(height: 12),
        TextField(controller: _label, decoration: const InputDecoration(labelText: 'اسم يميّزه', hintText: 'مثلاً: محل الورد')),
        const SizedBox(height: 10),
        if (_inClientAccount) ...[
          const Text(
            'الزبون ينشئ حساباً في supabase.com ومشروعاً جديداً، ويعطيك: رمز المشروع (من رابط المشروع) ومفتاح وصول من '
            'Account ← Access Tokens. البيانات والفواتير تبقى في حسابه.',
            style: TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ref,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'رمز المشروع (Project Ref)', hintText: 'abcdefghijklmnopqrst'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            textDirection: TextDirection.ltr,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'مفتاح الوصول (sbp_…)'),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'تحقّق وأضف المشروع',
            icon: Icons.verified_rounded,
            busy: _busy,
            onPressed: _busy ? null : () => _run(() => s.addClientDb(_label.text, _ref.text, _token.text)),
          ),
        ] else ...[
          const Text(
            'Alpha ينشئ مشروع Supabase جديداً في حسابك (التوكن الذي في الإعدادات). الخطة المجانية تسمح بمشروعين نشطين وتوقف '
            'المشروع إن لم يُستخدم أسبوعاً؛ لزبائن حقيقيين الأفضل خطة مدفوعة أو حساب الزبون.',
            style: TextStyle(color: AlphaColors.muted, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in AppState.supabaseRegions.entries)
              ChoiceChip(label: Text(r.value), selected: _region == r.key, onSelected: _busy ? null : (_) => setState(() => _region = r.key)),
          ]),
          const SizedBox(height: 12),
          GradientButton(
            label: 'أنشئ المشروع',
            icon: Icons.add_circle_rounded,
            busy: _busy,
            onPressed: _busy
                ? null
                : () => _run(() => s.createClientDb(_label.text, _region, onStep: (st) => mounted ? setState(() => _step = st) : null)),
          ),
          if (_busy && _step.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_step, textAlign: TextAlign.center, style: const TextStyle(color: AlphaColors.teal))),
        ],
      ],
    );
  }
}
