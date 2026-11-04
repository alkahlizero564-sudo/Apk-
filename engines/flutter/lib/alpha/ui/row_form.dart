import 'package:flutter/material.dart';

import '../backend.dart';
import '../config.dart';
import 'widgets.dart';

/// Add or edit a row: one field per column, made from the column type.
Future<bool> openRowForm(BuildContext context, Backend backend, TableCfg table, {Rec? row}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RowForm(backend: backend, table: table, row: row),
  );
  return saved == true;
}

class RowForm extends StatefulWidget {
  const RowForm({super.key, required this.backend, required this.table, this.row});
  final Backend backend;
  final TableCfg table;
  final Rec? row;

  @override
  State<RowForm> createState() => _RowFormState();
}

class _RowFormState extends State<RowForm> {
  final _form = GlobalKey<FormState>();
  final _values = <String, dynamic>{};
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  bool get _editing => widget.row != null;

  List<ColumnCfg> get _columns =>
      widget.table.columns.where((c) => !c.adminOnly || widget.backend.isAdmin).toList();

  @override
  void initState() {
    super.initState();
    for (final c in _columns) {
      final current = widget.row?[c.name];
      final initial = current ?? (_editing ? null : _default(c));
      _values[c.name] = initial;
      if (_isText(c)) _controllers[c.name] = TextEditingController(text: initial?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  dynamic _default(ColumnCfg c) {
    final d = c.defaultValue;
    if (d == null || d.isEmpty) return c.type == 'bool' ? false : null;
    return switch (c.type) {
      'bool' => d == 'true',
      'date' => d == 'today' || d == 'now' ? DateTime.now().toIso8601String().substring(0, 10) : d,
      'datetime' => d == 'now' ? DateTime.now().toIso8601String() : d,
      _ => d,
    };
  }

  bool _isText(ColumnCfg c) => !['bool', 'choice', 'date', 'datetime'].contains(c.type);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    for (final e in _controllers.entries) {
      _values[e.key] = e.value.text;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.backend.update(widget.table, '${widget.row!['id']}', _values);
      } else {
        await widget.backend.insert(widget.table, _values);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(ColumnCfg c) async {
    final now = DateTime.now();
    final current = DateTime.tryParse('${_values[c.name] ?? ''}')?.toLocal() ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 10),
    );
    if (day == null || !mounted) return;
    if (c.type == 'date') {
      setState(() => _values[c.name] = day.toIso8601String().substring(0, 10));
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    final at = DateTime(day.year, day.month, day.day, time?.hour ?? 9, time?.minute ?? 0);
    setState(() => _values[c.name] = at.toUtc().toIso8601String());
  }

  Widget _field(ColumnCfg c) {
    final label = '${c.label}${c.required ? ' *' : ''}';
    switch (c.type) {
      case 'bool':
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(c.label),
          value: _values[c.name] == true || _values[c.name] == 'true',
          onChanged: (v) => setState(() => _values[c.name] = v),
        );
      case 'choice':
        final value = c.options.contains(_values[c.name]) ? _values[c.name] as String : null;
        return DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: c.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _values[c.name] = v),
          validator: (v) => c.required && (v == null || v.isEmpty) ? 'مطلوب' : null,
        );
      case 'date':
      case 'datetime':
        final v = _values[c.name];
        return FormField<String>(
          validator: (_) => c.required && (v == null || '$v'.isEmpty) ? 'مطلوب' : null,
          builder: (state) => InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pickDate(c),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_month_rounded),
              ),
              child: Text(v == null ? 'اختر' : formatValue(c, v)),
            ),
          ),
        );
      default:
        final multi = c.type == 'longtext';
        return TextFormField(
          controller: _controllers[c.name],
          minLines: multi ? 3 : 1,
          maxLines: multi ? 6 : 1,
          keyboardType: switch (c.type) {
            'int' => TextInputType.number,
            'decimal' => const TextInputType.numberWithOptions(decimal: true),
            'phone' => TextInputType.phone,
            'email' => TextInputType.emailAddress,
            'image' => TextInputType.url,
            _ => multi ? TextInputType.multiline : TextInputType.text,
          },
          textDirection: ['phone', 'email', 'image', 'int', 'decimal'].contains(c.type) ? TextDirection.ltr : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: c.type == 'image' ? 'https://…' : null,
            prefixIcon: switch (c.type) {
              'phone' => const Icon(Icons.phone_rounded),
              'email' => const Icon(Icons.alternate_email_rounded),
              'image' => const Icon(Icons.image_rounded),
              'decimal' => const Icon(Icons.payments_rounded),
              _ => null,
            },
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return c.required ? 'مطلوب' : null;
            if (c.type == 'int' && int.tryParse(s.replaceAll(',', '')) == null) return 'رقم صحيح فقط';
            if (c.type == 'decimal' && double.tryParse(s.replaceAll(',', '')) == null) return 'رقم فقط';
            if (c.type == 'email' && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'بريد غير صحيح';
            if (c.type == 'phone' && !RegExp(r'^[+0-9 ()-]{6,20}$').hasMatch(s)) return 'رقم غير صحيح';
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(_editing ? 'تعديل ${widget.table.label}' : 'إضافة إلى ${widget.table.label}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            for (final c in _columns) ...[_field(c), const SizedBox(height: 12)],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_editing ? 'حفظ التعديل' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}
