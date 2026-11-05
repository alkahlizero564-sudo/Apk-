// Ready-made designs and databases to start from (all editable afterwards).

import '../models/project.dart';
import '../models/schema.dart';

/// A design school: a complete visual identity. The HTML/PHP engines draw the school itself; the other engines
/// use the tokens next to it (card style, header shape, list, nav, background) that come closest to it.
class Look {
  const Look(this.id, this.name, this.hint, {required this.group, required this.seed, required this.accent, required this.mode, required this.style,
      required this.radius, required this.hero, required this.list, required this.nav, required this.deco, this.type = 'heavy', this.home = 'tiles', this.sheet = 'sheet'});
  final String id;
  final String name;
  final String hint;
  final int group; // index in lookGroups
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
  final String home;
  final String sheet;

  /// Thumbnail rendered from the real engine (assets/schools/<id>.jpg).
  String get thumb => 'assets/schools/$id.jpg';

  /// The school with the owner's colors kept (when [keepColors]).
  ThemeSpec apply(ThemeSpec current, {bool keepColors = false}) => current.copyWith(
        look: id,
        school: id,
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
        home: home,
        sheet: sheet,
      );
}

const lookGroups = ['البساطة والوضوح', 'العمق والملمس', 'الأجواء الداكنة', 'الجرأة والتمرد', 'التفاعل والمحتوى'];

const looks = <Look>[
  // 1. Minimal & clear
  Look('flat', 'Flat كلاسيكي', 'مربعات ملوّنة صلبة بلا ظلال (Metro)', group: 0,
      seed: '#0078D7', accent: '#E3008C', mode: 'light', style: 'flat', radius: 0, hero: 'block', list: 'cards', nav: 'bar', deco: 'none', type: 'light'),
  Look('material', 'Material 3', 'ألوان ديناميكية وأسطح متدرجة وأزرار كبسولة', group: 0,
      seed: '#6750A4', accent: '#7D5260', mode: 'light', style: 'soft', radius: 22, hero: 'curve', list: 'cards', nav: 'bar', deco: 'none'),
  Look('bento', 'Bento Grid', 'مربعات بأحجام مختلفة مثل Apple وأرقام كبيرة', group: 0,
      seed: '#0071E3', accent: '#FF9F0A', mode: 'light', style: 'flat', radius: 26, hero: 'minimal', list: 'grid', nav: 'floating', deco: 'none', home: 'bento'),
  Look('cards', 'Clean Cards', 'بطاقات بيضاء نظيفة وشريط عروض متحرك', group: 0,
      seed: '#2563EB', accent: '#10B981', mode: 'light', style: 'soft', radius: 16, hero: 'card', list: 'cards', nav: 'bar', deco: 'none', home: 'carousel'),
  Look('swiss', 'Swiss / Minimal', 'أبيض وأسود وخطوط رفيعة وطباعة قوية', group: 0,
      seed: '#000000', accent: '#E30613', mode: 'light', style: 'outline', radius: 0, hero: 'minimal', list: 'compact', nav: 'bar', deco: 'none', type: 'light', sheet: 'page'),
  // 2. Depth & texture
  Look('skeuo', 'Skeuomorphism', 'خامات حقيقية: جلد وخشب وأزرار بارزة', group: 1,
      seed: '#8B5A2B', accent: '#C9A227', mode: 'light', style: 'soft', radius: 14, hero: 'card', list: 'cards', nav: 'bar', deco: 'dots'),
  Look('glass', 'Glassmorphism', 'زجاج مصنفر فوق ألوان متوهجة', group: 1,
      seed: '#7C3AED', accent: '#06B6D4', mode: 'dark', style: 'glass', radius: 22, hero: 'blob', list: 'cards', nav: 'floating', deco: 'blobs', home: 'bento'),
  Look('neu', 'Neumorphism', 'عناصر بارزة وغائرة من نفس الخلفية', group: 1,
      seed: '#5B6CFF', accent: '#FF6B9A', mode: 'light', style: 'neu', radius: 24, hero: 'curve', list: 'cards', nav: 'floating', deco: 'none'),
  Look('clay', 'Claymorphism', 'أشكال طينية منفوخة ومرحة', group: 1,
      seed: '#FF7A59', accent: '#7C5CFF', mode: 'light', style: 'neu', radius: 28, hero: 'blob', list: 'grid', nav: 'pill', deco: 'blobs', home: 'bento'),
  Look('spatial', 'Spatial / VisionOS', 'نوافذ زجاجية عائمة بعمق ثلاثي الأبعاد', group: 1,
      seed: '#5E8BFF', accent: '#C084FC', mode: 'dark', style: 'glass', radius: 34, hero: 'card', list: 'cards', nav: 'floating', deco: 'glow', home: 'carousel'),
  // 3. Dark moods
  Look('dark', 'Dark قياسي', 'رمادي داكن مريح للعين ولمسات لون', group: 2,
      seed: '#3B82F6', accent: '#22C55E', mode: 'dark', style: 'soft', radius: 18, hero: 'minimal', list: 'compact', nav: 'bar', deco: 'none'),
  Look('cyber', 'Neon / Cyberpunk', 'أسود وألوان نيون متوهجة وحواف حادة', group: 2,
      seed: '#FF2BD6', accent: '#00F0FF', mode: 'dark', style: 'outline', radius: 0, hero: 'glow', list: 'timeline', nav: 'floating', deco: 'grid'),
  Look('aurora', 'Aurora Gradient', 'تدرجات شفق قطبي متحركة', group: 2,
      seed: '#7C3AED', accent: '#22D3EE', mode: 'dark', style: 'glass', radius: 22, hero: 'blob', list: 'cards', nav: 'pill', deco: 'glow', home: 'carousel'),
  Look('hud', 'Sci-Fi HUD', 'شاشة قيادة: شبكة وخطوط مسح ودوائر رادار', group: 2,
      seed: '#00E5FF', accent: '#FFB020', mode: 'dark', style: 'outline', radius: 2, hero: 'diagonal', list: 'timeline', nav: 'bar', deco: 'grid'),
  // 4. Bold & rebellious
  Look('brutal', 'Neo-Brutalism', 'حدود سوداء سميكة وظل مزاح وألوان صارخة', group: 3,
      seed: '#FF5C35', accent: '#FFD23F', mode: 'light', style: 'brutal', radius: 6, hero: 'block', list: 'cards', nav: 'bar', deco: 'dots', home: 'bento'),
  Look('retro', 'Windows 95', 'نوافذ رمادية وأزرار بارزة وحنين للتسعينات', group: 3,
      seed: '#000080', accent: '#008080', mode: 'light', style: 'outline', radius: 0, hero: 'block', list: 'compact', nav: 'bar', deco: 'none'),
  Look('pixel', 'Pixel Art', 'بكسلات وألعاب 8-بت', group: 3,
      seed: '#FF004D', accent: '#29ADFF', mode: 'dark', style: 'brutal', radius: 0, hero: 'block', list: 'grid', nav: 'bar', deco: 'dots'),
  Look('y2k', 'Y2K Chrome', 'كروم لامع وألوان الألفية', group: 3,
      seed: '#FF4FD8', accent: '#7DF9FF', mode: 'light', style: 'glass', radius: 30, hero: 'wave', list: 'grid', nav: 'pill', deco: 'blobs', home: 'carousel'),
  Look('anti', 'Anti-Design', 'كسر القواعد: تداخل وميلان وتباين حاد', group: 3,
      seed: '#FF3B00', accent: '#1400FF', mode: 'light', style: 'brutal', radius: 0, hero: 'diagonal', list: 'cards', nav: 'floating', deco: 'none', home: 'bento'),
  // 5. Interaction & content
  Look('kinetic', 'Kinetic Typography', 'عناوين ضخمة متحركة وظهور مع التمرير', group: 4,
      seed: '#D4FF3A', accent: '#FF4D00', mode: 'dark', style: 'flat', radius: 22, hero: 'minimal', list: 'cards', nav: 'pill', deco: 'none'),
  Look('sketch', 'Hand-Drawn', 'رسم يدوي: خطوط متعرجة وورق دفتر', group: 4,
      seed: '#2B59C3', accent: '#F25C54', mode: 'light', style: 'outline', radius: 16, hero: 'wave', list: 'cards', nav: 'bar', deco: 'dots'),
  Look('chat', 'Conversational AI', 'الرئيسية محادثة: اكتب ما تريد ويرد التطبيق', group: 4,
      seed: '#10A37F', accent: '#7C3AED', mode: 'dark', style: 'soft', radius: 22, hero: 'minimal', list: 'compact', nav: 'pill', deco: 'none', home: 'chat'),
  Look('zero', 'Zero UI', 'زر واحد كبير والباقي يختفي', group: 4,
      seed: '#7C5CFF', accent: '#22D3EE', mode: 'dark', style: 'soft', radius: 40, hero: 'minimal', list: 'compact', nav: 'pill', deco: 'glow', home: 'focus'),
];

/// Older apps stored one of eight looks; each maps to the nearest school.
const lookToSchool = {'wave': 'material', 'bold': 'brutal', 'luxe': 'swiss', 'soft': 'neu', 'gallery': 'bento', 'neon': 'cyber', 'geo': 'dark'};
Look? lookById(String id) {
  final want = lookToSchool[id] ?? id;
  for (final l in looks) {
    if (l.id == want) return l;
  }
  return null;
}

const homeLayouts = {'': 'حسب المدرسة', 'tiles': 'مربعات', 'bento': 'Bento', 'carousel': 'عروض متحركة', 'feed': 'Reels', 'chat': 'محادثة', 'focus': 'زر واحد'};
const sheetStyles = {'sheet': 'نافذة سفلية تُسحب', 'page': 'صفحة كاملة'};
const fontChoices = {'': 'حسب المدرسة', 'cairo': 'Cairo', 'tajawal': 'Tajawal', 'plex': 'IBM Plex', 'readex': 'Readex', 'messiri': 'المسيري', 'kufi': 'كوفي', 'changa': 'Changa', 'lalezar': 'لاله‌زار'};
const heroShapes = {'blob': 'فقاعات', 'wave': 'موجة', 'curve': 'منحنى', 'diagonal': 'مائل', 'card': 'بطاقة عائمة', 'minimal': 'بسيط', 'block': 'كتلة', 'glow': 'توهج'};
const cardStyles = {'glass': 'زجاجي', 'soft': 'ظل ناعم', 'flat': 'مسطّح', 'outline': 'إطار', 'neu': 'بارز', 'brutal': 'جريء'};
const listStyles = {'cards': 'بطاقات', 'compact': 'مضغوطة', 'grid': 'شبكة', 'timeline': 'خط زمني', 'reels': 'Reels'};
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
