import 'dart:async';

import 'package:flutter/material.dart';

import '../backend.dart';
import '../config.dart';
import 'icons.dart';
import 'row_form.dart';
import 'widgets.dart';

class TablePage extends StatefulWidget {
  const TablePage({super.key, required this.backend, required this.table, this.embedded = true});
  final Backend backend;
  final TableCfg table;
  final bool embedded;

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  List<Rec>? _rows;
  String? _error;
  String _query = '';
  String? _filter;
  Timer? _timer;

  TableCfg get t => widget.table;
  Backend get b => widget.backend;

  @override
  void initState() {
    super.initState();
    _load();
    // Changes from the other app show up without pulling (cheap polling; push wakes the user).
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final rows = await b.list(t);
      if (mounted) setState(() => (_rows = rows, _error = null));
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = '$e');
    }
  }

  List<Rec> get _visible {
    final rows = _rows ?? const [];
    final q = _query.trim().toLowerCase();
    final badge = t.badgeColumn;
    return rows.where((r) {
      if (_filter != null && badge != null && r[badge.name] != _filter) return false;
      if (q.isEmpty) return true;
      return t.columns.any((c) => '${r[c.name] ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _add() async {
    if (await openRowForm(context, b, t)) {
      await _load();
      if (mounted) toast(context, 'تمت الإضافة ✓');
    }
  }

  Future<void> _open(Rec row) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RowDetails(backend: b, table: t, row: row),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badge = t.badgeColumn;
    final body = RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'بحث في ${t.label}'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          if (badge != null && badge.options.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: const Text('الكل'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                    ),
                    for (final o in badge.options)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(label: Text(o), selected: _filter == o, onSelected: (_) => setState(() => _filter = o)),
                      ),
                  ],
                ),
              ),
            ),
          if (_error != null && _rows == null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorBox(message: _error!, onRetry: _load))
          else if (_rows == null)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: iconFor(t.icon),
                text: _rows!.isEmpty ? 'لا يوجد شيء في ${t.label} بعد' : 'لا نتائج',
                action: _rows!.isEmpty && t.canAdd(b.isAdmin)
                    ? FilledButton.tonalIcon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('أضف أول عنصر'))
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList.builder(
                itemCount: _visible.length,
                itemBuilder: (_, i) => _RowCard(table: t, row: _visible[i], onTap: () => _open(_visible[i])),
              ),
            ),
        ],
      ),
    );
    final fab = t.canAdd(b.isAdmin)
        ? FloatingActionButton.extended(
            heroTag: 'add-${t.name}',
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: Text('إضافة'),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          )
        : null;
    if (widget.embedded) {
      return Scaffold(backgroundColor: Colors.transparent, body: body, floatingActionButton: fab);
    }
    return Scaffold(appBar: AppBar(title: Text(t.label)), body: body, floatingActionButton: fab);
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.table, required this.row, required this.onTap});
  final TableCfg table;
  final Rec row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = table.titleColumn;
    final image = table.imageColumn;
    final badge = table.badgeColumn;
    final price = table.priceColumn;
    final url = image == null ? '' : '${row[image.name] ?? ''}';
    final details = table.columns
        .where((c) => c.show && c != title && c != image && c != badge && c != price && row[c.name] != null && '${row[c.name]}'.isNotEmpty)
        .take(3)
        .map((c) => '${c.label}: ${formatValue(c, row[c.name])}')
        .join('  •  ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 58,
                  height: 58,
                  color: cs.primary.withValues(alpha: 0.12),
                  child: url.startsWith('http')
                      ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(iconFor(table.icon), color: cs.primary))
                      : Icon(iconFor(table.icon), color: cs.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title == null ? table.label : formatValue(title, row[title.name]),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (badge != null && row[badge.name] != null) StatusPill('${row[badge.name]}'),
                        const Spacer(),
                        if (price != null && row[price.name] != null)
                          Text(formatValue(price, row[price.name]),
                              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDetails extends StatefulWidget {
  const _RowDetails({required this.backend, required this.table, required this.row});
  final Backend backend;
  final TableCfg table;
  final Rec row;

  @override
  State<_RowDetails> createState() => _RowDetailsState();
}

class _RowDetailsState extends State<_RowDetails> {
  bool _busy = false;

  Future<void> _setChoice(ColumnCfg c, String v) async {
    setState(() => _busy = true);
    try {
      await widget.backend.update(widget.table, '${widget.row['id']}', {c.name: v});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف؟'),
        content: const Text('لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.backend.delete(widget.table, '${widget.row['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.table;
    final row = widget.row;
    final b = widget.backend;
    final cs = Theme.of(context).colorScheme;
    final canEdit = t.canEdit(b.isAdmin, b.isMine(row));
    final image = t.imageColumn;
    final url = image == null ? '' : '${row[image.name] ?? ''}';
    final quick = b.isAdmin ? t.columns.where((c) => c.type == 'choice' && c.adminOnly).toList() : <ColumnCfg>[];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        if (url.startsWith('http'))
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(url, height: 190, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        const SizedBox(height: 12),
        for (final c in t.columns)
          if (row[c.name] != null && '${row[c.name]}'.isNotEmpty && c.type != 'image')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(c.label, style: TextStyle(color: cs.onSurfaceVariant))),
                  Expanded(child: SelectableText(formatValue(c, row[c.name]), style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        if (row['created_at'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('أُضيف ${timeAgo(DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now())}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
        for (final c in quick) ...[
          const SizedBox(height: 16),
          Text('تغيير ${c.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in c.options)
                ChoiceChip(label: Text(o), selected: row[c.name] == o, onSelected: _busy ? null : (_) => _setChoice(c, o)),
            ],
          ),
        ],
        if (canEdit) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          if (await openRowForm(context, b, t, row: row)) nav.pop(true);
                        },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
