<?php
// Alpha PHP engine: HTML of every screen (same look as the HTML engine; assets/style.css).
declare(strict_types=1);

function e(mixed $v): string
{
    return htmlspecialchars((string)($v ?? ''), ENT_QUOTES, 'UTF-8');
}

const ICONS = [
    'search' => 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3',
    'list' => 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
    'shopping_bag' => 'M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4zM3 6h18M16 10a4 4 0 0 1-8 0',
    'receipt' => 'M4 2v20l3-2 3 2 3-2 3 2 3-2 1 .7V2l-3 2-3-2-3 2-3-2-3 2zM8 8h8M8 12h8M8 16h5',
    'star' => 'm12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z',
    'restaurant' => 'M3 2v7a3 3 0 0 0 6 0V2M6 2v20M18 2c-2 0-3 2.5-3 6s1 5 3 5v9',
    'delivery' => 'M10 17h4V5H2v12h3M14 9h4l4 4v4h-2M7.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM17.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
    'medical' => 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6z',
    'calendar' => 'M3 5h18v16H3zM3 10h18M8 3v4M16 3v4',
    'event' => 'M3 5h18v16H3zM3 10h18M8 3v4M16 3v4m-7 9 2 2 4-4',
    'place' => 'M12 22s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
    'school' => 'M2 9l10-5 10 5-10 5zM6 11v5c0 1.7 2.7 3 6 3s6-1.3 6-3v-5',
    'campaign' => 'M3 11v2a1 1 0 0 0 1 1h3l6 4V6L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8',
    'book' => 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5zM4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5',
    'chat' => 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
    'person' => 'M20 21a8 8 0 0 0-16 0M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10z',
    'wallet' => 'M3 7a2 2 0 0 1 2-2h14v4M3 7v12a2 2 0 0 0 2 2h16V9H5a2 2 0 0 1-2-2zM16 15h.01',
    'checklist' => 'm3 7 2 2 4-4M3 17l2 2 4-4M13 6h8M13 12h8M13 18h8',
    'home' => 'M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z',
    'car' => 'M5 17h14M5 17a2 2 0 1 0 4 0M15 17a2 2 0 1 0 4 0M3 17v-5l2-5h14l2 5v5',
    'phone' => 'M22 16.9v3a2 2 0 0 1-2.2 2A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7l.7 2.7-1.8 3.4a16 16 0 0 0 6 6l3.4-1.8 2.7.7a2 2 0 0 1 1.7 2z',
    'photo' => 'M3 3h18v18H3zM8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM21 15l-5-5L5 21',
    'store' => 'M3 9 4.5 3h15L21 9M3 9v12h18V9M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0M9 21v-6h6v6',
    'work' => 'M3 7h18v13H3zM8 7V4h8v3M3 13h18',
    'payments' => 'M2 6h20v12H2zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
    'dashboard' => 'M3 3h8v10H3zM13 3h8v6h-8zM13 11h8v10h-8zM3 15h8v6H3z',
    'bell' => 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0',
    'plus' => 'M12 5v14M5 12h14',
    'send' => 'M22 2 11 13M22 2l-7 20-4-9-9-4z',
    'edit' => 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z',
    'trash' => 'M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6',
    'logout' => 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
    'lock' => 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
    'cloud' => 'M17.5 19H9a7 7 0 1 1 6.7-9h1.8a4.5 4.5 0 1 1 0 9z',
];

function icon(string $name, int $size = 22): string
{
    $d = ICONS[$name] ?? ICONS['list'];
    return "<svg width=\"$size\" height=\"$size\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"$d\"/></svg>";
}

function fmt(array $c, mixed $v): string
{
    if ($v === null || $v === '') return '';
    return match ($c['type'] ?? 'text') {
        'bool' => ($v === true || $v === 1 || $v === '1' || $v === 'true') ? 'نعم' : 'لا',
        'decimal' => is_numeric($v) ? (floor((float)$v) == (float)$v ? (string)(int)$v : number_format((float)$v, 2, '.', '')) : (string)$v,
        'datetime' => ($ts = strtotime((string)$v)) ? date('Y/m/d H:i', $ts) : (string)$v,
        'date' => ($ts = strtotime((string)$v)) ? date('Y/m/d', $ts) : (string)$v,
        default => (string)$v,
    };
}

function col_of(array $t, string $type, ?bool $adminOnly = null): ?array
{
    foreach ($t['columns'] ?? [] as $c) {
        if (($c['type'] ?? '') === $type && ($adminOnly === null || (bool)($c['adminOnly'] ?? false) === $adminOnly)) return $c;
    }
    return null;
}

function title_col(array $t): ?array
{
    foreach ($t['columns'] ?? [] as $c) if (in_array($c['type'] ?? '', ['text', 'choice'], true)) return $c;
    return $t['columns'][0] ?? null;
}

function badge_col(array $t): ?array
{
    return col_of($t, 'choice', true) ?? col_of($t, 'choice');
}

function pill_class(string $v): string
{
    if (preg_match('/ملغي|مرفوض|cancel|reject/iu', $v)) return 'bad';
    if (preg_match('/تم|وصل|مؤكد|done|deliver|confirm/iu', $v)) return 'ok';
    if (preg_match('/جديد|new|انتظار/iu', $v)) return '';
    return 'warn';
}

function post_button(string $action, string $label, string $class = 'btn', array $fields = []): string
{
    $h = '<form method="post" style="margin:0"><input type="hidden" name="csrf" value="' . e(csrf()) . '"><input type="hidden" name="action" value="' . e($action) . '">';
    foreach ($fields as $k => $v) $h .= '<input type="hidden" name="' . e($k) . '" value="' . e($v) . '">';
    return $h . '<button class="' . e($class) . '">' . $label . '</button></form>';
}

// Design schools (same style.css as the HTML engine). Each brings its usual layout; a school chosen in Alpha keeps its own choices.
const SCHOOLS = [
    'flat' => ['tiles', 'cards', 'bar'], 'material' => ['tiles', 'cards', 'bar'], 'bento' => ['bento', 'grid', 'floating'], 'cards' => ['tiles', 'cards', 'bar'],
    'swiss' => ['tiles', 'compact', 'bar'], 'skeuo' => ['tiles', 'cards', 'bar'], 'glass' => ['bento', 'cards', 'floating'], 'neu' => ['tiles', 'cards', 'floating'],
    'clay' => ['bento', 'grid', 'pill'], 'spatial' => ['tiles', 'cards', 'floating'], 'dark' => ['tiles', 'compact', 'bar'], 'cyber' => ['tiles', 'timeline', 'floating'],
    'aurora' => ['tiles', 'cards', 'pill'], 'hud' => ['tiles', 'timeline', 'bar'], 'brutal' => ['bento', 'cards', 'bar'], 'retro' => ['tiles', 'compact', 'bar'],
    'pixel' => ['tiles', 'grid', 'bar'], 'y2k' => ['tiles', 'grid', 'pill'], 'anti' => ['bento', 'cards', 'floating'], 'kinetic' => ['tiles', 'cards', 'pill'],
    'sketch' => ['tiles', 'cards', 'bar'], 'chat' => ['tiles', 'compact', 'pill'], 'zero' => ['tiles', 'compact', 'pill'],
];
const FROM_LOOK = ['aurora' => 'aurora', 'wave' => 'material', 'bold' => 'brutal', 'luxe' => 'swiss', 'soft' => 'neu', 'gallery' => 'bento', 'neon' => 'cyber', 'geo' => 'dark'];

// Generated artwork for rows without a picture (same idea as the HTML engine): a pattern and the table's icon.
function art_inner(string $key, string $icon): string
{
    $h = crc32($key);
    $n = fn(int $i) => ($h >> ($i * 3)) % 100;
    $w = 'rgba(255,255,255,';
    $pats = [
        '<circle cx="' . $n(1) . '" cy="' . $n(2) . '" r="' . (26 + $n(3) % 30) . '" fill="' . $w . '.22)"/><circle cx="' . $n(4) . '" cy="' . $n(5) . '" r="' . (14 + $n(6) % 20) . '" fill="' . $w . '.16)"/>',
        implode('', array_map(fn($i) => '<path d="M' . ($i * 16 - 40) . ' 110 L' . ($i * 16 + 20) . ' -10" stroke="' . $w . '.16)" stroke-width="5"/>', range(0, 8))),
        implode('', array_map(fn($i) => '<circle cx="' . ($n(1) % 60 + 20) . '" cy="' . ($n(2) % 60 + 20) . '" r="' . (52 - $i * 14) . '" fill="none" stroke="' . $w . (0.1 + $i * 0.07) . ')" stroke-width="3"/>', range(0, 3))),
        implode('', array_map(fn($i) => '<circle cx="' . (($i % 6) * 18 + 5) . '" cy="' . (intdiv($i, 6) * 18 + 5) . '" r="2" fill="' . $w . '.3)"/>', range(0, 35))),
    ];
    return '<svg class="bg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">' . $pats[$h % 4] . '</svg><span style="position:relative">' . icon($icon, 24) . '</span>';
}

function theme_tokens(array $C): array
{
    $t = $C['theme'] ?? [];
    $own = isset(SCHOOLS[$t['school'] ?? '']);
    $school = $own ? $t['school'] : (FROM_LOOK[$t['look'] ?? ''] ?? 'material');
    [$home, $list, $nav] = SCHOOLS[$school];
    $pick = fn($v, array $ok, string $d) => $own && in_array($v, $ok, true) ? $v : $d;
    return [
        'school' => $school,
        'home' => $pick($t['home'] ?? '', ['tiles', 'bento'], $home), // the server-made pages have the tile homes
        'list' => $pick($t['list'] ?? '', ['cards', 'compact', 'grid', 'timeline'], $list),
        'nav' => $pick($t['nav'] ?? '', ['bar', 'floating', 'pill'], $nav),
    ];
}

function theme_attrs(array $C): string
{
    $t = $C['theme'] ?? [];
    $k = theme_tokens($C);
    $classes = trim((($t['mode'] ?? 'light') === 'light' ? 'light ' : '') . 's-' . $k['school'] . ' home-' . $k['home'] . ' list-' . $k['list'] . ' nav-' . $k['nav']);
    $style = '--seed:' . e($t['seed'] ?? '#6750A4') . ';--accent:' . e($t['accent'] ?? '#7D5260');
    if (isset(SCHOOLS[$t['school'] ?? '']) && isset($t['radius'])) $style .= ';--r:' . (int)$t['radius'] . 'px';
    if (preg_match('/^[a-z]+$/', $t['font'] ?? '')) $style .= ";--font:'A-" . $t['font'] . "',system-ui,sans-serif";
    $dir = ($C['app']['rtl'] ?? true) === false ? 'ltr' : 'rtl';
    return 'class="' . $classes . '" style="' . $style . '" dir="' . $dir . '" lang="' . ($dir === 'rtl' ? 'ar' : 'en') . '"';
}

function head(array $C): string
{
    return '<!doctype html><html ' . theme_attrs($C) . '><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">' .
        '<title>' . e($C['app']['title'] ?? 'Alpha') . '</title><link rel="stylesheet" href="assets/style.css"></head><body><div class="deco"></div>';
}

function flash(): string
{
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f ? '<div class="toast' . ($f['bad'] ? ' bad' : '') . '" id="toast">' . e($f['text']) . '</div><script>setTimeout(function(){var t=document.getElementById("toast");if(t)t.remove()},3500)</script>' : '';
}

function render_error(array $C, string $message): void
{
    echo head($C) . '<div class="wrap"><div class="empty"><span class="big">' . icon('cloud', 46) . '</span>' . e($message) .
        '<br><br><a class="btn sm" href="?">إعادة المحاولة</a></div></div></body></html>';
}

function render_login(array $C, Backend $B, string $mode): void
{
    $role = $B->role;
    $signup = $mode === 'signup';
    $code = $mode === 'code' && !empty($_SESSION['pending']);
    $sub = $code ? 'تأكيد البريد الإلكتروني' : ($signup ? 'أنشئ حسابك' : ($role === 'admin' ? 'لوحة الإدارة' : 'مرحباً بعودتك'));
    $hidden = fn(string $action, string $back) => '<input type="hidden" name="csrf" value="' . e(csrf()) . '"><input type="hidden" name="action" value="' . $action . '"><input type="hidden" name="back" value="' . $back . '">';
    echo head($C) . '<div class="login"><header class="hero"><i class="o o1"></i><i class="o o2"></i><div class="avatar" style="margin:0 auto 12px;background:rgba(255,255,255,.2)">' . icon($role === 'admin' ? 'lock' : 'person', 30) .
        '</div><h1>' . e($C['app']['title'] ?? '') . '</h1><p>' . $sub . '</p></header>';
    if ($code) {
        echo '<form class="card" method="post">' . $hidden('verify', '?mode=code') .
            '<p style="text-align:center;line-height:1.8">أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى <b>' . e($_SESSION['pending']['email']) . '</b></p>' .
            '<input class="input ltr" name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" required placeholder="••••••" style="text-align:center;font-size:26px;letter-spacing:10px;font-weight:800">' .
            '<button class="btn">تأكيد</button></form><form method="post" style="margin:0 18px">' . $hidden('resend', '?mode=code') .
            '<button class="linkbtn">أرسل الرمز مرة أخرى</button></form><a class="linkbtn" style="display:block;text-align:center" href="?">رجوع لتسجيل الدخول</a>';
    } else {
        echo '<form class="card" method="post">' . $hidden($signup ? 'signup' : 'login', '?' . ($signup ? 'mode=signup' : '')) .
            ($signup ? '<label class="lbl">الاسم</label><input class="input" name="name" required minlength="2">' .
                '<label class="lbl">رقم الهاتف</label><input class="input ltr" type="tel" name="phone" required pattern="[+0-9 ()-]{7,20}">' : '') .
            '<label class="lbl">البريد الإلكتروني</label><input class="input ltr" type="email" name="email" required>' .
            '<label class="lbl">كلمة المرور</label><input class="input ltr" type="password" name="password" required minlength="6">' .
            '<button class="btn">' . ($signup ? 'إنشاء الحساب' : 'دخول') . '</button>' .
            '<a class="linkbtn" style="display:block;text-align:center" href="?' . ($signup ? '' : 'mode=signup') . '">' . ($signup ? 'عندي حساب، سجّل دخولي' : 'ما عندي حساب؟ أنشئ واحداً') . '</a></form>';
    }
    echo '</div>' . flash() . '</body></html>';
}

function render_layout(array $C, Backend $B, string $current, string $title, string $body, bool $nav = true): void
{
    $tables = array_values(array_filter($C['tables'] ?? [], fn($t) => ($t['owner'] ?? '') !== 'admin' || $B->isAdmin || $B->role === 'admin'));
    $tabs = [['home', 'الرئيسية', 'dashboard', '?']];
    foreach (array_slice($tables, 0, 3) as $t) $tabs[] = ['table:' . $t['name'], $t['label'] ?? $t['name'], $t['icon'] ?? 'list', '?p=table&t=' . rawurlencode($t['name'])];
    if ($B->kind !== 'none' || ($C['backend']['auth'] ?? 'none') === 'email_password') $tabs[] = ['notes', 'الإشعارات', 'bell', '?p=notes'];
    $tabs[] = ['me', 'حسابي', 'person', '?p=me'];
    echo head($C);
    if ($title !== '') echo '<div class="topbar"><h2>' . e($title) . '</h2></div>';
    echo $body;
    if ($nav) {
        echo '<nav class="nav">';
        foreach ($tabs as [$id, $label, $ic, $href]) {
            echo '<a href="' . e($href) . '" style="text-decoration:none;flex:1"><button type="button" class="' . ($current === $id ? 'on' : '') . '" style="width:100%"><i>' . icon($ic) . '</i>' . e($label) . '</button></a>';
        }
        echo '</nav>';
    }
    echo flash() . '</body></html>';
}

function home_page(array $C, Backend $B, array $tables, array $stats): string
{
    $app = $C['app'] ?? [];
    $hello = $B->name ? 'أهلاً ' . $B->name : 'أهلاً بك';
    $title = ($app['headline'] ?? '') ?: ($app['title'] ?? '');
    $h = '<header class="hero"><i class="o o1"></i><i class="o o2"></i><div class="hb">' . icon($B->isAdmin ? 'dashboard' : 'home', 14) . e($B->isAdmin ? 'لوحة الإدارة' : ($app['title'] ?? '')) . '</div><h1>' . e($title) . '</h1><p>' .
        e(($app['subtitle'] ?? '') ?: ($B->isAdmin ? 'لوحة التحكم' : $hello)) . '</p>';
    $words = implode(' ✦ ', array_fill(0, 6, e($title))) . ' ✦ ';
    $h .= '<div class="marq" aria-hidden="true"><span>' . $words . '</span><span>' . $words . '</span></div></header>';
    $h .= '<div class="wrap"><div class="section"><h3>' . ($B->isAdmin ? 'نظرة عامة' : 'الأقسام') . '</h3></div><div class="grid">';
    $tiles = [];
    foreach (array_values($tables) as $i => $t) {
        $n = $stats[$t['name']] ?? null;
        if ($n === null) { try { $n = count($B->list($t)); } catch (Throwable $e) { $n = '›'; } }
        $tiles[] = '<a class="card tile tap' . ($i === 0 ? ' hl' : '') . '" style="text-decoration:none;color:inherit" href="?p=table&t=' . rawurlencode($t['name']) . '"><div class="ic">' . icon($t['icon'] ?? 'list') .
            '</div><b>' . e((string)$n) . '</b><span>' . e($t['label'] ?? $t['name']) . '</span></a>';
    }
    if (isset($stats['_customers'])) $tiles[] = '<div class="card tile"><div class="ic">' . icon('person') . '</div><b>' . (int)$stats['_customers'] . '</b><span>العملاء</span></div>';
    if (count($tiles) % 2 && theme_tokens($C)['home'] !== 'bento') $tiles[count($tiles) - 1] = str_replace('card tile', 'card tile wide', $tiles[count($tiles) - 1]);
    $h .= implode('', $tiles);
    return $h . '</div></div>';
}

function table_page(Backend $B, array $t, string $q, ?string $filter): string
{
    try {
        $rows = $B->list($t);
    } catch (BackendError $e) {
        return '<div class="wrap"><div class="empty"><span class="big">' . icon('cloud', 46) . '</span>' . e($e->getMessage()) . '</div></div>';
    }
    $badge = badge_col($t);
    $title = title_col($t);
    $image = col_of($t, 'image');
    $price = col_of($t, 'decimal');
    $base = '?p=table&t=' . rawurlencode($t['name']);
    $h = '<div class="wrap"><form method="get"><input type="hidden" name="p" value="table"><input type="hidden" name="t" value="' . e($t['name']) . '">' .
        '<div class="search">' . icon('search', 18) . '<input class="input" name="q" value="' . e($q) . '" placeholder="بحث في ' . e($t['label'] ?? '') . '"></div></form>';
    if ($badge && !empty($badge['options'])) {
        $h .= '<div class="chips"><a class="chip ' . ($filter === null ? 'on' : '') . '" href="' . $base . '">الكل</a>';
        foreach ($badge['options'] as $o) $h .= '<a class="chip ' . ($filter === $o ? 'on' : '') . '" href="' . $base . '&f=' . rawurlencode($o) . '">' . e($o) . '</a>';
        $h .= '</div>';
    }
    $ql = mb_strtolower(trim($q));
    $shown = array_filter($rows, function ($r) use ($t, $badge, $filter, $ql) {
        if ($filter !== null && $badge && ($r[$badge['name']] ?? null) !== $filter) return false;
        if ($ql === '') return true;
        foreach ($t['columns'] ?? [] as $c) if (str_contains(mb_strtolower((string)($r[$c['name']] ?? '')), $ql)) return true;
        return false;
    });
    if (!$shown) {
        $h .= '<div class="empty"><span class="big">' . icon($t['icon'] ?? 'list', 46) . '</span>' . ($rows ? 'لا نتائج' : 'لا يوجد شيء في ' . e($t['label'] ?? '') . ' بعد') . '</div>';
    }
    foreach ($shown as $r) {
        $details = [];
        foreach ($t['columns'] ?? [] as $c) {
            if (($c['show'] ?? true) === false || $c === $title || $c === $image || $c === $badge || $c === $price) continue;
            $v = fmt($c, $r[$c['name']] ?? null);
            if ($v !== '' && count($details) < 3) $details[] = e($c['label'] ?? $c['name']) . ': ' . e($v);
        }
        $url = $image ? (string)($r[$image['name']] ?? '') : '';
        $thumb = art_inner($t['name'] . $r['id'], $t['icon'] ?? 'list') . (preg_match('#^https?://#', $url) ? '<img src="' . e($url) . '" alt="">' : '');
        $hue = (crc32($t['name'] . $r['id'] . 'h') % 50) - 25;
        $h .= '<a class="card row tap" style="text-decoration:none;color:inherit" href="?p=row&t=' . rawurlencode($t['name']) . '&id=' . rawurlencode((string)$r['id']) . '"><div class="thumb art" style="--hue:' . $hue . 'deg">' . $thumb .
            '</div><div class="grow"><div class="title">' . e($title ? fmt($title, $r[$title['name']] ?? null) : $t['label']) . '</div>' .
            ($details ? '<div class="sub">' . implode('  •  ', $details) . '</div>' : '') . '<div class="meta">' .
            ($badge && !empty($r[$badge['name']]) ? '<span class="pill ' . pill_class((string)$r[$badge['name']]) . '">' . e($r[$badge['name']]) . '</span>' : '') .
            ($price && isset($r[$price['name']]) ? '<span class="price">' . e(fmt($price, $r[$price['name']])) . '</span>' : '') . '</div></div></a>';
    }
    $h .= '</div>';
    $canAdd = $B->isAdmin || in_array($t['owner'] ?? 'customer', ['customer', 'public'], true);
    if ($canAdd) $h .= '<a class="fab" style="text-decoration:none" href="?p=form&t=' . rawurlencode($t['name']) . '">' . icon('plus', 18) . ' إضافة</a>';
    return $h;
}

function row_page(Backend $B, array $t, array $row): string
{
    $image = col_of($t, 'image');
    $url = $image ? (string)($row[$image['name']] ?? '') : '';
    $h = '<div class="wrap">' . (preg_match('#^https?://#', $url) ? '<img src="' . e($url) . '" style="width:100%;max-height:220px;object-fit:cover;border-radius:18px">' : '') . '<div class="card">';
    foreach ($t['columns'] ?? [] as $c) {
        $v = fmt($c, $row[$c['name']] ?? null);
        if ($v === '' || ($c['type'] ?? '') === 'image') continue;
        $h .= '<div class="kv"><span>' . e($c['label'] ?? $c['name']) . '</span><span>' . nl2br(e($v)) . '</span></div>';
    }
    $h .= '</div>';
    if ($B->isAdmin) {
        foreach ($t['columns'] ?? [] as $c) {
            if (($c['type'] ?? '') !== 'choice' || empty($c['adminOnly'])) continue;
            $h .= '<div class="section" style="font-size:15px">تغيير ' . e($c['label'] ?? '') . '</div><div class="chips" style="flex-wrap:wrap">';
            foreach ($c['options'] ?? [] as $o) {
                $h .= post_button('set', e($o), 'chip' . (($row[$c['name']] ?? null) === $o ? ' on' : ''), ['table' => $t['name'], 'id' => $row['id'], 'col' => $c['name'], 'value' => $o,
                    'back' => '?p=row&t=' . $t['name'] . '&id=' . $row['id']]);
            }
            $h .= '</div>';
        }
    }
    $canEdit = $B->isAdmin || (in_array($t['owner'] ?? 'customer', ['customer', 'public'], true) && $B->isMine($row));
    if ($canEdit) {
        $h .= '<div class="row" style="margin-top:16px;cursor:default"><a class="btn" style="text-decoration:none" href="?p=form&t=' . rawurlencode($t['name']) . '&id=' . rawurlencode((string)$row['id']) . '">' . icon('edit', 18) . ' تعديل</a>' .
            post_button('delete', icon('trash', 18), 'iconbtn', ['table' => $t['name'], 'id' => $row['id'], 'back' => '?p=table&t=' . $t['name']]) . '</div>';
    }
    return $h . '</div>';
}

function form_page(Backend $B, array $t, ?array $row): string
{
    $h = '<form class="wrap" method="post"><input type="hidden" name="csrf" value="' . e(csrf()) . '"><input type="hidden" name="action" value="save">' .
        '<input type="hidden" name="table" value="' . e($t['name']) . '"><input type="hidden" name="id" value="' . e($row['id'] ?? '') . '">' .
        '<input type="hidden" name="back" value="?p=form&t=' . e($t['name']) . ($row ? '&id=' . e($row['id']) : '') . '">';
    foreach ($t['columns'] ?? [] as $c) {
        if (!empty($c['adminOnly']) && !$B->isAdmin) continue;
        $name = 'f_' . $c['name'];
        $v = $row[$c['name']] ?? ($row ? null : ($c['default'] ?? null));
        if (($c['type'] ?? '') === 'date' && in_array($v, ['today', 'now'], true)) $v = date('Y-m-d');
        $label = '<label class="lbl">' . e($c['label'] ?? $c['name']) . (!empty($c['required']) ? ' *' : '') . '</label>';
        $req = !empty($c['required']) ? ' required' : '';
        $h .= match ($c['type'] ?? 'text') {
            'bool' => '<label class="switch"><span>' . e($c['label'] ?? '') . '</span><input type="checkbox" name="' . $name . '"' . (in_array($v, [true, 1, '1', 'true'], true) ? ' checked' : '') . '></label>',
            'choice' => $label . '<select class="input" name="' . $name . '"' . $req . '><option value="">اختر</option>' .
                implode('', array_map(fn($o) => '<option' . ($v === $o ? ' selected' : '') . '>' . e($o) . '</option>', $c['options'] ?? [])) . '</select>',
            'longtext' => $label . '<textarea class="input" name="' . $name . '"' . $req . '>' . e($v) . '</textarea>',
            'date' => $label . '<input class="input" type="date" name="' . $name . '" value="' . e($v ? substr((string)$v, 0, 10) : '') . '"' . $req . '>',
            'datetime' => $label . '<input class="input" type="datetime-local" name="' . $name . '" value="' . e($v && ($ts = strtotime((string)$v)) ? date('Y-m-d\TH:i', $ts) : '') . '"' . $req . '>',
            default => $label . '<input class="input' . (in_array($c['type'] ?? '', ['int', 'decimal', 'phone', 'email', 'image'], true) ? ' ltr' : '') . '" name="' . $name . '" value="' . e($v) . '"' .
                ' type="' . (['int' => 'number', 'decimal' => 'number', 'phone' => 'tel', 'email' => 'email', 'image' => 'url'][$c['type'] ?? ''] ?? 'text') . '"' .
                (($c['type'] ?? '') === 'decimal' ? ' step="any"' : '') . $req . '>',
        };
    }
    return $h . '<button class="btn">' . ($row ? 'حفظ التعديل' : 'إضافة') . '</button></form>';
}

function notes_page(Backend $B, array $items): string
{
    $h = '<div class="wrap">';
    if (!$items) $h .= '<div class="empty"><span class="big">' . icon('bell', 46) . '</span>لا توجد إشعارات بعد</div>';
    foreach ($items as $n) {
        $h .= '<div class="card row" style="cursor:default"><div class="thumb" style="width:44px;height:44px">' . icon('bell') . '</div><div class="grow"><div class="title"' . ($n['read'] ? ' style="font-weight:600"' : '') . '>' .
            e($n['title']) . '</div>' . ($n['body'] !== '' ? '<div class="sub">' . e($n['body']) . '</div>' : '') . '<div class="sub">' . date('Y/m/d H:i', (int)$n['at']) . '</div></div></div>';
    }
    $h .= '<form class="card" method="post"><input type="hidden" name="csrf" value="' . e(csrf()) . '"><input type="hidden" name="action" value="notify"><input type="hidden" name="back" value="?p=notes">' .
        '<div class="section" style="margin-top:0">' . ($B->isAdmin ? 'إشعار لكل العملاء' : 'رسالة للإدارة') . '</div>' .
        '<input class="input" name="title" placeholder="العنوان" required><textarea class="input" name="body" placeholder="النص"></textarea><button class="btn">' . icon('send', 18) . ' إرسال</button></form>';
    return $h . '</div>';
}

function me_page(array $C, Backend $B): string
{
    $label = $B->name ?: ($B->email ? explode('@', $B->email)[0] : 'مستخدم');
    $h = '<div class="wrap"><div class="card row" style="cursor:default"><div class="avatar">' . e(mb_strtoupper(mb_substr($label, 0, 1))) . '</div><div class="grow"><div class="title">' . e($label) . '</div>' .
        ($B->email ? '<div class="sub">' . e($B->email) . '</div>' : '') . '<div class="meta"><span class="pill">' . ($B->isAdmin ? 'مدير' : 'عميل') . '</span></div></div></div>' .
        '<div class="card"><div class="kv"><span>التطبيق</span><span>' . e($C['app']['title'] ?? '') . '</span></div><div class="kv"><span>البيانات</span><span>' .
        ($B->kind === 'supabase' ? 'Supabase' : 'قاعدة SQLite على السيرفر') . '</span></div></div>';
    if ($B->needsAccount) $h .= post_button('logout', icon('logout', 18) . ' تسجيل الخروج', 'btn ghost');
    return $h . '<p class="empty" style="padding:24px">صُنع بواسطة Alpha</p></div>';
}
