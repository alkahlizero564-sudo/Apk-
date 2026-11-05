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


def design_standard():
    """The professional design standard every app follows (factory/design_brief.md, shared with Alpha's design stage)."""
    text = (ROOT / "factory" / "design_brief.md").read_text(encoding="utf-8")
    return re.sub(r"^<!--.*?-->\s*", "", text, flags=re.S)


def design_note(cfg):
    """The interface the owner approved in Alpha (apps/<app>/design): the code must reproduce it."""
    d = app_dir(cfg["app"]["slug"]) / "design"
    if (d / "design.html").is_file():
        # Design first (like APK Fact): a clickable prototype of every screen.
        proto = (d / "design.html").read_text(encoding="utf-8")[:60000]
        return ("\nAPPROVED DESIGN - the owner reviewed and approved this clickable design prototype. Build the real app so it "
                "looks exactly like it: the same screens, navigation, layout, colors, typography, spacing, corner radius, icons, "
                "texts and components (in native languages map them to the closest widgets). Ignore the prototype's top "
                "'screens' switcher (id alpha-screens): it is only for reviewing. Replace its sample data with the real data "
                "through the engine API, and make every screen fully functional.\n```html\n" + proto + "\n```\n")
    if not cfg.get("theme", {}).get("ai") or not (d / "spec.md").is_file():
        return ""
    spec = (d / "spec.md").read_text(encoding="utf-8")[:9000]
    css = (d / "design.css").read_text(encoding="utf-8")[:9000] if (d / "design.css").is_file() else ""
    return ("\nTHE APPROVED DESIGN (the owner saw it in the instant preview and chose it): reproduce it faithfully, natively, "
            "screen by screen (colors, fonts, radii, shadows, layout, components, motion). Spec:\n" + spec +
            ("\n\nIts web preview CSS, for exact values (do not copy CSS into native code, translate it):\n" + css if css else "") + "\n")


def missing_requirements(cfg, request, files):
    """Asks the AI which of the owner's requirements the code does not do yet (like APK Fact): [] when all are done."""
    brief = str(cfg["app"].get("brief") or "").strip()
    code = "\n".join(f"--- {p} ---\n{c}" for p, c in files.items())[:90000]
    prompt = ("You review an app before it is delivered. List the owner's requirements that the code below does NOT implement "
              "(features, screens, fields, texts, rules). Ignore style details and things the engine already provides "
              "(data storage, sign-in, notifications). Reply with JSON only: {\"missing\": [\"short item\", ...]} "
              "(empty list when everything is done).\n\nThe app (approved understanding):\n" + brief +
              "\n\nWhat the owner asked now:\n" + request + "\n\nCode:\n" + code)
    try:
        text = ask(prompt, max_tokens=4000)
        j = json.loads(text[text.index("{"): text.rindex("}") + 1])
        return [str(x) for x in j.get("missing", []) if str(x).strip()][:15]
    except Exception as e:  # the check is a bonus: never fail the build for it
        print(f"::warning::requirements check skipped ({e})")
        return []


def prompt_base(cfg, lang):
    c = CONTRACT[lang]
    api = (ROOT / c["api"]).read_text(encoding="utf-8")
    tables = json.dumps(cfg.get("tables", []), ensure_ascii=False, indent=1)
    theme = json.dumps(cfg.get("theme", {}), ensure_ascii=False)
    brief = str(cfg["app"].get("brief") or "").strip()
    brief_note = f"\nThe approved understanding of the app (follow it):\n{brief}\n" if brief else ""
    brief_note += design_note(cfg)
    return f"""You write the code of one mobile app made with Alpha.{brief_note}
Language: {lang}. App: «{cfg['app'].get('title')}» (role: {cfg['app'].get('role')} — single app, or the customer / admin app of a connected pair).
Backend: {cfg['backend'].get('type')} (sign-in: {cfg['backend'].get('auth', 'none')}). Theme: {theme}.

Rules:
{c['rules']}
- Design: modern, premium and consistent: the theme colors above (seed + accent gradient), rounded corners (radius {cfg['theme'].get('radius', 18)}),
  generous spacing, clear hierarchy, empty states, loading states, error messages in Arabic, dark/light per theme.mode.

{design_standard()}
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
    if not any(allowed_path(lang, p) for p in files):
        raise SystemExit("The AI answer had no usable files")
    # Make sure the app does everything the owner asked; one more round adds what is missing.
    missing = missing_requirements(cfg, request, {p: c for p, c in files.items() if allowed_path(lang, p)})
    if missing:
        print("Missing from the request:\n- " + "\n- ".join(missing), flush=True)
        retry = (prompt + "\n\nYour previous answer is below, but it does not do all of what the owner asked. Missing or different:\n- "
                 + "\n- ".join(missing) + "\n\nReturn every file again, complete, with ALL of these implemented exactly as asked, "
                 "keeping everything else.\n\nPREVIOUS ANSWER:\n" + "\n".join(f"```{FENCE[lang]} {p}\n{c}\n```" for p, c in files.items()))
        try:
            again = code_blocks(ask(retry))
            if any(allowed_path(lang, p) for p in again):
                files = again
                print("Added what was missing", flush=True)
        except Exception as e:  # keep the first version
            print(f"::warning::could not add the missing parts ({e})")
    else:
        print("Request check: everything asked for is implemented", flush=True)
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
