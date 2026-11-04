#!/usr/bin/env python3
"""Prepares a sample app in every language and backend and checks the result (run in CI by alpha.yml).
Catches a broken engine or prepare step before any user build does."""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "factory"))
import prepare  # noqa: E402

TABLES = [
    {"name": "products", "label": "المنتجات", "icon": "shopping_bag", "owner": "catalog",
     "columns": [{"name": "title", "label": "الاسم", "type": "text", "required": True}, {"name": "price", "label": "السعر", "type": "decimal"},
                 {"name": "photo", "label": "صورة", "type": "image"}]},
    {"name": "orders", "label": "الطلبات", "icon": "receipt", "owner": "customer", "notify": {"onInsert": "admin", "onUpdate": "owner"},
     "columns": [{"name": "items", "label": "المطلوب", "type": "longtext", "required": True}, {"name": "day", "label": "اليوم", "type": "date", "default": "today"},
                 {"name": "status", "label": "الحالة", "type": "choice", "options": ["جديد", "تم"], "default": "جديد", "adminOnly": True}]},
]
FB = {"apiKey": "AIzaTest", "appId": "1:1:android:1", "senderId": "1", "projectId": "demo"}
BACKENDS = {
    "none": {"type": "none", "prefix": "selftest"},
    "supabase": {"type": "supabase", "prefix": "selftest", "url": "https://example.supabase.co", "anonKey": "k", "auth": "email_password", "push": True, "firebase": FB},
    "firebase": {"type": "firebase", "prefix": "selftest", "auth": "none", "push": True, "firebase": FB},
}


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        raise SystemExit(f"FAILED: {' '.join(map(str, cmd))}\n{r.stdout}\n{r.stderr}")


def main():
    made = []
    tmp = Path(tempfile.mkdtemp())
    try:
        for lang in prepare.LANGS:
            for kind, be in BACKENDS.items():
                if kind == "firebase" and lang not in ("flutter", "html"):
                    continue
                app = f"selftest-{lang}-{kind}"
                d = ROOT / "apps" / app
                d.mkdir(parents=True, exist_ok=True)
                made.append(d)
                cfg = {"alpha": 1, "project": "selftest", "lang": lang, "app": {"title": "اختبار", "role": "customer"},
                       "theme": {"seed": "#6E4BFF", "accent": "#2DD4BF"}, "backend": be, "tables": TABLES}
                (d / "alpha.json").write_text(json.dumps(cfg, ensure_ascii=False), encoding="utf-8")
                errors = prepare.validate(prepare.load(app))
                if errors:
                    raise SystemExit(f"{app}: {errors}")
                out = tmp / app
                if lang == "flutter":
                    (out / "android" / "app" / "src" / "main" / "res").mkdir(parents=True)
                    (out / "android" / "app" / "src" / "main" / "AndroidManifest.xml").write_text('<manifest><application android:label="x"></application></manifest>')
                    (out / "android" / "app" / "build.gradle.kts").write_text('android { defaultConfig { applicationId = "x"\n minSdk = flutter.minSdkVersion\n versionCode = flutter.versionCode } }')
                prepare.PREPARE[lang](prepare.load(app), app, out, 99)
                if lang == "html":
                    run(["node", str(ROOT / "factory" / "check_html.js"), str(out)])
                elif lang == "php":
                    for f in out.rglob("*.php"):
                        run(["php", "-l", str(f)])
                elif lang == "python":
                    run([sys.executable, "-m", "py_compile", *map(str, out.glob("*.py"))])
                elif lang == "kotlin":
                    g = (out / "app" / "build.gradle.kts").read_text()
                    assert "__APP_ID__" not in g and "com.alpha.selftest_kotlin" in g, "kotlin ids not filled"
                    json.loads((out / "app" / "src" / "main" / "res" / "raw" / "alpha_config.json").read_text())
                elif lang == "flutter":
                    w = (out / "lib" / "alpha" / "wiring.dart").read_text()
                    want = {"none": "LocalBackend", "supabase": "SupabaseBackend", "firebase": "FirestoreBackend"}[kind]
                    assert want in w, f"wiring of {app} does not use {want}"
                print(f"ok  {app}")
    finally:
        for d in made:
            shutil.rmtree(d, ignore_errors=True)
        shutil.rmtree(tmp, ignore_errors=True)
    print("selftest passed")


if __name__ == "__main__":
    main()
