#!/usr/bin/env python3
"""Makes a new build reachable by the installed copies of the app, without a GitHub account:

    python factory/publish_update.py <app> <version> <apk> [notes]   -> prints the public APK link (or nothing)

1. With a public updates repository (UPDATES_REPO + UPDATES_TOKEN, made from Alpha > الإعدادات > التحديثات): the APK
   is published there as a release and <app>.json (version, link, notes) is written, which the apps check.
2. For Supabase projects (SUPABASE_ACCESS_TOKEN): an "update ready" notification is added, so the phones get a
   push notification even when the app is closed.
"""
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def api(method, path, token, body=None, ok404=False):
    req = urllib.request.Request(f"https://api.github.com{path}", method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
                                          "Content-Type": "application/json", "User-Agent": "alpha"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            text = r.read().decode()
            return json.loads(text) if text.strip() else {}
    except urllib.error.HTTPError as e:
        if ok404 and e.code == 404:
            return None
        raise RuntimeError(f"GitHub {method} {path} -> {e.code}: {e.read().decode()[:300]}")


def publish(app, version, apk, notes):
    repo = os.environ.get("UPDATES_REPO", "").strip()
    token = os.environ.get("UPDATES_TOKEN", "").strip()
    if not repo:
        return ""
    if not token:
        print("::warning::UPDATES_REPO is set but the UPDATES_TOKEN secret is missing: open Alpha > الإعدادات > التحديثات", file=sys.stderr)
        return ""
    tag = f"{app}-v{version}"
    env = {**os.environ, "GH_TOKEN": token}
    for attempt in range(5):
        r = subprocess.run(["gh", "release", "create", tag, apk, "--repo", repo, "--title", f"{app} 1.0.{version}",
                            "--notes", notes or "Update"], env=env, capture_output=True, text=True)
        if r.returncode == 0 or "already exists" in r.stderr:
            break
        print(f"Updates repo release failed ({r.stderr.strip()[:200]}), retrying", file=sys.stderr)
        time.sleep(5 * (attempt + 1))
    else:
        return ""
    link = f"https://github.com/{repo}/releases/download/{tag}/{Path(apk).name}"
    info = {"version": int(version), "name": f"1.0.{version}", "apk": link, "notes": notes or "",
            "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    path = f"/repos/{repo}/contents/{app}.json"
    for attempt in range(5):
        try:
            old = api("GET", path, token, ok404=True)
            body = {"message": f"{app} 1.0.{version}", "content": base64.b64encode(json.dumps(info, indent=1).encode()).decode()}
            if old and old.get("sha"):
                body["sha"] = old["sha"]
            api("PUT", path, token, body)
            break
        except RuntimeError as e:
            print(f"Writing {app}.json failed ({e}), retrying", file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    print(f"Update published for installed copies: {link}", file=sys.stderr)
    return link


def notify(app, version, link):
    """An 'update ready' notification row; the project's push function sends it to the phones."""
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    cfg = json.loads((ROOT / "apps" / app / "alpha.json").read_text(encoding="utf-8"))
    be = cfg.get("backend") or {}
    m = re.match(r"https://([a-z0-9]+)\.supabase\.co", str(be.get("url", "")))
    if not token or be.get("type") != "supabase" or not m or not link:
        return
    prefix = re.sub(r"[^a-z0-9_]", "_", str(be.get("prefix", "")))
    role = "admin" if cfg.get("app", {}).get("role") == "admin" else "customer"
    title = f"تحديث جديد لـ {cfg.get('app', {}).get('title', app)}"

    def q(v):
        return "'" + str(v).replace("'", "''") + "'"

    data = json.dumps({"type": "update", "app": app, "version": int(version), "apk": link}, ensure_ascii=False)
    sql = (f"insert into public.{prefix}_notifications (to_role, title, body, data) values "
           f"({q(role)}, {q(title)}, {q('النسخة 1.0.' + str(version) + ' جاهزة: افتح التطبيق للتحديث')}, {q(data)}::jsonb);")
    req = urllib.request.Request(f"https://api.supabase.com/v1/projects/{m.group(1)}/database/query", method="POST",
                                 data=json.dumps({"query": sql}).encode(),
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json", "User-Agent": "alpha"})
    try:
        urllib.request.urlopen(req, timeout=60).read()
        print("Installed copies were notified (push)", file=sys.stderr)
    except Exception as e:
        print(f"::warning::Could not send the update notification: {e}", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)
    app, version, apk = sys.argv[1:4]
    notes = sys.argv[4] if len(sys.argv) > 4 else ""
    if os.environ.get("STORE", "").lower() == "true":
        raise SystemExit(0)
    link = publish(app, version, apk, notes)
    notify(app, version, link)
    print(link)
