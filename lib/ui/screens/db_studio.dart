import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/state.dart';
import '../../app/theme.dart';
import '../../generator/firestore_rules.dart';
import '../../generator/presets.dart';
import '../../generator/sql_generator.dart';
import '../../models/project.dart';
import '../../models/schema.dart';
import '../widgets.dart';

/// Tables, columns, ownership (row level security), notifications, and the SQL / rules Alpha writes from them.
class DbStudioScreen extends StatefulWidget {
  const DbStudioScreen({super.key, required this.project});
  final Project project;

  @override
  State<DbStudioScreen> createState() => _DbStudioScreenState();
}

class _DbStudioScreenState extends State<DbStudioScreen> {
  late final DbSchema _schema = widget.project.schema.copy();
  bool _busy = false;
  bool _dirty = false;

  Project get p => widget.project;

  String get _code => p.backend == BackendType.firebase
      ? FirestoreRulesGenerator(p.prefix, _schema).build()
      : SqlGenerator(p.prefix, _schema, admins: p.admins).build();

  void _changed() => setState(() => _dirty = true);

  Future<void> _save({bool apply = false}) async {
    final s = context.read<AppState>();
    final errors = _schema.validate();
    if (errors.isNotEmpty) {
      showMessage(context, errors.join('\n'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      p.schema = _schema.copy();
      await s.save(p, message: 'Alpha: database of ${p.title}');
      var msg = 'حُفظت قاعدة البيانات';
      if (apply) {
        if (p.backend == BackendType.supabase && s.hasSupabase && (s.supabaseRef.isNotEmpty || p.supabaseRef.isNotEmpty)) {
          final tables = await s.applySqlNow(p);
          msg = 'طُبّقت على Supabase الآن: $tables';
        } else if (p.backend != BackendType.none) {
          await s.setupServer(p);
          msg = 'بدأ تجهيز السيرفر ثم البناء في GitHub Actions';
        } else if (s.hasGitHub) {
          await s.buildAll(p);
          msg = 'حُفظت وبدأ البناء';
        }
      }
      setState(() => _dirty = false);
      if (mounted) showMessage(context, msg);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTable([DbTable? table]) async {
    final result = await Navigator.push<DbTable>(
      context,
      MaterialPageRoute(builder: (_) => TableEditor(table: table?.copy(), others: _schema.tables.where((t) => t != table).map((t) => t.name).toSet())),
    );
    if (result == null) return;
    setState(() {
      if (table == null) {
        _schema.tables.add(result);
      } else {
        _schema.tables[_schema.tables.indexOf(table)] = result;
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final errors = _schema.validate();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استوديو البيانات'),
          bottom: const TabBar(tabs: [Tab(text: 'الجداول'), Tab(text: 'الكود المولّد')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editTable(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('جدول'),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: p.backend == BackendType.supabase ? 'احفظ وطبّق على Supabase' : (p.backend == BackendType.firebase ? 'احفظ وانشر القواعد' : 'احفظ وابنِ'),
                    icon: Icons.cloud_upload_rounded,
                    busy: _busy,
                    onPressed: () => _save(apply: true),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _busy || !_dirty ? null : () => _save(),
                  icon: const Icon(Icons.save_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
                ),
              ],
            ),
          ),
        ),
        body: AuroraBackground(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (errors.isNotEmpty)
                    GlassCard(
                      gradient: LinearGradient(colors: [AlphaColors.bad.withValues(alpha: 0.25), AlphaColors.bad.withValues(alpha: 0.08)]),
                      child: Text(errors.join('\n'), style: const TextStyle(height: 1.6)),
                    ),
                  GlassCard(
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: AlphaColors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'كل جدول يُنشأ باسم ${p.prefix}_<الاسم> مع صلاحيات RLS حسب نوعه، وعمود customer_id لصاحب الصف، وتنبيهات تلقائية بين التطبيقين.',
                            style: const TextStyle(color: AlphaColors.muted, fontSize: 13, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_schema.tables.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('لا جداول بعد. اضغط «جدول» للإضافة.', textAlign: TextAlign.center, style: TextStyle(color: AlphaColors.muted)),
                    ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (a, b) {
                      setState(() {
                        _schema.tables.insert(b, _schema.tables.removeAt(a));
                        _dirty = true;
                      });
                    },
                    children: [
                      for (var i = 0; i < _schema.tables.length; i++)
                        _TableCard(
                          key: ValueKey(_schema.tables[i].name),
                          index: i,
                          table: _schema.tables[i],
                          onTap: () => _editTable(_schema.tables[i]),
                          onDelete: () async {
                            if (await confirm(context, 'حذف الجدول؟', 'يُحذف من التصميم. بياناته في السيرفر تبقى حتى تحذفها هناك.', ok: 'حذف')) {
                              setState(() => _schema.tables.removeAt(i));
                              _changed();
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
              _CodeView(code: _code, label: p.backend == BackendType.firebase ? 'firestore.rules' : 'schema.sql'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({super.key, required this.index, required this.table, required this.onTap, required this.onDelete});
  final int index;
  final DbTable table;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator_rounded, color: AlphaColors.muted)),
                const SizedBox(width: 6),
                Icon(tableIcon(table.icon), color: AlphaColors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(table.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(table.name, style: const TextStyle(color: AlphaColors.muted, fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Pill(table.owner.label, color: AlphaColors.blue),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: AlphaColors.bad)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in table.columns)
                  Pill('${c.label} · ${c.type.label}', color: c.adminOnly ? AlphaColors.amber : (c.required ? AlphaColors.violet : AlphaColors.muted)),
              ],
            ),
          ],
        ),
      );
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              const Spacer(),
              Text('${code.split('\n').length} سطر', style: const TextStyle(color: AlphaColors.muted)),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showMessage(context, 'نُسخ الكود');
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF0A0C14), borderRadius: BorderRadius.circular(16), border: Border.all(color: AlphaColors.line)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.5, color: Color(0xFFB8C1EC))),
            ),
          ),
        ],
      );
}

/// One table: name, owner (row level security), notifications and its columns.
class TableEditor extends StatefulWidget {
  const TableEditor({super.key, this.table, required this.others});
  final DbTable? table;
  final Set<String> others;

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  late final DbTable t = widget.table ?? DbTable(name: '', label: '', columns: [DbColumn(name: 'title', label: 'الاسم', required: true)]);
  late final _name = TextEditingController(text: t.name);
  late final _label = TextEditingController(text: t.label);

  void _done() {
    t.name = slugIdent(_name.text.isEmpty ? _label.text : _name.text, fallback: 'table');
    t.label = _label.text.trim().isEmpty ? t.name : _label.text.trim();
    if (widget.others.contains(t.name)) {
      showMessage(context, 'يوجد جدول بنفس الاسم', error: true);
      return;
    }
    if (t.columns.isEmpty) {
      showMessage(context, 'أضف عموداً واحداً على الأقل', error: true);
      return;
    }
    final errors = DbSchema(tables: [t]).validate();
    if (errors.isNotEmpty) {
      showMessage(context, errors.first, error: true);
      return;
    }
    Navigator.pop(context, t);
  }

  Future<void> _editColumn([DbColumn? col]) async {
    final result = await showModalBottomSheet<DbColumn>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ColumnSheet(column: col?.copy(), taken: t.columns.where((c) => c != col).map((c) => c.name).toSet()),
    );
    if (result == null) return;
    setState(() {
      if (col == null) {
        t.columns.add(result);
      } else {
        t.columns[t.columns.indexOf(col)] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.table == null ? 'جدول جديد' : 'تعديل ${t.label}'),
        actions: [TextButton(onPressed: _done, child: const Text('تم', style: TextStyle(fontWeight: FontWeight.w800)))],
      ),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'الاسم الظاهر (عربي)', prefixIcon: Icon(Icons.label_rounded))),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الاسم في قاعدة البيانات (english_snake)', prefixIcon: Icon(Icons.data_object_rounded)),
            ),
            const SectionTitle('الأيقونة'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in tableIcons)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => t.icon = i),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: t.icon == i ? AlphaColors.violet.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tableIcon(i), size: 22),
                    ),
                  ),
              ],
            ),
            const SectionTitle('من يملك الصفوف؟', subtitle: 'يحدد صلاحيات RLS تلقائياً'),
            RadioGroup<TableOwner>(
              groupValue: t.owner,
              onChanged: (v) => setState(() {
                t.owner = v!;
                if (!t.hasOwnerColumn && t.notifyOnUpdate == NotifyTarget.owner) t.notifyOnUpdate = NotifyTarget.none;
              }),
              child: Column(
                children: [
                  for (final o in TableOwner.values)
                    RadioListTile<TableOwner>(
                      contentPadding: EdgeInsets.zero,
                      value: o,
                      title: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(o.hint, style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SectionTitle('الإشعارات التلقائية'),
            _dropdown<NotifyTarget>('عند إضافة صف، أشعِر', t.notifyOnInsert,
                NotifyTarget.values.where((n) => n != NotifyTarget.owner).toList(), (v) => setState(() => t.notifyOnInsert = v), (n) => n.label),
            const SizedBox(height: 10),
            _dropdown<NotifyTarget>('عند تعديل صف، أشعِر', t.notifyOnUpdate,
                NotifyTarget.values.where((n) => n != NotifyTarget.owner || t.hasOwnerColumn).toList(), (v) => setState(() => t.notifyOnUpdate = v), (n) => n.label),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: t.realtime,
              onChanged: (v) => setState(() => t.realtime = v),
              title: const Text('تحديث مباشر (Realtime)'),
            ),
            SectionTitle('الأعمدة',
                subtitle: 'id و created_at و updated_at تضاف تلقائياً',
                trailing: TextButton.icon(onPressed: () => _editColumn(), icon: const Icon(Icons.add_rounded), label: const Text('عمود'))),
            for (final c in t.columns)
              GlassCard(
                onTap: () => _editColumn(c),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${c.name} · ${c.type.label}${c.required ? ' · مطلوب' : ''}${c.adminOnly ? ' · للإدارة فقط' : ''}',
                              style: const TextStyle(color: AlphaColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => t.columns.remove(c)),
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AlphaColors.bad),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T> onChanged, String Function(T) name) => DropdownButtonFormField<T>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(name(i)))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

class _ColumnSheet extends StatefulWidget {
  const _ColumnSheet({this.column, required this.taken});
  final DbColumn? column;
  final Set<String> taken;

  @override
  State<_ColumnSheet> createState() => _ColumnSheetState();
}

class _ColumnSheetState extends State<_ColumnSheet> {
  late final DbColumn c = widget.column ?? DbColumn(name: '', label: '');
  late final _name = TextEditingController(text: c.name);
  late final _label = TextEditingController(text: c.label);
  late final _options = TextEditingController(text: c.options.join('، '));
  late final _default = TextEditingController(text: c.defaultValue ?? '');

  void _done() {
    c.name = slugIdent(_name.text.isEmpty ? _label.text : _name.text, fallback: 'col');
    c.label = _label.text.trim().isEmpty ? c.name : _label.text.trim();
    c.options = _options.text.split(RegExp(r'[,،\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    c.defaultValue = _default.text.trim().isEmpty ? null : _default.text.trim();
    if (reservedColumns.contains(c.name)) {
      showMessage(context, '«${c.name}» اسم محجوز', error: true);
      return;
    }
    if (widget.taken.contains(c.name)) {
      showMessage(context, 'يوجد عمود بنفس الاسم', error: true);
      return;
    }
    if (c.type == ColumnType.choice && c.options.isEmpty) {
      showMessage(context, 'اكتب الخيارات مفصولة بفاصلة', error: true);
      return;
    }
    Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            Text(widget.column == null ? 'عمود جديد' : 'تعديل العمود', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'الاسم الظاهر (عربي)')),
            const SizedBox(height: 10),
            TextField(controller: _name, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الاسم في قاعدة البيانات')),
            const SizedBox(height: 10),
            DropdownButtonFormField<ColumnType>(
              initialValue: c.type,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: [for (final t in ColumnType.values) DropdownMenuItem(value: t, child: Text('${t.label}  (${t.sql})'))],
              onChanged: (v) => setState(() => c.type = v!),
            ),
            if (c.type == ColumnType.choice) ...[
              const SizedBox(height: 10),
              TextField(controller: _options, decoration: const InputDecoration(labelText: 'الخيارات (افصل بفاصلة)', hintText: 'جديد، قيد التجهيز، تم')),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _default,
              decoration: InputDecoration(
                labelText: 'القيمة الافتراضية (اختياري)',
                helperText: switch (c.type) {
                  ColumnType.date => 'today = تاريخ اليوم',
                  ColumnType.datetime => 'now = الآن',
                  ColumnType.boolean => 'true أو false',
                  _ => null,
                },
              ),
            ),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: c.required, onChanged: (v) => setState(() => c.required = v), title: const Text('مطلوب')),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: c.unique, onChanged: (v) => setState(() => c.unique = v), title: const Text('بدون تكرار (unique)')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: c.adminOnly,
              onChanged: (v) => setState(() => c.adminOnly = v),
              title: const Text('الإدارة فقط تغيّره'),
              subtitle: const Text('مثل حالة الطلب: العميل يراه ولا يعدّله', style: TextStyle(color: AlphaColors.muted, fontSize: 12)),
            ),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: c.showInList, onChanged: (v) => setState(() => c.showInList = v), title: const Text('يظهر في القائمة')),
            const SizedBox(height: 8),
            GradientButton(label: 'تم', icon: Icons.check_rounded, onPressed: _done),
          ],
        ),
      );
}
