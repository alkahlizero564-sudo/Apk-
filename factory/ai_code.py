#!/usr/bin/env python3
"""AI code for one app, on top of Alpha's engine (the engine keeps the data, sign-in, push and build wiring).

    python factory/ai_code.py generate <app> <request-file>   # writes apps/<app>/custom/...
    python factory/ai_code.py fix <app> <build-log>           # fixes apps/<app>/custom/... from a failed build
                                                              # exit 0 fixed, 3 not caused by custom code, 1 failed

The AI may only write the files of its language's contract and use only factory/libraries.json.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ai import AIError, ask, code_blocks  # noqa: E402
from prepare import libraries, load, app_dir, ROOT, ENGINES  # noqa: E402

FENCE = {'flutter': 'dart', 'html': 'html', 'python': 'python', 'kotlin': 'kotlin', 'php': 'php'}

CONTRACT = {
    "flutter": {
        "files": ["lib/main.dart", "lib/screens/*.dart", "lib/widgets/*.dart", "packages.txt"],
        "api": "engines/flutter/lib/alpha/backend.dart",
        "rules": (
            "Write a complete Flutter app (Material 3, useMaterial3: true, null safety, Dart 3.13). Keep the engine: "
            "start with `final backend = createBackend(AlphaConfig.instance); await backend.init();` "
            "(import 'alpha/config.dart' and 'alpha/wiring.dart'), use backend.list/insert/update/delete/notifications/notify "
            "for ALL data, show the login screen when `!backend.signedIn` (backend.signIn / signUp), and call "
            "`setupPush(backend, AlphaConfig.instance, messengerKey)` after sign-in (it is exported by wiring.dart). "
            "Table configs are AlphaConfig.instance.tables (TableCfg with name, label, columns). Rows are Map<String, dynamic> (typedef Rec). "
            "Arabic UI: locale ar, Directionality RTL via MaterialApp locale + GlobalMaterialLocalizations.delegates. "
            "List extra pub.dev packages (only from the allowed list) one per line in packages.txt."
        ),
    },
    "html": {
        "files": ["index.html", "app.js", "style.css"],
        "api": "engines/html/backend.js",
        "rules": (
            "Write a complete mobile web app (it runs in an Android WebView via Capacitor, offline). index.html must load, in this order, "
            "config.js then backend.js then your app.js. Use window.AlphaBackend (B) for ALL data: await B.init(), B.signedIn, "
            "B.signIn/signUp/signOut, B.list/insert/update/remove(table,...), B.notifications(), B.notify({...}). Table configs are "
            "window.ALPHA.tables. Libraries only from vendor/ (the allowed list, with the given <script>/<link> tags); never a CDN. "
            "Arabic RTL (<html dir=rtl lang=ar>), mobile-first, safe-area insets, no alert()/prompt() for normal flows."
        ),
    },
    "python": {
        "files": ["main.py", "*.py", "requirements.txt"],
        "api": "engines/python/alpha_backend.py",
        "rules": (
            "Write a Flet 1.0.5 app (Flet 1.x API: ft.run(main), ft.Colors/ft.Icons enums, ft.Button/FilledButton with content=, "
            "ft.Padding.only/all/symmetric, ft.BorderRadius.all/only, ft.Alignment.CENTER, page.show_dialog()/page.pop_dialog(), "
            "ft.Dropdown(options=[ft.DropdownOption(key=, text=)], on_select=), ft.NavigationBar + NavigationBarDestination). "
            "Use `from alpha_backend import create_backend, BackendError` and `from alpha_config import CONFIG`; b = create_backend(CONFIG); "
            "b.init(); use b.list/insert/update/delete/notifications/notify for ALL data. page.rtl = True for Arabic. "
            "requirements.txt: flet==1.0.5 plus only allowed packages."
        ),
    },
    "kotlin": {
        "files": ["MainActivity.kt", "Ui.kt", "*.kt"],
        "api": "engines/kotlin/src/Backend.kt",
        "rules": (
            "Write Kotlin + Jetpack Compose (Material 3) files in `package app.main`. Keep MainActivity's start: "
            "`val config = AlphaConfig.load(this); val backend = Backend.create(config, this)`, call `Push.setup(this, backend)` after sign-in, "
            "and use the suspend functions backend.list/insert/update/delete/notifications/notify inside coroutines for ALL data. "
            "Do not redefine AlphaConfig, Backend, TableCfg, ColumnCfg, Rec or Push (they exist). Only the libraries listed; explicit imports, "
            "no wildcard imports. RTL with CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl)."
        ),
    },
    "php": {
        "files": ["index.php", "lib/view.php", "lib/*.php", "assets/*.css", "composer.json"],
        "api": "engines/php/lib/backend.php",
        "rules": (
            "Write a PHP 8.3 web app (server-rendered, mobile-first, Arabic RTL). Keep `$C = require __DIR__ . '/config.php'; "
            "$B = Backend::create($C); $B->init();` and use $B->list/get/insert/update/delete/notifications/notify for ALL data; "
            "sessions + CSRF tokens on every POST; escape all output with htmlspecialchars. Composer packages only from the allowed list."
        ),
    },
}


def lib_lines(lang):
    out = []
    for p in libraries()[lang]["packages"]:
        line = f"- {p['name']} {p['version']}: {p['use']}"
        if p.get("tag"):
            line += f"  ->  {p['tag']}"
        out.append(line)
    return "\n".join(out)


def custom_files(app):
    d = app_dir(app) / "custom"
    if not d.is_dir():
        return {}
    return {str(p.relative_to(d)): p.read_text(encoding="utf-8") for p in sorted(d.rglob("*"))
            if p.is_file() and p.suffix in (".dart", ".js", ".html", ".css", ".py", ".kt", ".php", ".txt", ".json")}


def allowed_path(lang, path):
    import fnmatch
    path = path.strip().lstrip("./")
    if ".." in path or path.startswith("/"):
        return False
    return any(fnmatch.fnmatch(path, pattern) for pattern in CONTRACT[lang]["files"])


def write_files(app, lang, files):
    d = app_dir(app) / "custom"
    written = []
    for path, code in files.items():
        if not allowed_path(lang, path):
            print(f"::warning::AI wrote {path!r}, which is not allowed for {lang}; skipped")
            continue
        target = d / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(code, encoding="utf-8")
        written.append(path)
    return written


def prompt_base(cfg, lang):
    c = CONTRACT[lang]
    api = (ROOT / c["api"]).read_text(encoding="utf-8")
    tables = json.dumps(cfg.get("tables", []), ensure_ascii=False, indent=1)
    theme = json.dumps(cfg.get("theme", {}), ensure_ascii=False)
    brief = str(cfg["app"].get("brief") or "").strip()
    brief_note = f"\nThe approved understanding of the app (follow it):\n{brief}\n" if brief else ""
    return f"""You write the code of one mobile app made with Alpha.{brief_note}
Language: {lang}. App: «{cfg['app'].get('title')}» (role: {cfg['app'].get('role')} — single app, or the customer / admin app of a connected pair).
Backend: {cfg['backend'].get('type')} (sign-in: {cfg['backend'].get('auth', 'none')}). Theme: {theme}.

Rules:
{c['rules']}
- Design: modern, premium and consistent: the theme colors above (seed + accent gradient), rounded corners (radius {cfg['theme'].get('radius', 18)}),
  generous spacing, clear hierarchy, empty states, loading states, error messages in Arabic, dark/light per theme.mode.
- Never hard-code server URLs or keys; they are in the config. Never invent tables: use exactly these tables and columns:
{tables}

Allowed libraries (nothing else):
{lib_lines(lang)}

The engine API you must use for data (already in the project, do not rewrite it):
```
{api[:14000]}
```

Files you may write: {', '.join(c['files'])}.
Reply with one fenced block per file, the file path after the language on the opening line, e.g.
```{FENCE[lang]} {c['files'][0]}
...
```
Write complete files (no "..." placeholders). Nothing outside the code blocks."""


def generate(app, request_file):
    cfg = load(app)
    lang = cfg["lang"]
    request = Path(request_file).read_text(encoding="utf-8").strip()
    current = custom_files(app)
    extra = ""
    if current:
        extra = "\n\nThe app already has this custom code; change it as asked and return every file you change in full:\n" + "\n".join(
            f"--- {p} ---\n{code}" for p, code in current.items())
    prompt = prompt_base(cfg, lang) + f"\n\nWhat the owner wants (Arabic or English):\n{request}{extra}"
    files = code_blocks(ask(prompt))
    written = write_files(app, lang, files)
    if not written:
        raise SystemExit("The AI answer had no usable files")
    print("AI wrote: " + ", ".join(written))


def fix(app, log_file):
    cfg = load(app)
    lang = cfg["lang"]
    current = custom_files(app)
    log = Path(log_file).read_text(encoding="utf-8", errors="replace")
    errors = [l for l in log.splitlines() if re.search(r"error|exception|failed|unresolved|cannot find|undefined", l, re.I)]
    snippet = "\n".join(errors[-80:]) or log[-6000:]
    if not current:
        print("No custom code: the error is not in AI code (the engine is tested). Not changing anything.")
        raise SystemExit(3)
    mentioned = any(Path(p).name in log for p in current)
    if not mentioned and lang in ("flutter", "kotlin", "python"):
        print("The build log does not mention the custom files: probably not a code error.")
        raise SystemExit(3)
    prompt = prompt_base(cfg, lang) + "\n\nThis code failed to build. Errors:\n```\n" + snippet[-9000:] + "\n```\n\nCurrent files:\n" + "\n".join(
        f"--- {p} ---\n{code}" for p, code in current.items()) + "\n\nFix every error and return each changed file in full."
    try:
        files = code_blocks(ask(prompt))
    except AIError as e:
        print(f"AI fix failed: {e}")
        raise SystemExit(1)
    written = write_files(app, lang, files)
    if not written:
        raise SystemExit(1)
    print("AI fixed: " + ", ".join(written))


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("generate", "fix"):
        print(__doc__)
        raise SystemExit(2)
    (generate if sys.argv[1] == "generate" else fix)(sys.argv[2], sys.argv[3])
