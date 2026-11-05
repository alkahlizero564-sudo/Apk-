import 'dart:async';

import 'package:flutter/material.dart';

import '../backend.dart';
import '../config.dart';
import 'icons.dart';
import 'look.dart';
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

  /// The rows in the chosen list style: cards, compact, a 2-column gallery or a timeline.
  Widget _rowsSliver(BuildContext context) {
    final c = b.config;
    final rows = _visible;
    switch (c.listStyle) {
      case 'grid':
        return SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
          itemCount: rows.length,
          itemBuilder: (_, i) => _GridCard(config: c, table: t, row: rows[i], onTap: () => _open(rows[i])),
        );
      case 'compact':
        return SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: surface(context, c),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                _RowCard(config: c, table: t, row: rows[i], onTap: () => _open(rows[i]), compact: true),
              ],
            ]),
          ),
        );
      case 'reels':
        return SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => _Reel(config: c, table: t, row: rows[i], onTap: () => _open(rows[i])),
        );
      case 'timeline':
        return SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => _Timeline(config: c, first: i == 0, last: i == rows.length - 1, row: rows[i],
              child: _RowCard(config: c, table: t, row: rows[i], onTap: () => _open(rows[i]))),
        );
      default:
        return SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => _RowCard(config: c, table: t, row: rows[i], onTap: () => _open(rows[i])),
        );
    }
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: _rowsSliver(context),
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.config, required this.table, required this.row, required this.size, this.square = false, this.circle = false});
  final AlphaConfig config;
  final TableCfg table;
  final Rec row;
  final double size;
  final bool square;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final cs = Theme.of(context).colorScheme;
    final image = table.imageColumn;
    final url = image == null ? '' : '${row[image.name] ?? ''}';
    final brutal = c.style == 'brutal';
    final icon = Icon(iconFor(table.icon), color: brutal ? ink : cs.primary, size: square ? 40 : 24);
    return Container(
      width: square ? double.infinity : size,
      height: square ? null : size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: brutal ? c.accent : null,
        gradient: brutal ? null : LinearGradient(colors: [c.seed.withValues(alpha: 0.2), c.accent.withValues(alpha: square ? 0.22 : 0.08)]),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle || square ? null : BorderRadius.circular(brutal ? 8 : c.radius * 0.75),
        border: brutal && !square ? Border.all(color: ink, width: 2) : null,
      ),
      child: url.startsWith('http') ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => icon) : icon,
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.config, required this.table, required this.row, required this.onTap, this.compact = false});
  final AlphaConfig config;
  final TableCfg table;
  final Rec row;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final cs = Theme.of(context).colorScheme;
    final title = table.titleColumn;
    final image = table.imageColumn;
    final badge = table.badgeColumn;
    final price = table.priceColumn;
    final details = table.columns
        .where((x) => x.show && x != title && x != image && x != badge && x != price && row[x.name] != null && '${row[x.name]}'.isNotEmpty)
        .take(3)
        .map((x) => '${x.label}: ${formatValue(x, row[x.name])}')
        .join('  •  ');
    final content = Row(
      children: [
        _Thumb(config: c, table: table, row: row, size: compact ? 44 : 60, circle: compact),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.listStyle == 'timeline' && row['created_at'] != null)
                Text(timeAgo(DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now()), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              Text(title == null ? table.label : formatValue(title, row[title.name]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: c.lightTitles ? FontWeight.w500 : FontWeight.w800, fontSize: 16)),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(details, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                if (badge != null && row[badge.name] != null) StatusPill('${row[badge.name]}'),
                const Spacer(),
                if (price != null && row[price.name] != null)
                  Text(formatValue(price, row[price.name]), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ],
          ),
        ),
      ],
    );
    if (compact) {
      return InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: content));
    }
    return Surface(config: c, onTap: onTap, padding: const EdgeInsets.all(13), child: content);
  }
}

/// Gallery card: the picture (or a gradient with the icon) first, then the name, badge and price.
class _GridCard extends StatelessWidget {
  const _GridCard({required this.config, required this.table, required this.row, required this.onTap});
  final AlphaConfig config;
  final TableCfg table;
  final Rec row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final cs = Theme.of(context).colorScheme;
    final title = table.titleColumn;
    final badge = table.badgeColumn;
    final price = table.priceColumn;
    return Surface(
      config: c,
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(c.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Thumb(config: c, table: table, row: row, size: 0, square: true)),
            if (c.style == 'brutal') Container(height: 2.5, color: ink),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title == null ? table.label : formatValue(title, row[title.name]),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: c.lightTitles ? FontWeight.w500 : FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (badge != null && row[badge.name] != null) Flexible(child: StatusPill('${row[badge.name]}')),
                    const Spacer(),
                    if (price != null && row[price.name] != null)
                      Text(formatValue(price, row[price.name]), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row on the timeline: a gradient line with a glowing dot, the card beside it.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.config, required this.first, required this.last, required this.row, required this.child});
  final AlphaConfig config;
  final bool first;
  final bool last;
  final Rec row;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = config;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: first ? 26 : 0,
                bottom: last ? null : 0,
                height: last ? 26 : null,
                child: Container(width: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.seed, c.accent], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              ),
              Positioned(
                top: 20,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.seed, width: 3),
                    boxShadow: [BoxShadow(color: c.seed.withValues(alpha: 0.6), blurRadius: 10)],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
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

/// Reels: one tall picture-first card per row, the text on a dark fade at the bottom.
class _Reel extends StatelessWidget {
  const _Reel({required this.config, required this.table, required this.row, required this.onTap});
  final AlphaConfig config;
  final TableCfg table;
  final Rec row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = config;
    final title = table.titleColumn;
    final badge = table.badgeColumn;
    final price = table.priceColumn;
    final image = table.imageColumn;
    final url = image == null ? '' : '${row[image.name] ?? ''}';
    final h = MediaQuery.sizeOf(context).height * 0.66;
    final hue = '${row['id']}'.hashCode % 3;
    final colors = [c.seed, c.accent, Color.lerp(c.seed, c.accent, 0.5)!];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(c.radius + 6),
          child: SizedBox(
            height: h,
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors[hue], colors[(hue + 1) % 3]])),
                child: Center(child: Icon(iconFor(table.icon), size: 90, color: Colors.white.withValues(alpha: 0.9))),
              ),
              if (url.startsWith('http')) Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.45, 1]))),
              PositionedDirectional(
                start: 18,
                end: 70,
                bottom: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title == null ? table.label : formatValue(title, row[title.name]),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (badge != null && row[badge.name] != null) Flexible(child: StatusPill('${row[badge.name]}')),
                    const SizedBox(width: 10),
                    if (price != null && row[price.name] != null)
                      Text(formatValue(price, row[price.name]), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ]),
                ]),
              ),
              PositionedDirectional(
                end: 14,
                bottom: 22,
                child: Column(children: [
                  for (final ic in const [Icons.favorite_border_rounded, Icons.share_rounded])
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
                      child: Icon(ic, color: Colors.white),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
