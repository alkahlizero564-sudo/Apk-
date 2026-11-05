// Ready-made designs and databases to start from (all editable afterwards).

import '../models/project.dart';
import '../models/schema.dart';

/// A complete visual identity: shapes, cards, lists, navigation and decoration chosen to work together.
class Look {
  const Look(this.id, this.name, this.hint, {required this.seed, required this.accent, required this.mode, required this.style,
      required this.radius, required this.hero, required this.list, required this.nav, required this.deco, this.type = 'heavy'});
  final String id;
  final String name;
  final String hint;
  final String seed;
  final String accent;
  final String mode;
  final String style;
  final double radius;
  final String hero;
  final String list;
  final String nav;
  final String deco;
  final String type;

  /// The look with the owner's colors kept (when [keepColors]).
  ThemeSpec apply(ThemeSpec current, {bool keepColors = false}) => current.copyWith(
        look: id,
        preset: keepColors ? current.preset : id,
        seed: keepColors ? current.seed : seed,
        accent: keepColors ? current.accent : accent,
        mode: mode,
        style: style,
        radius: radius,
        hero: hero,
        list: list,
        nav: nav,
        deco: deco,
        type: type,
      );
}

const looks = <Look>[
  Look('aurora', 'أورورا', 'زجاج شفاف وفقاعات ضوء وشريط عائم',
      seed: '#6E4BFF', accent: '#2DD4BF', mode: 'dark', style: 'glass', radius: 22, hero: 'blob', list: 'cards', nav: 'floating', deco: 'blobs'),
  Look('wave', 'موجة', 'رأس بموجة ناعمة وبطاقات بظل خفيف',
      seed: '#0EA5E9', accent: '#6366F1', mode: 'light', style: 'soft', radius: 20, hero: 'wave', list: 'cards', nav: 'pill', deco: 'none'),
  Look('bold', 'جريء', 'Neo-Brutalism: حدود سميكة وظل مزاح وألوان صارخة',
      seed: '#FF5C35', accent: '#FFD23F', mode: 'light', style: 'brutal', radius: 6, hero: 'block', list: 'cards', nav: 'bar', deco: 'dots'),
  Look('luxe', 'فاخر', 'بساطة راقية: خطوط رفيعة ومساحات وعناوين أنيقة',
      seed: '#1C1917', accent: '#B45309', mode: 'light', style: 'outline', radius: 14, hero: 'minimal', list: 'compact', nav: 'bar', deco: 'none', type: 'light'),
  Look('soft', 'نيومورفيزم', 'بطاقات بارزة ناعمة على خلفية هادئة',
      seed: '#6366F1', accent: '#EC4899', mode: 'light', style: 'neu', radius: 24, hero: 'curve', list: 'cards', nav: 'floating', deco: 'none'),
  Look('gallery', 'معرض', 'الصور أولاً: شبكة كبيرة مثل المتاجر العالمية',
      seed: '#E11D48', accent: '#F59E0B', mode: 'light', style: 'flat', radius: 18, hero: 'card', list: 'grid', nav: 'pill', deco: 'none'),
  Look('neon', 'نيون', 'داكن بتوهج ملوّن وخط زمني للأحداث',
      seed: '#A855F7', accent: '#22D3EE', mode: 'dark', style: 'outline', radius: 16, hero: 'glow', list: 'timeline', nav: 'floating', deco: 'glow'),
  Look('geo', 'هندسي', 'قطع مائل وشبكة خطوط وحضور قوي',
      seed: '#059669', accent: '#0EA5E9', mode: 'dark', style: 'soft', radius: 12, hero: 'diagonal', list: 'cards', nav: 'bar', deco: 'grid'),
];

const heroShapes = {'blob': 'فقاعات', 'wave': 'موجة', 'curve': 'منحنى', 'diagonal': 'مائل', 'card': 'بطاقة عائمة', 'minimal': 'بسيط', 'block': 'كتلة', 'glow': 'توهج'};
const cardStyles = {'glass': 'زجاجي', 'soft': 'ظل ناعم', 'flat': 'مسطّح', 'outline': 'إطار', 'neu': 'بارز', 'brutal': 'جريء'};
const listStyles = {'cards': 'بطاقات', 'compact': 'مضغوطة', 'grid': 'شبكة', 'timeline': 'خط زمني'};
const navStyles = {'bar': 'شريط', 'floating': 'عائم', 'pill': 'كبسولة'};
const decoStyles = {'none': 'بدون', 'blobs': 'فقاعات', 'dots': 'نقاط', 'grid': 'شبكة', 'glow': 'توهج'};

class ThemePreset {
  const ThemePreset(this.id, this.name, this.seed, this.accent, this.mode, this.style);
  final String id;
  final String name;
  final String seed;
  final String accent;
  final String mode;
  final String style;

  ThemeSpec toSpec({double radius = 18, String layout = 'tabs'}) =>
      ThemeSpec(preset: id, seed: seed, accent: accent, mode: mode, style: style, radius: radius, layout: layout);
}

const themePresets = <ThemePreset>[
  ThemePreset('aurora', 'أورورا', '#6E4BFF', '#2DD4BF', 'dark', 'glass'),
  ThemePreset('ocean', 'محيط', '#0EA5E9', '#22D3EE', 'dark', 'glass'),
  ThemePreset('sunset', 'غروب', '#F97316', '#F43F5E', 'light', 'soft'),
  ThemePreset('mint', 'نعناع', '#10B981', '#84CC16', 'light', 'soft'),
  ThemePreset('rose', 'وردي', '#E11D48', '#F59E0B', 'light', 'soft'),
  ThemePreset('royal', 'ملكي', '#7C3AED', '#EAB308', 'dark', 'glass'),
  ThemePreset('mono', 'أحادي', '#18181B', '#71717A', 'light', 'flat'),
  ThemePreset('forest', 'غابة', '#166534', '#CA8A04', 'dark', 'flat'),
];

DbColumn _c(String name, String label, ColumnType type,
        {bool required = false, List<String> options = const [], String? def, bool adminOnly = false, bool show = true}) =>
    DbColumn(
        name: name,
        label: label,
        type: type,
        required: required,
        options: options,
        defaultValue: def,
        adminOnly: adminOnly,
        showInList: show);

class SchemaPreset {
  const SchemaPreset(this.id, this.name, this.icon, this.hint, this.build);
  final String id;
  final String name;
  final String icon;
  final String hint;
  final DbSchema Function() build;
}

final schemaPresets = <SchemaPreset>[
  SchemaPreset('store', 'متجر', 'shopping_bag', 'منتجات وطلبات وتقييمات', () => DbSchema(tables: [
        DbTable(name: 'products', label: 'المنتجات', icon: 'shopping_bag', owner: TableOwner.catalog, columns: [
          _c('title', 'اسم المنتج', ColumnType.text, required: true),
          _c('price', 'السعر', ColumnType.decimal, required: true),
          _c('image', 'صورة', ColumnType.image),
          _c('category', 'القسم', ColumnType.choice, options: ['عام', 'عروض', 'جديد'], def: 'عام'),
          _c('in_stock', 'متوفر', ColumnType.boolean, def: 'true'),
          _c('details', 'الوصف', ColumnType.longtext, show: false),
        ], notifyOnInsert: NotifyTarget.customers),
        DbTable(name: 'orders', label: 'الطلبات', icon: 'receipt', owner: TableOwner.customer, columns: [
          _c('items', 'المطلوب', ColumnType.longtext, required: true),
          _c('phone', 'رقم الهاتف', ColumnType.phone, required: true),
          _c('address', 'العنوان', ColumnType.text),
          _c('total', 'الإجمالي', ColumnType.decimal),
          _c('status', 'الحالة', ColumnType.choice,
              options: ['جديد', 'قيد التجهيز', 'في الطريق', 'تم التسليم', 'ملغي'], def: 'جديد', adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
        DbTable(name: 'reviews', label: 'التقييمات', icon: 'star', owner: TableOwner.shared, columns: [
          _c('product', 'المنتج', ColumnType.text, required: true),
          _c('stars', 'النجوم', ColumnType.integer, def: '5'),
          _c('comment', 'التعليق', ColumnType.longtext),
        ], notifyOnInsert: NotifyTarget.admin),
      ])),
  SchemaPreset('restaurant', 'مطعم', 'restaurant', 'قائمة طعام وطلبات توصيل', () => DbSchema(tables: [
        DbTable(name: 'menu', label: 'قائمة الطعام', icon: 'restaurant', owner: TableOwner.catalog, columns: [
          _c('title', 'الصنف', ColumnType.text, required: true),
          _c('price', 'السعر', ColumnType.decimal, required: true),
          _c('section', 'القسم', ColumnType.choice, options: ['وجبات', 'مشروبات', 'حلويات'], def: 'وجبات'),
          _c('image', 'صورة', ColumnType.image),
          _c('available', 'متاح', ColumnType.boolean, def: 'true'),
        ]),
        DbTable(name: 'orders', label: 'الطلبات', icon: 'delivery', owner: TableOwner.customer, columns: [
          _c('items', 'الطلب', ColumnType.longtext, required: true),
          _c('phone', 'الهاتف', ColumnType.phone, required: true),
          _c('address', 'العنوان', ColumnType.text, required: true),
          _c('notes', 'ملاحظات', ColumnType.text, show: false),
          _c('status', 'الحالة', ColumnType.choice,
              options: ['جديد', 'يُحضّر', 'خرج للتوصيل', 'وصل'], def: 'جديد', adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
      ])),
  SchemaPreset('clinic', 'عيادة', 'medical', 'خدمات ومواعيد ومرضى', () => DbSchema(tables: [
        DbTable(name: 'services', label: 'الخدمات', icon: 'medical', owner: TableOwner.catalog, columns: [
          _c('title', 'الخدمة', ColumnType.text, required: true),
          _c('price', 'السعر', ColumnType.decimal),
          _c('duration', 'المدة بالدقائق', ColumnType.integer, def: '30'),
        ]),
        DbTable(name: 'appointments', label: 'المواعيد', icon: 'calendar', owner: TableOwner.customer, columns: [
          _c('patient', 'اسم المريض', ColumnType.text, required: true),
          _c('phone', 'الهاتف', ColumnType.phone, required: true),
          _c('service', 'الخدمة', ColumnType.text),
          _c('visit_at', 'الموعد', ColumnType.datetime, required: true),
          _c('status', 'الحالة', ColumnType.choice, options: ['بانتظار التأكيد', 'مؤكد', 'تم', 'ملغي'],
              def: 'بانتظار التأكيد', adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
      ])),
  SchemaPreset('booking', 'حجوزات', 'event', 'صالون، ملاعب، قاعات', () => DbSchema(tables: [
        DbTable(name: 'places', label: 'الأماكن', icon: 'place', owner: TableOwner.catalog, columns: [
          _c('title', 'الاسم', ColumnType.text, required: true),
          _c('price', 'سعر الساعة', ColumnType.decimal),
          _c('image', 'صورة', ColumnType.image),
        ]),
        DbTable(name: 'bookings', label: 'الحجوزات', icon: 'event', owner: TableOwner.customer, columns: [
          _c('place', 'المكان', ColumnType.text, required: true),
          _c('day', 'اليوم', ColumnType.date, required: true),
          _c('hours', 'عدد الساعات', ColumnType.integer, def: '1'),
          _c('phone', 'الهاتف', ColumnType.phone, required: true),
          _c('status', 'الحالة', ColumnType.choice, options: ['جديد', 'مؤكد', 'مرفوض'], def: 'جديد', adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
      ])),
  SchemaPreset('school', 'مدرسة', 'school', 'إعلانات وواجبات وطلاب', () => DbSchema(tables: [
        DbTable(name: 'announcements', label: 'الإعلانات', icon: 'campaign', owner: TableOwner.catalog, columns: [
          _c('title', 'العنوان', ColumnType.text, required: true),
          _c('body', 'التفاصيل', ColumnType.longtext),
          _c('class_name', 'الفصل', ColumnType.text),
        ], notifyOnInsert: NotifyTarget.customers),
        DbTable(name: 'homework', label: 'الواجبات', icon: 'book', owner: TableOwner.catalog, columns: [
          _c('title', 'الواجب', ColumnType.text, required: true),
          _c('subject', 'المادة', ColumnType.text),
          _c('due', 'آخر موعد', ColumnType.date),
        ], notifyOnInsert: NotifyTarget.customers),
        DbTable(name: 'questions', label: 'أسئلة الطلاب', icon: 'chat', owner: TableOwner.customer, columns: [
          _c('question', 'السؤال', ColumnType.longtext, required: true),
          _c('answer', 'الرد', ColumnType.longtext, adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
      ])),
  SchemaPreset('delivery', 'توصيل', 'delivery', 'طلبات توصيل وتتبع', () => DbSchema(tables: [
        DbTable(name: 'requests', label: 'طلبات التوصيل', icon: 'delivery', owner: TableOwner.customer, columns: [
          _c('pickup', 'من', ColumnType.text, required: true),
          _c('dropoff', 'إلى', ColumnType.text, required: true),
          _c('phone', 'الهاتف', ColumnType.phone, required: true),
          _c('price', 'السعر', ColumnType.decimal, adminOnly: true),
          _c('status', 'الحالة', ColumnType.choice, options: ['جديد', 'تم القبول', 'في الطريق', 'تم'],
              def: 'جديد', adminOnly: true),
        ], notifyOnInsert: NotifyTarget.admin, notifyOnUpdate: NotifyTarget.owner),
        DbTable(name: 'drivers', label: 'السائقين', icon: 'person', owner: TableOwner.admin, columns: [
          _c('title', 'الاسم', ColumnType.text, required: true),
          _c('phone', 'الهاتف', ColumnType.phone),
          _c('active', 'نشط', ColumnType.boolean, def: 'true'),
        ]),
      ])),
  SchemaPreset('expenses', 'مصروفات', 'wallet', 'تطبيق شخصي لتسجيل المصروفات', () => DbSchema(tables: [
        DbTable(name: 'expenses', label: 'المصروفات', icon: 'wallet', owner: TableOwner.customer, columns: [
          _c('title', 'البند', ColumnType.text, required: true),
          _c('amount', 'المبلغ', ColumnType.decimal, required: true),
          _c('category', 'التصنيف', ColumnType.choice, options: ['أكل', 'مواصلات', 'فواتير', 'أخرى'], def: 'أخرى'),
          _c('day', 'التاريخ', ColumnType.date, def: 'today'),
        ]),
      ])),
  SchemaPreset('notes', 'ملاحظات ومهام', 'checklist', 'مهام مع أولوية وإنجاز', () => DbSchema(tables: [
        DbTable(name: 'tasks', label: 'المهام', icon: 'checklist', owner: TableOwner.customer, columns: [
          _c('title', 'المهمة', ColumnType.text, required: true),
          _c('priority', 'الأولوية', ColumnType.choice, options: ['عالية', 'متوسطة', 'منخفضة'], def: 'متوسطة'),
          _c('done', 'تمت', ColumnType.boolean, def: 'false'),
          _c('due', 'الموعد', ColumnType.date),
        ]),
      ])),
  SchemaPreset('empty', 'فارغ', 'add', 'صمّم الجداول بنفسك', () => DbSchema()),
];

/// Icons the generated apps know (same names in every language engine).
const tableIcons = <String>[
  'list', 'shopping_bag', 'receipt', 'star', 'restaurant', 'delivery', 'medical', 'calendar', 'event', 'place',
  'school', 'campaign', 'book', 'chat', 'person', 'wallet', 'checklist', 'home', 'settings', 'car', 'phone',
  'photo', 'store', 'work', 'payments',
];
