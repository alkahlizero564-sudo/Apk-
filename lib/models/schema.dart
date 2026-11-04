// The data model of an app: tables and columns designed in Alpha's database studio.
// The same JSON goes into every generated app (alpha config) and drives the SQL / Firestore rules.

enum ColumnType {
  text('text', 'نص قصير', 'text'),
  longtext('longtext', 'نص طويل', 'text'),
  integer('int', 'رقم صحيح', 'bigint'),
  decimal('decimal', 'رقم عشري / سعر', 'numeric(12,2)'),
  boolean('bool', 'نعم / لا', 'boolean'),
  date('date', 'تاريخ', 'date'),
  datetime('datetime', 'تاريخ ووقت', 'timestamptz'),
  image('image', 'رابط صورة', 'text'),
  phone('phone', 'رقم هاتف', 'text'),
  email('email', 'بريد إلكتروني', 'text'),
  choice('choice', 'اختيار من قائمة', 'text');

  const ColumnType(this.id, this.label, this.sql);
  final String id;
  final String label;
  final String sql;

  static ColumnType parse(String? v) =>
      ColumnType.values.firstWhere((t) => t.id == v, orElse: () => ColumnType.text);
}

/// Who owns the rows of a table, which decides the row level security.
enum TableOwner {
  catalog('catalog', 'كتالوج', 'الكل يقرأ، الإدارة فقط تضيف وتعدّل (منتجات، خدمات، قائمة طعام)'),
  customer('customer', 'خاص بالعميل', 'كل عميل يرى ويعدّل صفوفه فقط، والإدارة ترى الكل (طلبات، حجوزات)'),
  shared('public', 'مشترك', 'الكل يقرأ ويضيف، وكل واحد يعدّل صفوفه فقط (تقييمات، رسائل)'),
  admin('admin', 'إدارة فقط', 'لا يظهر إلا في تطبيق الإدارة (مصروفات، موظفين)');

  const TableOwner(this.id, this.label, this.hint);
  final String id;
  final String label;
  final String hint;

  static TableOwner parse(String? v) =>
      TableOwner.values.firstWhere((t) => t.id == v, orElse: () => TableOwner.customer);
}

/// Who gets a notification when something happens in a table.
enum NotifyTarget {
  none('none', 'لا أحد'),
  admin('admin', 'الإدارة'),
  customers('customer', 'كل العملاء'),
  owner('owner', 'صاحب الصف');

  const NotifyTarget(this.id, this.label);
  final String id;
  final String label;

  static NotifyTarget parse(String? v) =>
      NotifyTarget.values.firstWhere((t) => t.id == v, orElse: () => NotifyTarget.none);
}

final _ident = RegExp(r'^[a-z][a-z0-9_]{0,40}$');

/// Turns any name (Arabic or English) into a safe SQL identifier.
String slugIdent(String input, {String fallback = 'item'}) {
  var s = input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = '${fallback}_$s'.replaceAll(RegExp(r'_$'), '');
  if (s.length > 40) s = s.substring(0, 40);
  return s;
}

bool isIdent(String s) => _ident.hasMatch(s);

const reservedColumns = {'id', 'created_at', 'updated_at', 'customer_id'};

class DbColumn {
  DbColumn({
    required this.name,
    required this.label,
    this.type = ColumnType.text,
    this.required = false,
    this.unique = false,
    this.options = const [],
    this.defaultValue,
    this.showInList = true,
    this.adminOnly = false,
  });

  String name;
  String label;
  ColumnType type;
  bool required;
  bool unique;
  List<String> options;
  String? defaultValue;
  bool showInList;

  /// Customers can read it but only the admin sets it (e.g. order status).
  bool adminOnly;

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type.id,
        if (required) 'required': true,
        if (unique) 'unique': true,
        if (options.isNotEmpty) 'options': options,
        if (defaultValue != null && defaultValue!.isNotEmpty) 'default': defaultValue,
        'show': showInList,
        if (adminOnly) 'adminOnly': true,
      };

  factory DbColumn.fromJson(Map<String, dynamic> j) => DbColumn(
        name: slugIdent('${j['name'] ?? ''}', fallback: 'col'),
        label: '${j['label'] ?? j['name'] ?? ''}',
        type: ColumnType.parse(j['type'] as String?),
        required: j['required'] == true,
        unique: j['unique'] == true,
        options: ((j['options'] as List?) ?? const []).map((e) => '$e').toList(),
        defaultValue: j['default']?.toString(),
        showInList: j['show'] != false,
        adminOnly: j['adminOnly'] == true,
      );

  DbColumn copy() => DbColumn.fromJson(toJson());
}

class DbTable {
  DbTable({
    required this.name,
    required this.label,
    this.icon = 'list',
    this.owner = TableOwner.customer,
    List<DbColumn>? columns,
    this.notifyOnInsert = NotifyTarget.none,
    this.notifyOnUpdate = NotifyTarget.none,
    this.realtime = true,
  }) : columns = columns ?? [];

  String name;
  String label;
  String icon;
  TableOwner owner;
  List<DbColumn> columns;
  NotifyTarget notifyOnInsert;
  NotifyTarget notifyOnUpdate;
  bool realtime;

  /// The column shown as the title of a row (first text-like column).
  DbColumn? get titleColumn {
    for (final c in columns) {
      if (c.type == ColumnType.text || c.type == ColumnType.choice) return c;
    }
    return columns.isEmpty ? null : columns.first;
  }

  bool get hasOwnerColumn => owner == TableOwner.customer || owner == TableOwner.shared;

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'icon': icon,
        'owner': owner.id,
        'columns': columns.map((c) => c.toJson()).toList(),
        'notify': {'onInsert': notifyOnInsert.id, 'onUpdate': notifyOnUpdate.id},
        'realtime': realtime,
      };

  factory DbTable.fromJson(Map<String, dynamic> j) {
    final notify = (j['notify'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cols = <DbColumn>[];
    final seen = <String>{};
    for (final c in (j['columns'] as List? ?? const [])) {
      final col = DbColumn.fromJson((c as Map).cast<String, dynamic>());
      if (reservedColumns.contains(col.name) || !seen.add(col.name)) continue;
      cols.add(col);
    }
    return DbTable(
      name: slugIdent('${j['name'] ?? ''}', fallback: 'table'),
      label: '${j['label'] ?? j['name'] ?? ''}',
      icon: '${j['icon'] ?? 'list'}',
      owner: TableOwner.parse(j['owner'] as String?),
      columns: cols,
      notifyOnInsert: NotifyTarget.parse(notify['onInsert'] as String?),
      notifyOnUpdate: NotifyTarget.parse(notify['onUpdate'] as String?),
      realtime: j['realtime'] != false,
    );
  }

  DbTable copy() => DbTable.fromJson(toJson());
}

class DbSchema {
  DbSchema({List<DbTable>? tables}) : tables = tables ?? [];
  List<DbTable> tables;

  List<Map<String, dynamic>> toJson() => tables.map((t) => t.toJson()).toList();

  factory DbSchema.fromJson(List<dynamic>? j) {
    final seen = <String>{};
    final out = <DbTable>[];
    for (final t in j ?? const []) {
      final table = DbTable.fromJson((t as Map).cast<String, dynamic>());
      if (seen.add(table.name)) out.add(table);
    }
    return DbSchema(tables: out);
  }

  DbSchema copy() => DbSchema.fromJson(toJson());

  /// Problems that would break the SQL or the apps; empty when the schema is good.
  List<String> validate() {
    final errors = <String>[];
    final names = <String>{};
    for (final t in tables) {
      if (!isIdent(t.name)) errors.add('اسم الجدول «${t.name}» لازم يكون بالإنجليزي الصغير (a-z و _).');
      if (!names.add(t.name)) errors.add('الجدول «${t.name}» مكرر.');
      if (t.columns.isEmpty) errors.add('الجدول «${t.label}» ما فيه أعمدة.');
      final cols = <String>{};
      for (final c in t.columns) {
        if (!isIdent(c.name)) errors.add('العمود «${c.name}» في «${t.label}» لازم يكون بالإنجليزي الصغير.');
        if (reservedColumns.contains(c.name)) errors.add('«${c.name}» اسم محجوز في «${t.label}».');
        if (!cols.add(c.name)) errors.add('العمود «${c.name}» مكرر في «${t.label}».');
        if (c.type == ColumnType.choice && c.options.isEmpty) {
          errors.add('العمود «${c.label}» نوعه اختيار لكن ما فيه خيارات.');
        }
      }
      if (t.owner == TableOwner.catalog && t.notifyOnUpdate == NotifyTarget.owner) {
        errors.add('«${t.label}» كتالوج وما له صاحب صف لإشعاره.');
      }
    }
    return errors;
  }
}
