<?php
// Made with Alpha (PHP). Screens, data and rules come from config.php (the app's design in Alpha).
declare(strict_types=1);

session_set_cookie_params(['lifetime' => 60 * 60 * 24 * 60, 'httponly' => true, 'samesite' => 'Lax']);
session_start();
require __DIR__ . '/lib/backend.php';
require __DIR__ . '/lib/view.php';

$C = require __DIR__ . '/config.php';
$B = Backend::create($C);
$page = $_GET['p'] ?? 'home';
$tables = $C['tables'] ?? [];
$tableByName = [];
foreach ($tables as $t) $tableByName[$t['name']] = $t;

function csrf(): string
{
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}

function redirect(string $to, ?string $flash = null, bool $bad = false): never
{
    if ($flash !== null) $_SESSION['flash'] = ['text' => $flash, 'bad' => $bad];
    header('Location: ' . $to);
    exit;
}

try {
    $B->init();
} catch (Throwable $e) {
    render_error($C, $e->getMessage());
    exit;
}

// ---------- actions ----------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hash_equals(csrf(), (string)($_POST['csrf'] ?? ''))) redirect('?', 'انتهت الجلسة، أعد المحاولة.', true);
    $action = (string)($_POST['action'] ?? '');
    $back = (string)($_POST['back'] ?? '?');
    try {
        switch ($action) {
            case 'login':
                $B->signIn((string)$_POST['email'], (string)$_POST['password']);
                redirect('?');
            case 'signup':
                $B->signUp((string)($_POST['name'] ?? ''), (string)$_POST['email'], (string)$_POST['password']);
                redirect('?');
            case 'logout':
                $B->signOut();
                redirect('?');
            case 'save':
                $t = $tableByName[(string)$_POST['table']] ?? throw new BackendError('جدول غير موجود');
                $values = [];
                foreach ($t['columns'] ?? [] as $c) {
                    if (!empty($c['adminOnly']) && !$B->isAdmin) continue;
                    $v = ($c['type'] ?? '') === 'bool' ? (isset($_POST['f_' . $c['name']]) ? 'true' : 'false') : (string)($_POST['f_' . $c['name']] ?? '');
                    if (!empty($c['required']) && trim($v) === '') throw new BackendError('«' . ($c['label'] ?? $c['name']) . '» مطلوب');
                    if (($c['type'] ?? '') === 'datetime' && $v !== '') $v = gmdate('c', strtotime($v) ?: time());
                    $values[$c['name']] = $v;
                }
                $id = (string)($_POST['id'] ?? '');
                $id === '' ? $B->insert($t, $values) : $B->update($t, $id, $values);
                redirect('?p=table&t=' . rawurlencode($t['name']), $id === '' ? 'تمت الإضافة ✓' : 'تم الحفظ ✓');
            case 'set':
                $t = $tableByName[(string)$_POST['table']] ?? throw new BackendError('جدول غير موجود');
                $B->update($t, (string)$_POST['id'], [(string)$_POST['col'] => (string)$_POST['value']]);
                redirect('?p=table&t=' . rawurlencode($t['name']), 'تم التحديث ✓');
            case 'delete':
                $t = $tableByName[(string)$_POST['table']] ?? throw new BackendError('جدول غير موجود');
                $B->delete($t, (string)$_POST['id']);
                redirect('?p=table&t=' . rawurlencode($t['name']), 'تم الحذف');
            case 'notify':
                $title = trim((string)($_POST['title'] ?? ''));
                if ($title === '') throw new BackendError('اكتب العنوان');
                $B->notify($B->isAdmin ? 'customer' : 'admin', $title, trim((string)($_POST['body'] ?? '')));
                redirect('?p=notes', 'تم الإرسال ✓');
        }
    } catch (BackendError $e) {
        redirect($back, $e->getMessage(), true);
    }
    redirect('?');
}

// ---------- pages ----------
if (!$B->signedIn) {
    render_login($C, $B, ($_GET['mode'] ?? '') === 'signup');
    exit;
}
if ($B->role === 'admin' && !$B->isAdmin) {
    render_layout($C, $B, 'home', '', '<div class="wrap"><div class="empty"><span class="big">' . icon('lock', 46) . '</span>الحساب ' . e($B->email ?? '') .
        ' ليس مديراً.<br>أضف بريده كمدير في Alpha.<br><br>' . post_button('logout', 'تسجيل الخروج', 'btn sm') . '</div></div>', false);
    exit;
}

$visible = array_values(array_filter($tables, fn($t) => ($t['owner'] ?? '') !== 'admin' || $B->isAdmin || $B->role === 'admin'));
switch ($page) {
    case 'table':
        $t = $tableByName[$_GET['t'] ?? ''] ?? null;
        if (!$t) redirect('?');
        render_layout($C, $B, 'table:' . $t['name'], $t['label'] ?? $t['name'], table_page($B, $t, (string)($_GET['q'] ?? ''), $_GET['f'] ?? null));
        break;
    case 'row':
        $t = $tableByName[$_GET['t'] ?? ''] ?? null;
        $row = $t ? $B->get($t, (string)($_GET['id'] ?? '')) : null;
        if (!$row) redirect('?', 'غير موجود', true);
        render_layout($C, $B, 'table:' . $t['name'], $t['label'] ?? '', row_page($B, $t, $row));
        break;
    case 'form':
        $t = $tableByName[$_GET['t'] ?? ''] ?? null;
        if (!$t) redirect('?');
        $row = !empty($_GET['id']) ? $B->get($t, (string)$_GET['id']) : null;
        render_layout($C, $B, 'table:' . $t['name'], ($row ? 'تعديل ' : 'إضافة إلى ') . ($t['label'] ?? ''), form_page($B, $t, $row));
        break;
    case 'notes':
        $items = $B->notifications();
        $B->markSeen();
        render_layout($C, $B, 'notes', 'الإشعارات', notes_page($B, $items));
        break;
    case 'me':
        render_layout($C, $B, 'me', 'حسابي', me_page($C, $B));
        break;
    default:
        $stats = [];
        if ($B->isAdmin) {
            try {
                $stats = $B->stats();
            } catch (BackendError) {
            }
        }
        render_layout($C, $B, 'home', '', home_page($C, $B, $visible, $stats));
}
