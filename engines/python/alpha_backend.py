"""Alpha Python engine: data backends (phone storage or Supabase REST). Same API as the other engines:

    b = create_backend(CONFIG); b.init()
    b.signed_in, b.is_admin, b.user_id, b.email, b.name
    b.sign_in(email, password); b.sign_up(name, email, password); b.sign_out()
    b.list(table); b.insert(table, values); b.update(table, id, values); b.delete(table, id)
    b.notifications(); b.mark_seen(); b.notify(to_role, title, body, to_user=None); b.stats()
"""
import json
import os
import secrets
import time
from datetime import datetime, timezone

import requests

DATA_DIR = os.getenv("FLET_APP_STORAGE_DATA", ".")


class BackendError(Exception):
    pass


class NeedsConfirmation(BackendError):
    """Sign-in refused because the email is not confirmed yet: the app shows the code screen."""


def _now():
    return datetime.now(timezone.utc).isoformat()


def _parse_time(value):
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return datetime(2000, 1, 1, tzinfo=timezone.utc)


class Store:
    """A small JSON file in the app's private folder (survives restarts and updates)."""

    def __init__(self, name="alpha.json"):
        self.path = os.path.join(DATA_DIR, name)
        try:
            with open(self.path, encoding="utf-8") as f:
                self.data = json.load(f)
        except (OSError, ValueError):
            self.data = {}

    def get(self, key, default=None):
        return self.data.get(key, default)

    def set(self, key, value):
        if value is None:
            self.data.pop(key, None)
        else:
            self.data[key] = value
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False)
        os.replace(tmp, self.path)


class Backend:
    kind = "none"

    def __init__(self, config):
        self.config = config
        self.role = config.get("app", {}).get("role", "single")
        be = config.get("backend") or {}
        self.prefix = be.get("prefix") or str(config.get("app", {}).get("slug", "app")).replace("-", "_")
        self.needs_account = be.get("auth") in ("email_password", "email_code")
        self.email_code = be.get("auth") == "email_code"
        self.store = Store()
        self.signed_in = False
        self.is_admin = False
        self.user_id = None
        self.email = None
        self.name = None

    def clean(self, table, values):
        out = {}
        for c in table.get("columns", []):
            name = c["name"]
            if name not in values:
                continue
            if c.get("adminOnly") and not self.is_admin:
                continue
            v = values[name]
            if isinstance(v, str):
                v = v.strip()
                if v == "":
                    v = None
                elif c.get("type") == "int":
                    try:
                        v = int(v.replace(",", ""))
                    except ValueError:
                        pass
                elif c.get("type") == "decimal":
                    try:
                        v = float(v.replace(",", ""))
                    except ValueError:
                        pass
            out[name] = v
        return out

    def defaults(self, table):
        out = {}
        for c in table.get("columns", []):
            d = c.get("default")
            if d in (None, "") or (c.get("adminOnly") and not self.is_admin):
                continue
            t = c.get("type")
            if t == "int":
                out[c["name"]] = int(float(d))
            elif t == "decimal":
                out[c["name"]] = float(d)
            elif t == "bool":
                out[c["name"]] = d == "true"
            elif t == "date" and d in ("today", "now"):
                out[c["name"]] = datetime.now().date().isoformat()
            elif t == "datetime" and d == "now":
                out[c["name"]] = _now()
            else:
                out[c["name"]] = d
        return out

    def is_mine(self, row):
        return not row.get("customer_id") or row.get("customer_id") == self.user_id

    def seen_at(self):
        return _parse_time(self.store.get("alpha_seen", "2000-01-01T00:00:00+00:00"))

    def mark_seen(self):
        self.store.set("alpha_seen", _now())


class LocalBackend(Backend):
    kind = "none"

    def init(self):
        if not self.store.get("alpha_uid"):
            self.store.set("alpha_uid", secrets.token_hex(16))
        self.user_id = self.store.get("alpha_uid")
        self.name = self.store.get("alpha_name")
        self.signed_in = True
        self.is_admin = True

    def _rows(self, table):
        return list(self.store.get("rows_" + table["name"], []))

    def sign_in(self, email, password):
        pass

    def sign_up(self, name, phone, email, password):
        self.store.set("alpha_name", name)
        return False

    def verify_code(self, email, code, password):
        pass

    def resend_code(self, email):
        pass

    def sign_out(self):
        pass

    def list(self, table):
        return sorted(self._rows(table), key=lambda r: str(r.get("created_at")), reverse=True)

    def insert(self, table, values):
        now = _now()
        row = {**self.defaults(table), **self.clean(table, values), "id": secrets.token_hex(16),
               "created_at": now, "updated_at": now, "customer_id": self.user_id}
        self.store.set("rows_" + table["name"], self._rows(table) + [row])
        return row

    def update(self, table, row_id, values):
        rows = [{**r, **self.clean(table, values), "updated_at": _now()} if r.get("id") == row_id else r
                for r in self._rows(table)]
        self.store.set("rows_" + table["name"], rows)

    def delete(self, table, row_id):
        self.store.set("rows_" + table["name"], [r for r in self._rows(table) if r.get("id") != row_id])

    def notifications(self):
        return []

    def notify(self, to_role, title, body, to_user=None):
        pass

    def stats(self):
        return {t["name"]: len(self._rows(t)) for t in self.config.get("tables", [])}


class SupabaseBackend(Backend):
    kind = "supabase"

    def __init__(self, config):
        super().__init__(config)
        be = config.get("backend") or {}
        self.url = str(be.get("url", "")).rstrip("/")
        self.key = be.get("anonKey", "")
        self.session = None
        self.http = requests.Session()

    # ---- helpers ----
    @staticmethod
    def _explain(res):
        msg = res.text
        try:
            j = res.json()
            if isinstance(j, dict):
                msg = j.get("msg") or j.get("message") or j.get("error_description") or j.get("error") or msg
        except ValueError:
            pass
        m = str(msg).lower()
        if "email not confirmed" in m:
            return "EMAIL_NOT_CONFIRMED"
        if "invalid login" in m:
            return "البريد أو كلمة المرور غير صحيحة."
        if "already registered" in m or "already been registered" in m:
            return "هذا البريد مسجّل من قبل، سجّل الدخول."
        if "password should be" in m:
            return "كلمة المرور قصيرة (6 أحرف على الأقل)."
        if "row-level security" in m or res.status_code == 403:
            return "ليست لديك صلاحية لهذه العملية."
        return f"خطأ من السيرفر ({res.status_code}): {msg}"

    def _call(self, method, path, body=None, headers=None, refresh=True):
        if refresh:
            self._refresh()
        token = (self.session or {}).get("access_token") or self.key
        h = {"apikey": self.key, "Authorization": f"Bearer {token}", "Content-Type": "application/json", **(headers or {})}
        try:
            res = self.http.request(method, self.url + path, json=body, headers=h, timeout=30)
        except requests.RequestException:
            raise BackendError("لا يوجد اتصال بالإنترنت.")
        if res.status_code >= 300:
            raise BackendError(self._explain(res))
        return res.json() if res.text.strip() else None

    def _save(self, s):
        s["expires_at"] = time.time() + int(s.get("expires_in") or 3600)
        self.session = s
        self.store.set("alpha_session", s)
        user = s.get("user") or {}
        self.signed_in = True
        self.user_id = user.get("id")
        self.email = user.get("email") or None

    def _refresh(self, force=False):
        s = self.session
        if not s or (not force and s.get("expires_at", 0) - time.time() > 60):
            return
        self._save(self._call("POST", "/auth/v1/token?grant_type=refresh_token",
                              {"refresh_token": s.get("refresh_token")}, refresh=False))

    def _anonymous(self):
        self._save(self._call("POST", "/auth/v1/signup", {}, refresh=False))

    def _profile(self):
        role = "customer"
        try:
            rows = self._call("GET", f"/rest/v1/{self.prefix}_profiles?select=role,full_name&id=eq.{self.user_id}")
            if rows:
                role = rows[0].get("role") or "customer"
                self.name = rows[0].get("full_name")
        except BackendError:
            pass
        self.is_admin = self.role != "customer" and role == "admin"

    # ---- API ----
    def init(self):
        if not self.url or not self.key:
            raise BackendError("السيرفر لم يُجهّز بعد. افتح Alpha واضغط «تجهيز السيرفر» ثم ابنِ التطبيق مرة أخرى.")
        saved = self.store.get("alpha_session")
        if saved:
            try:
                self._save(saved)
                self._refresh(force=True)
            except BackendError:
                self.session = None
                self.signed_in = False
                self.store.set("alpha_session", None)
        if not self.session and not self.needs_account:
            self._anonymous()
        if self.session:
            self._profile()

    def sign_in(self, email, password):
        try:
            self._save(self._call("POST", "/auth/v1/token?grant_type=password",
                                  {"email": email.strip(), "password": password}, refresh=False))
        except BackendError as e:
            if str(e) == "EMAIL_NOT_CONFIRMED":
                raise NeedsConfirmation("أكّد بريدك أولاً بالرمز الذي وصلك.")
            raise
        self._profile()

    def sign_up(self, name, phone, email, password):
        """Makes the account; True when the email must be confirmed with the 6-digit code first."""
        s = self._call("POST", "/auth/v1/signup",
                       {"email": email.strip(), "password": password,
                        "data": {"full_name": name.strip(), "phone": (phone or "").strip()}}, refresh=False)
        if not s.get("access_token"):
            if self.email_code:
                return True
            self.sign_in(email, password)
            return False
        self._save(s)
        self._profile()
        return False

    def verify_code(self, email, code, password):
        try:
            s = self._call("POST", "/auth/v1/verify", {"type": "signup", "email": email.strip(), "token": code.strip()}, refresh=False)
        except BackendError:
            raise BackendError("الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً.")
        if s and s.get("access_token"):
            self._save(s)
            self._profile()
        else:
            self.sign_in(email, password)

    def resend_code(self, email):
        self._call("POST", "/auth/v1/resend", {"type": "signup", "email": email.strip()}, refresh=False)

    def sign_out(self):
        try:
            self._call("POST", "/auth/v1/logout", {})
        except BackendError:
            pass
        self.session = None
        self.store.set("alpha_session", None)
        self.signed_in = self.is_admin = False
        self.user_id = self.email = None
        if not self.needs_account:
            self._anonymous()
            self._profile()

    def _t(self, table):
        return f"{self.prefix}_{table['name']}"

    def list(self, table):
        q = f"/rest/v1/{self._t(table)}?select=*&order=created_at.desc&limit=500"
        if table.get("owner") == "customer" and not self.is_admin:
            q += f"&customer_id=eq.{self.user_id}"
        return self._call("GET", q) or []

    def insert(self, table, values):
        rows = self._call("POST", f"/rest/v1/{self._t(table)}", self.clean(table, values),
                          {"Prefer": "return=representation"})
        return rows[0] if rows else {}

    def update(self, table, row_id, values):
        self._call("PATCH", f"/rest/v1/{self._t(table)}?id=eq.{row_id}", self.clean(table, values),
                   {"Prefer": "return=minimal"})

    def delete(self, table, row_id):
        self._call("DELETE", f"/rest/v1/{self._t(table)}?id=eq.{row_id}")

    def notifications(self):
        if not self.user_id:
            return []
        roles = {"customer": ["customer"], "admin": ["admin"]}.get(self.role) or (["customer"] + (["admin"] if self.is_admin else []))
        cond = ",".join([f"to_user.eq.{self.user_id}"] + [f"to_role.eq.{r}" for r in roles])
        rows = self._call("GET", f"/rest/v1/{self.prefix}_notifications?select=*&or=({cond})&order=created_at.desc&limit=60") or []
        seen = self.seen_at()
        return [{"id": r.get("id"), "title": r.get("title") or "", "body": r.get("body") or "",
                 "at": _parse_time(r.get("created_at")), "read": _parse_time(r.get("created_at")) <= seen} for r in rows]

    def notify(self, to_role, title, body, to_user=None):
        target = {"to_user": to_user} if to_user else {"to_role": to_role}
        self._call("POST", f"/rest/v1/{self.prefix}_notifications",
                   {**target, "title": title, "body": body or "", "created_by": self.user_id}, {"Prefer": "return=minimal"})

    def stats(self):
        return self._call("POST", f"/rest/v1/rpc/{self.prefix}_stats", {}) or {}


def create_backend(config):
    kind = (config.get("backend") or {}).get("type")
    return SupabaseBackend(config) if kind == "supabase" else LocalBackend(config)
