<?php
// Alpha PHP engine: data backends. Same API as the other engines.
//   SqliteBackend: the database is a SQLite file on this server (accounts, roles and owners enforced here).
//   SupabaseBackend: Supabase REST; the row level security made by Alpha enforces the rules.
declare(strict_types=1);

final class BackendError extends RuntimeException {}

/** Sign-in refused because the email is not confirmed yet: the app shows the code screen. */
final class NeedsConfirmation extends RuntimeException {}

abstract class Backend
{
    public array $config;
    public string $role;
    public string $prefix;
    public bool $needsAccount;
    public bool $emailCode = false;
    public bool $signedIn = false;
    public bool $isAdmin = false;
    public ?string $userId = null;
    public ?string $email = null;
    public ?string $name = null;
    public string $kind = 'none';

    public function __construct(array $config)
    {
        $this->config = $config;
        $this->role = $config['app']['role'] ?? 'single';
        $be = $config['backend'] ?? [];
        $this->prefix = $be['prefix'] ?? str_replace('-', '_', (string)($config['app']['slug'] ?? 'app'));
        $this->needsAccount = in_array($be['auth'] ?? 'none', ['email_password', 'email_code'], true);
        $this->emailCode = ($be['auth'] ?? 'none') === 'email_code';
    }

    abstract public function init(): void;
    abstract public function signIn(string $email, string $password): void;
    /** Makes the account; true when the email must be confirmed with the 6-digit code first. */
    abstract public function signUp(string $name, string $phone, string $email, string $password): bool;

    public function verifyCode(string $email, string $code, string $password): void
    {
    }

    public function resendCode(string $email): void
    {
    }
    abstract public function signOut(): void;
    abstract public function list(array $table): array;
    abstract public function get(array $table, string $id): ?array;
    abstract public function insert(array $table, array $values): void;
    abstract public function update(array $table, string $id, array $values): void;
    abstract public function delete(array $table, string $id): void;
    abstract public function notifications(): array;
    abstract public function notify(string $toRole, string $title, string $body, ?string $toUser = null): void;
    abstract public function stats(): array;

    public function isMine(array $row): bool
    {
        return empty($row['customer_id']) || $row['customer_id'] === $this->userId;
    }

    public function markSeen(): void
    {
        $_SESSION['alpha_seen'] = gmdate('c');
    }

    protected function seenAt(): int
    {
        return strtotime($_SESSION['alpha_seen'] ?? '2000-01-01T00:00:00Z') ?: 0;
    }

    /** Values ready to save: empty fields removed, numbers typed, admin-only fields kept for admins only. */
    public function clean(array $table, array $values): array
    {
        $out = [];
        foreach ($table['columns'] ?? [] as $c) {
            $name = $c['name'];
            if (!array_key_exists($name, $values)) continue;
            if (!empty($c['adminOnly']) && !$this->isAdmin) continue;
            $v = $values[$name];
            if (is_string($v)) {
                $v = trim($v);
                if ($v === '') $v = null;
                elseif (($c['type'] ?? '') === 'int' && is_numeric(str_replace(',', '', $v))) $v = (int)str_replace(',', '', $v);
                elseif (($c['type'] ?? '') === 'decimal' && is_numeric(str_replace(',', '', $v))) $v = (float)str_replace(',', '', $v);
                elseif (($c['type'] ?? '') === 'bool') $v = in_array($v, ['1', 'true', 'on'], true);
            }
            $out[$name] = $v;
        }
        return $out;
    }

    public function defaults(array $table): array
    {
        $out = [];
        foreach ($table['columns'] ?? [] as $c) {
            $d = $c['default'] ?? null;
            if ($d === null || $d === '' || (!empty($c['adminOnly']) && !$this->isAdmin)) continue;
            $t = $c['type'] ?? 'text';
            $out[$c['name']] = match (true) {
                $t === 'int' => (int)$d,
                $t === 'decimal' => (float)$d,
                $t === 'bool' => $d === 'true',
                $t === 'date' && in_array($d, ['today', 'now'], true) => date('Y-m-d'),
                $t === 'datetime' && $d === 'now' => gmdate('c'),
                default => $d,
            };
        }
        return $out;
    }

    public static function create(array $config): Backend
    {
        return (($config['backend']['type'] ?? 'none') === 'supabase') ? new SupabaseBackend($config) : new SqliteBackend($config);
    }
}

final class SqliteBackend extends Backend
{
    public string $kind = 'none';
    private PDO $db;

    public function init(): void
    {
        $dir = getenv('ALPHA_DATA_DIR') ?: __DIR__ . '/../data';
        if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
            throw new BackendError('لا يمكن إنشاء مجلد البيانات على السيرفر.');
        }
        $this->db = new PDO('sqlite:' . $dir . '/app.sqlite', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $this->db->exec('PRAGMA journal_mode=WAL');
        $this->db->exec('create table if not exists users (id text primary key, email text unique, name text, password text, role text not null default \'customer\', created_at text)');
        if (!in_array('phone', array_column($this->db->query('pragma table_info(users)')->fetchAll(PDO::FETCH_ASSOC), 'name'), true)) {
            $this->db->exec('alter table users add column phone text');
        }
        $this->db->exec('create table if not exists notifications (id integer primary key autoincrement, to_user text, to_role text, title text, body text, created_by text, created_at text)');
        foreach ($this->config['tables'] ?? [] as $t) $this->ensureTable($t);

        if (!empty($_SESSION['alpha_uid'])) {
            $u = $this->user((string)$_SESSION['alpha_uid']);
            if ($u) $this->useUser($u);
        }
        if (!$this->signedIn && !$this->needsAccount) {
            $id = bin2hex(random_bytes(16));
            $this->db->prepare('insert into users (id, role, created_at) values (?, ?, ?)')->execute([$id, 'customer', gmdate('c')]);
            $_SESSION['alpha_uid'] = $id;
            $this->useUser($this->user($id));
        }
    }

    private function ensureTable(array $t): void
    {
        $name = $this->tn($t);
        $this->db->exec("create table if not exists \"$name\" (id text primary key, created_at text, updated_at text, customer_id text)");
        $have = array_column($this->db->query("pragma table_info(\"$name\")")->fetchAll(PDO::FETCH_ASSOC), 'name');
        foreach ($t['columns'] ?? [] as $c) {
            if (!preg_match('/^[a-z][a-z0-9_]*$/', $c['name']) || in_array($c['name'], $have, true)) continue;
            $type = in_array($c['type'] ?? '', ['int', 'bool'], true) ? 'integer' : (($c['type'] ?? '') === 'decimal' ? 'real' : 'text');
            $this->db->exec("alter table \"$name\" add column \"{$c['name']}\" $type");
        }
    }

    private function tn(array $t): string
    {
        if (!preg_match('/^[a-z][a-z0-9_]*$/', (string)$t['name'])) throw new BackendError('اسم جدول غير صالح');
        return $this->prefix . '_' . $t['name'];
    }

    private function user(string $id): ?array
    {
        $s = $this->db->prepare('select * from users where id = ?');
        $s->execute([$id]);
        return $s->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    private function admins(): array
    {
        return array_map('strtolower', $this->config['backend']['admins'] ?? []);
    }

    private function useUser(array $u): void
    {
        $this->signedIn = true;
        $this->userId = $u['id'];
        $this->email = $u['email'] ?: null;
        $this->name = $u['name'] ?: null;
        $admin = $u['role'] === 'admin' || ($u['email'] && in_array(strtolower($u['email']), $this->admins(), true));
        // A single app on a server without accounts: its owner manages everything.
        if ($this->role === 'single' && !$this->needsAccount) $admin = true;
        $this->isAdmin = $this->role !== 'customer' && $admin;
    }

    public function signIn(string $email, string $password): void
    {
        $s = $this->db->prepare('select * from users where email = ?');
        $s->execute([strtolower(trim($email))]);
        $u = $s->fetch(PDO::FETCH_ASSOC);
        if (!$u || !password_verify($password, (string)$u['password'])) throw new BackendError('البريد أو كلمة المرور غير صحيحة.');
        session_regenerate_id(true);
        $_SESSION['alpha_uid'] = $u['id'];
        $this->useUser($u);
    }

    public function signUp(string $name, string $phone, string $email, string $password): bool
    {
        $email = strtolower(trim($email));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) throw new BackendError('بريد غير صحيح');
        if (strlen($password) < 6) throw new BackendError('كلمة المرور قصيرة (6 أحرف على الأقل).');
        $s = $this->db->prepare('select 1 from users where email = ?');
        $s->execute([$email]);
        if ($s->fetchColumn()) throw new BackendError('هذا البريد مسجّل من قبل، سجّل الدخول.');
        $id = bin2hex(random_bytes(16));
        $role = in_array($email, $this->admins(), true) ? 'admin' : 'customer';
        $this->db->prepare('insert into users (id, email, name, phone, password, role, created_at) values (?, ?, ?, ?, ?, ?, ?)')
            ->execute([$id, $email, trim($name), trim($phone), password_hash($password, PASSWORD_DEFAULT), $role, gmdate('c')]);
        session_regenerate_id(true);
        $_SESSION['alpha_uid'] = $id;
        $this->useUser($this->user($id));
        return false;
    }

    public function signOut(): void
    {
        unset($_SESSION['alpha_uid']);
        $this->signedIn = $this->isAdmin = false;
        $this->userId = $this->email = $this->name = null;
    }

    private function canRead(array $t, array $row): bool
    {
        if ($this->isAdmin || in_array($t['owner'] ?? 'customer', ['catalog', 'public'], true)) return true;
        return ($t['owner'] ?? 'customer') === 'customer' && $row['customer_id'] === $this->userId;
    }

    private function canWrite(array $t, ?array $row): bool
    {
        if ($this->isAdmin) return true;
        $owner = $t['owner'] ?? 'customer';
        if (!in_array($owner, ['customer', 'public'], true)) return false;
        return $row === null || $row['customer_id'] === $this->userId;
    }

    public function list(array $table): array
    {
        if (($table['owner'] ?? '') === 'admin' && !$this->isAdmin) return [];
        $rows = $this->db->query('select * from "' . $this->tn($table) . '" order by created_at desc limit 500')->fetchAll(PDO::FETCH_ASSOC);
        return array_values(array_filter($rows, fn($r) => $this->canRead($table, $r)));
    }

    public function get(array $table, string $id): ?array
    {
        $s = $this->db->prepare('select * from "' . $this->tn($table) . '" where id = ?');
        $s->execute([$id]);
        $row = $s->fetch(PDO::FETCH_ASSOC) ?: null;
        return $row && $this->canRead($table, $row) ? $row : null;
    }

    public function insert(array $table, array $values): void
    {
        if (!$this->canWrite($table, null)) throw new BackendError('ليست لديك صلاحية لهذه العملية.');
        $now = gmdate('c');
        $row = array_merge($this->defaults($table), $this->clean($table, $values),
            ['id' => bin2hex(random_bytes(16)), 'created_at' => $now, 'updated_at' => $now, 'customer_id' => $this->userId]);
        $cols = array_keys($row);
        $sql = 'insert into "' . $this->tn($table) . '" (' . implode(',', array_map(fn($c) => "\"$c\"", $cols)) . ') values (' .
            implode(',', array_fill(0, count($cols), '?')) . ')';
        $this->db->prepare($sql)->execute(array_map(fn($v) => is_bool($v) ? (int)$v : $v, array_values($row)));
        $this->afterChange($table, $row, true);
    }

    public function update(array $table, string $id, array $values): void
    {
        $row = $this->get($table, $id);
        if (!$row || !$this->canWrite($table, $row)) throw new BackendError('ليست لديك صلاحية لهذه العملية.');
        $data = $this->clean($table, $values) + ['updated_at' => gmdate('c')];
        $sql = 'update "' . $this->tn($table) . '" set ' . implode(',', array_map(fn($c) => "\"$c\" = ?", array_keys($data))) . ' where id = ?';
        $this->db->prepare($sql)->execute([...array_map(fn($v) => is_bool($v) ? (int)$v : $v, array_values($data)), $id]);
        $this->afterChange($table, array_merge($row, $data), false);
    }

    public function delete(array $table, string $id): void
    {
        $row = $this->get($table, $id);
        if (!$row || !$this->canWrite($table, $row)) throw new BackendError('ليست لديك صلاحية لهذه العملية.');
        $this->db->prepare('delete from "' . $this->tn($table) . '" where id = ?')->execute([$id]);
    }

    private function afterChange(array $t, array $row, bool $inserted): void
    {
        $target = $inserted ? ($t['notify']['onInsert'] ?? 'none') : ($t['notify']['onUpdate'] ?? 'none');
        $title = ($t['label'] ?? $t['name']) . ': ' . ($inserted ? 'جديد' : 'تحديث');
        $parts = [];
        foreach ($t['columns'] ?? [] as $c) {
            if ((in_array($c['type'] ?? '', ['text', 'choice'], true) && !$parts) || !empty($c['adminOnly'])) {
                if (isset($row[$c['name']]) && $row[$c['name']] !== '') $parts[] = (string)$row[$c['name']];
            }
        }
        $body = implode(' · ', $parts);
        if ($target === 'admin') $this->notify('admin', $title, $body);
        elseif ($target === 'customer' && $this->isAdmin) $this->notify('customer', $title, $body);
        elseif ($target === 'owner' && !empty($row['customer_id']) && $row['customer_id'] !== $this->userId) $this->notify('customer', $title, $body, $row['customer_id']);
    }

    public function notifications(): array
    {
        $roles = match ($this->role) { 'customer' => ['customer'], 'admin' => ['admin'], default => $this->isAdmin ? ['customer', 'admin'] : ['customer'] };
        $in = implode(',', array_fill(0, count($roles), '?'));
        $s = $this->db->prepare("select * from notifications where to_user = ? or (to_user is null and to_role in ($in)) order by id desc limit 60");
        $s->execute([$this->userId, ...$roles]);
        $seen = $this->seenAt();
        return array_map(fn($r) => ['title' => $r['title'], 'body' => $r['body'], 'at' => strtotime($r['created_at']), 'read' => strtotime($r['created_at']) <= $seen],
            $s->fetchAll(PDO::FETCH_ASSOC));
    }

    public function notify(string $toRole, string $title, string $body, ?string $toUser = null): void
    {
        $this->db->prepare('insert into notifications (to_user, to_role, title, body, created_by, created_at) values (?, ?, ?, ?, ?, ?)')
            ->execute([$toUser, $toUser ? null : $toRole, $title, $body, $this->userId, gmdate('c')]);
    }

    public function stats(): array
    {
        $out = [];
        foreach ($this->config['tables'] ?? [] as $t) $out[$t['name']] = (int)$this->db->query('select count(*) from "' . $this->tn($t) . '"')->fetchColumn();
        $out['_customers'] = (int)$this->db->query("select count(*) from users where role = 'customer' and email is not null")->fetchColumn();
        return $out;
    }
}

final class SupabaseBackend extends Backend
{
    public string $kind = 'supabase';
    private string $url;
    private string $key;

    public function __construct(array $config)
    {
        parent::__construct($config);
        $this->url = rtrim((string)($config['backend']['url'] ?? ''), '/');
        $this->key = (string)($config['backend']['anonKey'] ?? '');
    }

    private function explain(int $code, string $body): string
    {
        $j = json_decode($body, true);
        $msg = is_array($j) ? ($j['msg'] ?? $j['message'] ?? $j['error_description'] ?? $j['error'] ?? $body) : $body;
        $m = strtolower((string)$msg);
        if (str_contains($m, 'email not confirmed')) return 'EMAIL_NOT_CONFIRMED';
        if (str_contains($m, 'invalid login')) return 'البريد أو كلمة المرور غير صحيحة.';
        if (str_contains($m, 'already registered') || str_contains($m, 'already been registered')) return 'هذا البريد مسجّل من قبل، سجّل الدخول.';
        if (str_contains($m, 'password should be')) return 'كلمة المرور قصيرة (6 أحرف على الأقل).';
        if (str_contains($m, 'row-level security') || $code === 403) return 'ليست لديك صلاحية لهذه العملية.';
        return "خطأ من السيرفر ($code): $msg";
    }

    private function call(string $method, string $path, ?array $body = null, array $headers = [], bool $refresh = true): mixed
    {
        if ($refresh) $this->refresh(false);
        $token = $_SESSION['alpha_session']['access_token'] ?? $this->key;
        $ch = curl_init($this->url . $path);
        $h = array_merge(['apikey: ' . $this->key, 'Authorization: Bearer ' . $token, 'Content-Type: application/json'], $headers);
        curl_setopt_array($ch, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => $h, CURLOPT_TIMEOUT => 30]);
        if ($body !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body ?: new stdClass(), JSON_UNESCAPED_UNICODE));
        $text = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        if ($text === false) throw new BackendError('لا يوجد اتصال بالسيرفر.');
        if ($code >= 300) throw new BackendError($this->explain($code, (string)$text));
        return $text === '' ? null : json_decode((string)$text, true);
    }

    private function save(array $s): void
    {
        $s['expires_at'] = time() + (int)($s['expires_in'] ?? 3600);
        $_SESSION['alpha_session'] = $s;
        $this->signedIn = true;
        $this->userId = $s['user']['id'] ?? null;
        $this->email = ($s['user']['email'] ?? '') ?: null;
    }

    private function refresh(bool $force): void
    {
        $s = $_SESSION['alpha_session'] ?? null;
        if (!$s || (!$force && ($s['expires_at'] ?? 0) - time() > 60)) return;
        $this->save($this->call('POST', '/auth/v1/token?grant_type=refresh_token', ['refresh_token' => $s['refresh_token'] ?? ''], [], false));
    }

    private function profile(): void
    {
        $role = 'customer';
        try {
            $rows = $this->call('GET', "/rest/v1/{$this->prefix}_profiles?select=role,full_name&id=eq.{$this->userId}");
            if ($rows) {
                $role = $rows[0]['role'] ?? 'customer';
                $this->name = $rows[0]['full_name'] ?? null;
            }
        } catch (BackendError) {
        }
        $this->isAdmin = $this->role !== 'customer' && $role === 'admin';
    }

    public function init(): void
    {
        if ($this->url === '' || $this->key === '') throw new BackendError('السيرفر لم يُجهّز بعد. افتح Alpha واضغط «تجهيز السيرفر».');
        if (!empty($_SESSION['alpha_session'])) {
            try {
                $this->save($_SESSION['alpha_session']);
                $this->refresh(false);
            } catch (BackendError) {
                unset($_SESSION['alpha_session']);
                $this->signedIn = false;
            }
        }
        if (!$this->signedIn && !$this->needsAccount) $this->save($this->call('POST', '/auth/v1/signup', [], [], false));
        if ($this->signedIn) $this->profile();
    }

    public function signIn(string $email, string $password): void
    {
        try {
            $this->save($this->call('POST', '/auth/v1/token?grant_type=password', ['email' => trim($email), 'password' => $password], [], false));
        } catch (BackendError $e) {
            if ($e->getMessage() === 'EMAIL_NOT_CONFIRMED') throw new NeedsConfirmation('أكّد بريدك أولاً بالرمز الذي وصلك.');
            throw $e;
        }
        session_regenerate_id(true);
        $this->profile();
    }

    public function signUp(string $name, string $phone, string $email, string $password): bool
    {
        $s = $this->call('POST', '/auth/v1/signup', ['email' => trim($email), 'password' => $password,
            'data' => ['full_name' => trim($name), 'phone' => trim($phone)]], [], false);
        if (empty($s['access_token'])) {
            if ($this->emailCode) return true;
            $this->signIn($email, $password);
            return false;
        }
        $this->save($s);
        $this->profile();
        return false;
    }

    public function verifyCode(string $email, string $code, string $password): void
    {
        try {
            $s = $this->call('POST', '/auth/v1/verify', ['type' => 'signup', 'email' => trim($email), 'token' => trim($code)], [], false);
        } catch (BackendError) {
            throw new BackendError('الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً.');
        }
        if (!empty($s['access_token'])) {
            $this->save($s);
            session_regenerate_id(true);
            $this->profile();
        } else {
            $this->signIn($email, $password);
        }
    }

    public function resendCode(string $email): void
    {
        $this->call('POST', '/auth/v1/resend', ['type' => 'signup', 'email' => trim($email)], [], false);
    }

    public function signOut(): void
    {
        try {
            $this->call('POST', '/auth/v1/logout', []);
        } catch (BackendError) {
        }
        unset($_SESSION['alpha_session']);
        $this->signedIn = $this->isAdmin = false;
        $this->userId = $this->email = $this->name = null;
    }

    private function tn(array $t): string
    {
        return $this->prefix . '_' . $t['name'];
    }

    public function list(array $table): array
    {
        $q = '/rest/v1/' . $this->tn($table) . '?select=*&order=created_at.desc&limit=500';
        if (($table['owner'] ?? '') === 'customer' && !$this->isAdmin) $q .= '&customer_id=eq.' . $this->userId;
        return $this->call('GET', $q) ?? [];
    }

    public function get(array $table, string $id): ?array
    {
        $rows = $this->call('GET', '/rest/v1/' . $this->tn($table) . '?select=*&id=eq.' . rawurlencode($id));
        return $rows[0] ?? null;
    }

    public function insert(array $table, array $values): void
    {
        $this->call('POST', '/rest/v1/' . $this->tn($table), $this->clean($table, $values), ['Prefer: return=minimal']);
    }

    public function update(array $table, string $id, array $values): void
    {
        $this->call('PATCH', '/rest/v1/' . $this->tn($table) . '?id=eq.' . rawurlencode($id), $this->clean($table, $values), ['Prefer: return=minimal']);
    }

    public function delete(array $table, string $id): void
    {
        $this->call('DELETE', '/rest/v1/' . $this->tn($table) . '?id=eq.' . rawurlencode($id));
    }

    public function notifications(): array
    {
        $roles = match ($this->role) { 'customer' => ['customer'], 'admin' => ['admin'], default => $this->isAdmin ? ['customer', 'admin'] : ['customer'] };
        $or = implode(',', array_merge(["to_user.eq.{$this->userId}"], array_map(fn($r) => "to_role.eq.$r", $roles)));
        $rows = $this->call('GET', "/rest/v1/{$this->prefix}_notifications?select=*&or=($or)&order=created_at.desc&limit=60") ?? [];
        $seen = $this->seenAt();
        return array_map(fn($r) => ['title' => $r['title'] ?? '', 'body' => $r['body'] ?? '', 'at' => strtotime($r['created_at']), 'read' => strtotime($r['created_at']) <= $seen], $rows);
    }

    public function notify(string $toRole, string $title, string $body, ?string $toUser = null): void
    {
        $target = $toUser ? ['to_user' => $toUser] : ['to_role' => $toRole];
        $this->call('POST', "/rest/v1/{$this->prefix}_notifications", $target + ['title' => $title, 'body' => $body, 'created_by' => $this->userId], ['Prefer: return=minimal']);
    }

    public function stats(): array
    {
        return $this->call('POST', "/rest/v1/rpc/{$this->prefix}_stats", []) ?? [];
    }
}
