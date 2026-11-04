#!/usr/bin/env python3
"""Sets up the server of one Alpha project and writes the connection into its apps.

    python factory/backend_setup.py <base>

Reads projects/<base>/project.json, schema.sql (Supabase) or firestore.rules (Firebase), all written by Alpha.
Supabase: runs the SQL (tables, roles, row level security, notifications), turns on the sign-in the project
uses, and with push: registers the apps in Firebase, deploys the <prefix>-push Edge Function and its trigger.
Firebase: registers the Android apps, creates Firestore if needed, publishes the security rules, turns on
the sign-in providers, adds the admins, and with push deploys the notification Cloud Function (Blaze plan).
Then apps/<app>/alpha.json gets the URL / keys / Firebase options, so the next build connects by itself.

Env: SUPABASE_ACCESS_TOKEN + SUPABASE_PROJECT_REF, FIREBASE_SERVICE_ACCOUNT (JSON).
"""
import base64
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SB_API = "https://api.supabase.com/v1"


def need(name, why):
    v = os.environ.get(name, "").strip()
    if not v:
        raise SystemExit(f"{name} is missing: {why}. Save it in Alpha > الإعدادات (Alpha stores it as a repository secret).")
    return v


def http(method, url, token, body=None, ok404=False, raw=False):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json", "User-Agent": "alpha"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            text = r.read().decode()
            return text if raw else (json.loads(text) if text.strip() else {})
    except urllib.error.HTTPError as e:
        msg = e.read().decode()[:800]
        if ok404 and e.code == 404:
            return None
        raise RuntimeError(f"{method} {url.split('?')[0]} -> {e.code}: {msg}")


# ---------------- Supabase ----------------

def sb(method, path, token, body=None):
    return http(method, SB_API + path, token, body)


def run_sql(ref, token, sql):
    return sb("POST", f"/projects/{ref}/database/query", token, {"query": sql})


def client_key(ref, token):
    """The key the apps send as `apikey`: the anon key or a publishable key, never a secret one."""
    override = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    if override and not override.startswith("sb_secret_"):
        return override

    def pick(keys):
        keys = [k for k in (keys or []) if isinstance(k, dict) and k.get("api_key")]
        for test in (lambda k: k.get("name") == "anon" and k.get("type") in (None, "legacy"),
                     lambda k: k.get("type") == "publishable",
                     lambda k: str(k.get("api_key", "")).startswith("sb_publishable_")):
            hit = next((k["api_key"] for k in keys if test(k)), None)
            if hit:
                return hit
        return None

    for path in (f"/projects/{ref}/api-keys", f"/projects/{ref}/api-keys?reveal=true"):
        try:
            key = pick(sb("GET", path, token))
            if key:
                return key
        except RuntimeError as e:
            print(f"Reading API keys: {e}")
    created = sb("POST", f"/projects/{ref}/api-keys", token, {"type": "publishable", "name": "alpha", "description": "Alpha apps"})
    key = pick([created]) or pick(sb("GET", f"/projects/{ref}/api-keys", token))
    if not key:
        raise SystemExit("Could not get a publishable/anon key of the Supabase project (check the access token and project ref).")
    return key


def supabase_cli(args, cwd):
    r = subprocess.run(["supabase", *args, "--yes"], cwd=cwd, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 and re.search(r"unknown (flag|shorthand flag).*yes", out):
        r = subprocess.run(["supabase", *args], cwd=cwd, capture_output=True, text=True)
        out = (r.stdout or "") + (r.stderr or "")
    print(out.strip())
    if r.returncode != 0:
        raise SystemExit(f"supabase {' '.join(args[:2])} failed")


def push_sql(p, url, secret):
    url, secret = url.replace("'", "''"), secret.replace("'", "''")
    return f"""
create extension if not exists pg_net;
create table if not exists public.{p}_push_config (id int primary key default 1 check (id = 1), url text not null, secret text not null);
alter table public.{p}_push_config enable row level security;
revoke all on public.{p}_push_config from anon, authenticated;
insert into public.{p}_push_config (id, url, secret) values (1, '{url}', '{secret}')
  on conflict (id) do update set url = excluded.url, secret = excluded.secret;
create or replace function public.{p}_push_notify() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare c record;
begin
  select url, secret into c from public.{p}_push_config where id = 1;
  if c.url is not null then
    perform net.http_post(url := c.url, body := jsonb_build_object('record', to_jsonb(new)),
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', c.secret));
  end if;
  return new;
end $$;
drop trigger if exists {p}_push on public.{p}_notifications;
create trigger {p}_push after insert on public.{p}_notifications for each row execute function public.{p}_push_notify();
"""


def setup_supabase(proj, pdir):
    token = need("SUPABASE_ACCESS_TOKEN", "the Supabase access token (supabase.com > Account > Access Tokens)")
    ref = proj.get("supabaseRef") or need("SUPABASE_PROJECT_REF", "the Supabase project ref")
    p = proj["prefix"]
    sql = (pdir / "schema.sql").read_text(encoding="utf-8")
    print(f"Running the database script of {p} on Supabase project {ref}…")
    try:
        run_sql(ref, token, sql)
    except RuntimeError as e:
        raise SystemExit(f"The database script failed: {e}")
    tables = run_sql(ref, token, f"select table_name from information_schema.tables where table_schema = 'public' and table_name like '{p}\\_%' order by 1")
    print("Tables now: " + ", ".join(t["table_name"] for t in tables or []))

    auth = {"mailer_autoconfirm": True, "external_email_enabled": True}
    if proj.get("auth", "none") == "none":
        auth["external_anonymous_users_enabled"] = True
    try:
        sb("PATCH", f"/projects/{ref}/config/auth", token, auth)
        print("Sign-in configured: " + ("anonymous accounts (one per phone)" if proj.get("auth", "none") == "none" else "email + password"))
    except RuntimeError as e:
        print(f"::warning::Could not change the sign-in settings: {e}")

    url = f"https://{ref}.supabase.co"
    key = client_key(ref, token)
    result = {"type": "supabase", "url": url, "anonKey": key, "ref": ref}

    if proj.get("push"):
        sa_raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
        if not sa_raw:
            print("::warning::Push is on but there is no Firebase service account: notifications stay inside the apps. "
                  "Add it in Alpha > الإعدادات > Firebase and set up the server again.")
        else:
            sa = json.loads(sa_raw)
            result["firebase"] = register_apps(proj, sa)
            deploy_supabase_push(p, ref, token, sa)
    return result


def deploy_supabase_push(p, ref, token, sa):
    fn = f"{p.replace('_', '-')}-push"
    secret = secrets.token_urlsafe(32)
    with tempfile.TemporaryDirectory() as tmp:
        fdir = Path(tmp) / "supabase" / "functions" / fn
        fdir.mkdir(parents=True)
        src = (ROOT / "factory" / "templates" / "push_function.ts").read_text(encoding="utf-8")
        (fdir / "index.ts").write_text(src.replace("__PREFIX__", p), encoding="utf-8")
        sb("POST", f"/projects/{ref}/secrets", token, [{"name": "FIREBASE_SERVICE_ACCOUNT", "value": json.dumps(sa)},
                                                       {"name": f"PUSH_SECRET_{p.upper()}", "value": secret}])
        print(f"Deploying the {fn} Edge Function…")
        supabase_cli(["functions", "deploy", fn, "--project-ref", ref, "--no-verify-jwt", "--use-api"], cwd=tmp)
    run_sql(ref, token, push_sql(p, f"https://{ref}.supabase.co/functions/v1/{fn}", secret))
    print("Push is connected: every new notification row is sent to the phones with Firebase Cloud Messaging")


# ---------------- Firebase ----------------

def google_token(sa):
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account
    creds = service_account.Credentials.from_service_account_info(
        sa, scopes=["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/firebase"])
    try:
        creds.refresh(Request())
    except Exception as e:
        raise SystemExit(f"Firebase sign-in failed for {sa.get('client_email', '?')}: {e}. Generate a new private key "
                         "(Firebase console > Project settings > Service accounts) and save it in Alpha.")
    return creds.token


def fb(method, path, token, body=None):
    try:
        return http(method, f"https://firebase.googleapis.com/v1beta1/{path}", token, body)
    except RuntimeError as e:
        if "-> 403" in str(e):
            raise SystemExit(f"Firebase refused ({e}). Give the service account the role 'Firebase Admin' in Google Cloud > IAM.")
        raise SystemExit(str(e))


def register_apps(proj, sa):
    """Registers every Android app of the project and returns {package: options} for the engines."""
    token = google_token(sa)
    project = sa["project_id"]
    existing = fb("GET", f"projects/{project}/androidApps?pageSize=100", token).get("apps", [])
    out = {}
    for app in proj["apps"]:
        pkg = app["package"]
        found = next((x for x in existing if x.get("packageName") == pkg), None)
        if not found:
            print(f"Registering {pkg} in Firebase project {project}…")
            op = fb("POST", f"projects/{project}/androidApps", token, {"packageName": pkg, "displayName": app.get("title") or app["slug"]})
            for _ in range(40):
                if op.get("done"):
                    break
                time.sleep(2)
                op = fb("GET", op["name"], token)
            found = op.get("response") or {}
            if not found.get("appId"):
                raise SystemExit(f"Firebase did not finish registering {pkg}: {op}")
        cfg = fb("GET", f"projects/{project}/androidApps/{found['appId']}/config", token)
        gs = json.loads(base64.b64decode(cfg["configFileContents"]).decode())
        client = next(c for c in gs["client"] if c["client_info"]["android_client_info"]["package_name"] == pkg)
        out[pkg] = {
            "apiKey": client["api_key"][0]["current_key"],
            "appId": client["client_info"]["mobilesdk_app_id"],
            "senderId": gs["project_info"]["project_number"],
            "projectId": gs["project_info"]["project_id"],
            "storageBucket": gs["project_info"].get("storage_bucket", ""),
        }
        (ROOT / "apps" / app["slug"]).mkdir(parents=True, exist_ok=True)
        (ROOT / "apps" / app["slug"] / "google-services.json").write_text(json.dumps(gs, indent=2), encoding="utf-8")
    return out


def setup_firebase(proj, pdir):
    sa = json.loads(need("FIREBASE_SERVICE_ACCOUNT", "the Firebase service account JSON"))
    token = google_token(sa)
    project = sa["project_id"]
    p = proj["prefix"]
    options = register_apps(proj, sa)

    db = http("GET", f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)", token, ok404=True)
    if db is None:
        print("Creating the Firestore database…")
        try:
            op = http("POST", f"https://firestore.googleapis.com/v1/projects/{project}/databases?databaseId=(default)", token,
                      {"locationId": proj.get("firestoreLocation", "eur3"), "type": "FIRESTORE_NATIVE"})
            for _ in range(30):
                if op.get("done"):
                    break
                time.sleep(3)
                op = http("GET", f"https://firestore.googleapis.com/v1/{op['name']}", token)
        except RuntimeError as e:
            print(f"::warning::Could not create Firestore ({e}). Create it in Firebase console > Firestore Database.")

    rules = (pdir / "firestore.rules").read_text(encoding="utf-8")
    try:
        rs = http("POST", f"https://firebaserules.googleapis.com/v1/projects/{project}/rulesets", token,
                  {"source": {"files": [{"name": "firestore.rules", "content": rules}]}})
        release = f"projects/{project}/releases/cloud.firestore"
        try:
            http("PATCH", f"https://firebaserules.googleapis.com/v1/{release}", token, {"release": {"name": release, "rulesetName": rs["name"]}})
        except RuntimeError:
            http("POST", f"https://firebaserules.googleapis.com/v1/projects/{project}/releases", token, {"name": release, "rulesetName": rs["name"]})
        print("Firestore security rules published")
    except RuntimeError as e:
        raise SystemExit(f"Publishing the Firestore rules failed: {e}")

    try:
        http("PATCH", f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project}/config?updateMask=signIn.anonymous.enabled,signIn.email.enabled,signIn.email.passwordRequired",
             token, {"signIn": {"anonymous": {"enabled": True}, "email": {"enabled": True, "passwordRequired": True}}})
        print("Firebase Authentication: anonymous + email/password are on")
    except RuntimeError as e:
        print(f"::warning::Turn on Authentication (Anonymous and Email/Password) in Firebase console: {e}")

    for mail in proj.get("admins", []):
        mail = mail.strip().lower()
        if "@" not in mail:
            continue
        doc = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/{p}_admins/{urllib.request.quote(mail)}"
        try:
            http("PATCH", doc, token, {"fields": {"email": {"stringValue": mail}}})
        except RuntimeError as e:
            print(f"::warning::Could not add admin {mail}: {e}")

    if proj.get("push"):
        deploy_firebase_push(p, project, sa)
    return {"type": "firebase", "firebase": options}


def deploy_firebase_push(p, project, sa):
    """Cloud Function that sends a push for every new <p>_notifications document (needs the Blaze plan)."""
    src = ROOT / "factory" / "templates" / "firebase_push"
    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        (d / "functions").mkdir()
        for f in src.iterdir():
            (d / "functions" / f.name).write_text(f.read_text(encoding="utf-8").replace("__PREFIX__", p), encoding="utf-8")
        (d / "firebase.json").write_text(json.dumps({"functions": [{"source": "functions", "codebase": p.replace("_", "-")}]}), encoding="utf-8")
        key = d / "sa.json"
        key.write_text(json.dumps(sa), encoding="utf-8")
        env = {**os.environ, "GOOGLE_APPLICATION_CREDENTIALS": str(key)}
        subprocess.run(["npm", "install", "--prefix", "functions", "--silent"], cwd=d, env=env, check=False)
        r = subprocess.run(["npx", "--yes", "firebase-tools@14", "deploy", "--only", "functions", "--project", project, "--non-interactive", "--force"],
                           cwd=d, env=env, capture_output=True, text=True)
        print((r.stdout + r.stderr)[-3000:])
        if r.returncode != 0:
            print("::warning::The push Cloud Function was not deployed (Cloud Functions need the Firebase Blaze plan). "
                  "Notifications still appear inside the apps.")
        else:
            print("Push is connected (Cloud Function)")


# ---------------- main ----------------

def write_apps(proj, result):
    for app in proj["apps"]:
        path = ROOT / "apps" / app["slug"] / "alpha.json"
        cfg = json.loads(path.read_text(encoding="utf-8"))
        be = cfg.setdefault("backend", {})
        be["type"] = result["type"]
        if result["type"] == "supabase":
            be["url"], be["anonKey"] = result["url"], result["anonKey"]
        fbopts = (result.get("firebase") or {}).get(app["package"])
        if fbopts:
            be["firebase"] = fbopts
        path.write_text(json.dumps(cfg, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"apps/{app['slug']}/alpha.json connected")


def main(base):
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,30}", base):
        raise SystemExit("bad project name")
    pdir = ROOT / "projects" / base
    proj = json.loads((pdir / "project.json").read_text(encoding="utf-8"))
    kind = proj.get("backend")
    if kind == "supabase":
        result = setup_supabase(proj, pdir)
    elif kind == "firebase":
        result = setup_firebase(proj, pdir)
    else:
        print("This project keeps its data on the phone: nothing to set up")
        return
    write_apps(proj, result)
    status = {"ready": True, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "backend": kind,
              "url": result.get("url", ""), "push": bool(result.get("firebase")) or kind == "firebase"}
    (pdir / "status.json").write_text(json.dumps(status, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        raise SystemExit(2)
    main(sys.argv[1])
