#!/usr/bin/env python3
"""Turns apps/<app>/alpha.json (made by the Alpha app) into a buildable project.

    python factory/prepare.py project <lang> <app> <out>   # engine + config + icon + name + package into <out>
    python factory/prepare.py meta <app> <field>           # prints lang | label | package | role | server | push | backend
    python factory/prepare.py check <app>                  # validates alpha.json (exit 1 with the reasons)
    python factory/prepare.py npm-list x                   # the HTML libraries to npm install
    python factory/prepare.py vendor <node_modules> <out>  # copies them into an app's vendor/ folder
    python factory/prepare.py android <app> <src/main> [<app/build.gradle>]  # name, icon, permissions, ids

Engines live in engines/<lang>/ (tested, schema-driven apps). Code written with AI for one app lives in
apps/<app>/custom/ and is copied over the engine, so an app can be fully custom and still get the
backend, push and build wiring. Needs Pillow for icons (pip install pillow).
"""
import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINES = ROOT / "engines"
LANGS = ("html", "php", "flutter", "python", "kotlin")
IDENT = re.compile(r"^[a-z][a-z0-9_]{0,40}$")
COLUMN_TYPES = {"text", "longtext", "int", "decimal", "bool", "date", "datetime", "image", "phone", "email", "choice"}
OWNERS = {"catalog", "customer", "public", "admin"}

FLUTTER_DEPS = {
    "firebase": ["firebase_core: ^5.1.0", "cloud_firestore: ^7.1.0", "firebase_auth: ^7.0.1"],
    "push": ["firebase_core: ^5.1.0", "firebase_messaging: ^17.0.1"],
}


def libraries():
    return json.loads((ROOT / "factory" / "libraries.json").read_text(encoding="utf-8"))


def vendor(node_modules, out):
    """Copies the HTML libraries of factory/libraries.json from an npm install into <out> (vendor/)."""
    out = Path(out)
    for pkg in libraries()["html"]["packages"]:
        for target, src in pkg["files"].items():
            path = Path(node_modules) / pkg["name"] / src
            if not path.exists():
                print(f"::warning::{pkg['name']}: {src} not found")
                continue
            (out / target).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, out / target)
    print(f"HTML libraries copied to {out}")


def app_dir(app):
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,40}", app):
        raise SystemExit(f"bad app name: {app!r}")
    return ROOT / "apps" / app


def load(app):
    path = app_dir(app) / "alpha.json"
    if not path.exists():
        raise SystemExit(f"apps/{app}/alpha.json is missing (create the app in Alpha first)")
    cfg = json.loads(path.read_text(encoding="utf-8"))
    cfg.setdefault("app", {})
    cfg["app"].setdefault("slug", app)
    cfg["app"].setdefault("title", app)
    cfg["app"].setdefault("role", "single")
    cfg.setdefault("theme", {})
    cfg.setdefault("backend", {"type": "none"})
    cfg["backend"].setdefault("prefix", re.sub(r"[^a-z0-9_]", "_", cfg.get("project", app).lower()))
    cfg.setdefault("tables", [])
    return cfg


def validate(cfg):
    errors = []
    lang = cfg.get("lang")
    if lang not in LANGS:
        errors.append(f"lang must be one of {LANGS}, not {lang!r}")
    if cfg["app"]["role"] not in ("single", "customer", "admin"):
        errors.append("app.role must be single, customer or admin")
    be = cfg["backend"]
    if be.get("type") not in ("none", "supabase", "firebase"):
        errors.append("backend.type must be none, supabase or firebase")
    if be.get("type") == "firebase" and lang not in ("flutter", "html"):
        errors.append("Firebase as the database works with Flutter and HTML apps only")
    if not IDENT.match(str(be.get("prefix", ""))):
        errors.append("backend.prefix must be lowercase letters, digits and _")
    names = set()
    for t in cfg["tables"]:
        n = t.get("name", "")
        if not IDENT.match(n):
            errors.append(f"table name {n!r} must be lowercase English (a-z, 0-9, _)")
        if n in names:
            errors.append(f"table {n!r} is repeated")
        names.add(n)
        if t.get("owner", "customer") not in OWNERS:
            errors.append(f"table {n}: owner must be one of {sorted(OWNERS)}")
        cols = set()
        for c in t.get("columns", []):
            cn = c.get("name", "")
            if not IDENT.match(cn) or cn in ("id", "created_at", "updated_at", "customer_id"):
                errors.append(f"{n}.{cn}: bad or reserved column name")
            if cn in cols:
                errors.append(f"{n}.{cn}: repeated column")
            cols.add(cn)
            if c.get("type", "text") not in COLUMN_TYPES:
                errors.append(f"{n}.{cn}: unknown type {c.get('type')!r}")
            if c.get("type") == "choice" and not c.get("options"):
                errors.append(f"{n}.{cn}: a choice column needs options")
    return errors


def package_id(cfg, app):
    pkg = str(cfg["app"].get("package") or "").strip()
    if re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+", pkg):
        return pkg
    return "com.alpha." + app.replace("-", "_")


def label(cfg):
    return str(cfg["app"].get("title") or cfg["app"]["slug"]).strip()[:40] or "Alpha"


def push_on(cfg):
    be = cfg["backend"]
    f = be.get("firebase") or {}
    return bool(be.get("push")) and be.get("type") in ("supabase", "firebase") and bool(f.get("apiKey")) and bool(f.get("appId"))


def runtime_config(cfg):
    """The part of alpha.json the app itself reads (no build-only fields)."""
    out = {k: cfg[k] for k in ("app", "theme", "backend", "tables") if k in cfg}
    be = dict(out["backend"])
    be["push"] = push_on(cfg)
    be.pop("serviceAccount", None)
    out["backend"] = be
    upd = update_info(cfg)
    if upd:
        out["update"] = upd
    return out


def update_url(app):
    """Public address of an app's newest-version file: the public updates repo when there is one (the main
    repository can stay private), else this repository (only reachable when it is public)."""
    updates = os.environ.get("UPDATES_REPO", "").strip()
    if updates:
        return f"https://raw.githubusercontent.com/{updates}/main/{app}.json"
    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    branch = os.environ.get("GITHUB_REF_NAME", "main").strip() or "main"
    return f"https://raw.githubusercontent.com/{repo}/{branch}/apps/{app}/build.json" if repo else ""


def update_info(cfg):
    """What the app needs to find its own updates: where to look and which version it is."""
    if store_build():
        return None
    version = int(os.environ.get("VERSION") or 0)
    url = update_url(cfg["app"]["slug"])
    return {"url": url, "version": version} if version and url else None


def store_build():
    """Google Play files must not ask to install other APKs (Play installs the updates itself)."""
    return os.environ.get("STORE", "").lower() == "true"


def copy_tree(src, dst):
    for path in src.rglob("*"):
        if path.is_dir() or "__pycache__" in path.parts:
            continue
        target = dst / path.relative_to(src)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def overlay_custom(app, out):
    custom = app_dir(app) / "custom"
    if custom.is_dir():
        print(f"Custom code of {app} (apps/{app}/custom) copied over the engine")
        copy_tree(custom, out)


def xml_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "\\'").replace('"', '\\"')


# ---------------- icons ----------------

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def icon_image(cfg, app, size=512):
    """apps/<app>/icon.png, or a gradient icon with the app's first letter in the theme colors."""
    from PIL import Image, ImageDraw, ImageFont

    src = app_dir(app) / "icon.png"
    if src.exists():
        try:
            img = Image.open(src).convert("RGBA")
            side = min(img.size)
            img = img.crop(((img.width - side) // 2, (img.height - side) // 2, (img.width + side) // 2, (img.height + side) // 2))
            return img.resize((size, size), Image.LANCZOS)
        except Exception as e:  # a broken upload must not break the build
            print(f"::warning::icon.png of {app} could not be read ({e}); using the generated icon")

    def rgb(h, fallback):
        h = str(h or "").lstrip("#")
        try:
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        except ValueError:
            return fallback

    a = rgb(cfg["theme"].get("seed"), (110, 75, 255))
    b = rgb(cfg["theme"].get("accent"), (45, 212, 191))
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
    draw = ImageDraw.Draw(img)
    letter = (re.sub(r"[^A-Za-z]", "", app)[:1] or "A").upper()
    font = None
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "Arial Bold.ttf"):
        try:
            font = ImageFont.truetype(name, int(size * 0.52))
            break
        except OSError:
            continue
    if font is None:
        try:
            font = ImageFont.load_default(size=int(size * 0.52))
        except TypeError:
            font = ImageFont.load_default()
    box = draw.textbbox((0, 0), letter, font=font)
    draw.text(((size - (box[2] - box[0])) / 2 - box[0], (size - (box[3] - box[1])) / 2 - box[1]), letter, font=font, fill=(255, 255, 255, 255))
    return img


def write_mipmaps(cfg, app, res_dir):
    from PIL import Image

    img = icon_image(cfg, app)
    for d, px in DENSITIES.items():
        folder = Path(res_dir) / f"mipmap-{d}"
        folder.mkdir(parents=True, exist_ok=True)
        icon = img.resize((px, px), Image.LANCZOS)
        icon.save(folder / "ic_launcher.png")
        mask = Image.new("L", (px, px), 0)
        from PIL import ImageDraw
        ImageDraw.Draw(mask).ellipse((0, 0, px - 1, px - 1), fill=255)
        rnd = Image.new("RGBA", (px, px))
        rnd.paste(icon, (0, 0), mask)
        rnd.save(folder / "ic_launcher_round.png")
    # Adaptive icons from flutter create / Capacitor would hide the custom icon: remove them.
    for p in Path(res_dir).glob("mipmap-anydpi*"):
        shutil.rmtree(p, ignore_errors=True)


# ---------------- per language ----------------

def manifest_fix(path, cfg, push, install=False):
    text = Path(path).read_text(encoding="utf-8")
    perms = ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"]
    if push:
        perms.append("android.permission.POST_NOTIFICATIONS")
    if install:
        # In-app updates open Android's installer for the downloaded APK.
        perms.append("android.permission.REQUEST_INSTALL_PACKAGES")
    for p in perms:
        if p not in text:
            text = text.replace("<application", f'<uses-permission android:name="{p}" />\n    <application', 1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', text, count=1)
    Path(path).write_text(text, encoding="utf-8")


def write_strings(res_dir, cfg):
    values = Path(res_dir) / "values"
    values.mkdir(parents=True, exist_ok=True)
    strings = values / "strings.xml"
    name = xml_escape(label(cfg))
    if strings.exists():
        text = strings.read_text(encoding="utf-8")
        if 'name="app_name"' in text:
            text = re.sub(r'<string name="app_name">.*?</string>', f'<string name="app_name">{name}</string>', text, flags=re.S)
        else:
            text = text.replace("</resources>", f'    <string name="app_name">{name}</string>\n</resources>')
        if 'name="title_activity_main"' in text:
            text = re.sub(r'<string name="title_activity_main">.*?</string>', f'<string name="title_activity_main">{name}</string>', text, flags=re.S)
        strings.write_text(text, encoding="utf-8")
    else:
        strings.write_text(f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">{name}</string>\n</resources>\n', encoding="utf-8")


def gradle_app_id(path, pkg, version):
    """applicationId, versions and Android SDK 36 in a Flutter / Capacitor app build.gradle(.kts)."""
    path = Path(path)
    text = path.read_text(encoding="utf-8")
    kts = path.suffix == ".kts"
    q = '"'
    if kts:
        text = re.sub(r'applicationId\s*=\s*"[^"]*"', f'applicationId = {q}{pkg}{q}', text)
        text = re.sub(r"minSdk\s*=\s*[\w.]+", "minSdk = 24", text)
        text = re.sub(r"targetSdk\s*=\s*[\w.]+", "targetSdk = 36", text)
        text = re.sub(r"compileSdk\s*=\s*[\w.]+", "compileSdk = 36", text)
    else:
        text = re.sub(r'applicationId\s+"[^"]*"', f'applicationId "{pkg}"', text)
        text = re.sub(r"minSdkVersion\s+[\w.]+", "minSdkVersion 24", text)
    if version:
        if kts:
            text = re.sub(r"versionCode\s*=\s*[\w.]+", f"versionCode = {version}", text)
            text = re.sub(r"versionName\s*=\s*[\w.\"]+", f'versionName = "1.0.{version}"', text)
        else:
            text = re.sub(r"versionCode\s+\d+", f"versionCode {version}", text)
            text = re.sub(r'versionName\s+"[^"]*"', f'versionName "1.0.{version}"', text)
    path.write_text(text, encoding="utf-8")


def prepare_flutter(cfg, app, out, version):
    out = Path(out)
    shutil.rmtree(out / "lib", ignore_errors=True)
    copy_tree(ENGINES / "flutter" / "lib", out / "lib")
    rc = runtime_config(cfg)
    kind = rc["backend"].get("type", "none")
    push = rc["backend"]["push"]
    deps = []
    if kind == "firebase":
        deps += FLUTTER_DEPS["firebase"]
    if push:
        deps += FLUTTER_DEPS["push"]
    # Packages the custom (AI) code asked for in custom/packages.txt, from the checked list only.
    allowed = {x["name"]: x["version"] for x in libraries()["flutter"]["packages"]}
    wanted = app_dir(app) / "custom" / "packages.txt"
    if wanted.exists():
        for line in wanted.read_text(encoding="utf-8").splitlines():
            name = line.strip().split(":")[0].strip()
            if name in allowed:
                deps.append(f"{name}: {allowed[name]}")
            elif name:
                print(f"::warning::{app}: package {name} is not in factory/libraries.json; left out")
    names = set()
    deps = [d for d in deps if not (d.split(":")[0] in names or names.add(d.split(":")[0]))]
    pubspec = (ENGINES / "flutter" / "pubspec.yaml").read_text(encoding="utf-8")
    pubspec = pubspec.replace("  #ALPHA_DEPS", "\n".join(f"  {d}" for d in deps) or "  #ALPHA_DEPS")
    (out / "pubspec.yaml").write_text(pubspec, encoding="utf-8")

    alpha = out / "lib" / "alpha"
    raw = json.dumps(rc, ensure_ascii=False)
    if "'''" in raw:
        raw = raw.replace("'''", "' ' '")
    (alpha / "config_data.dart").write_text(f"// Written by factory/prepare.py from apps/{app}/alpha.json.\nconst alphaConfigJson = r'''{raw}''';\n", encoding="utf-8")
    impl = {"supabase": ("backend_supabase.dart", "SupabaseBackend"), "firebase": ("backend_firestore.dart", "FirestoreBackend")}.get(
        kind, ("backend_local.dart", "LocalBackend"))
    (alpha / "wiring.dart").write_text(
        "// Written by factory/prepare.py: which backend this app uses and whether push is on.\n"
        f"import 'backend.dart';\nimport '{impl[0]}';\nimport 'config.dart';\n\n"
        f"export '{'push_fcm.dart' if push else 'push_none.dart'}';\n\n"
        f"Backend createBackend(AlphaConfig config) => {impl[1]}(config);\n", encoding="utf-8")
    # Files for packages this app does not have would not compile.
    keep = {impl[0]}
    for f in ("backend_supabase.dart", "backend_firestore.dart", "backend_local.dart"):
        if f not in keep:
            (alpha / f).unlink(missing_ok=True)
    if not push:
        (alpha / "push_fcm.dart").unlink(missing_ok=True)
    if kind != "firebase" and not push:
        (alpha / "firebase_boot.dart").unlink(missing_ok=True)
    shutil.rmtree(out / "test", ignore_errors=True)

    res = out / "android" / "app" / "src" / "main" / "res"
    manifest_fix(out / "android" / "app" / "src" / "main" / "AndroidManifest.xml", cfg, push, install=not store_build())
    write_strings(res, cfg)
    write_mipmaps(cfg, app, res)
    gradle = next((out / "android" / "app").glob("build.gradle*"))
    gradle_app_id(gradle, package_id(cfg, app), version)
    if kind == "firebase" or push:
        # firebase_* plugins need minSdk 23+; core library desugaring is not needed with them.
        text = gradle.read_text(encoding="utf-8")
        gradle.write_text(text, encoding="utf-8")
    overlay_custom(app, out)


def prepare_html(cfg, app, out, version):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    copy_tree(ENGINES / "html", out)
    rc = runtime_config(cfg)
    (out / "config.js").write_text(f"// Written by factory/prepare.py from apps/{app}/alpha.json.\nwindow.ALPHA = "
                                   + json.dumps(rc, ensure_ascii=False) + ";\n", encoding="utf-8")
    vendor = os.environ.get("ALPHA_VENDOR_DIR")
    if vendor and Path(vendor).is_dir():
        copy_tree(Path(vendor), out / "vendor")
    if rc["backend"].get("type") == "firebase":
        tags = "".join(f'  <script src="vendor/firebase/{n}"></script>\n' for n in
                       ("firebase-app-compat.js", "firebase-auth-compat.js", "firebase-firestore-compat.js"))
        index = (out / "index.html").read_text(encoding="utf-8")
        index = index.replace('  <script src="backend.js"></script>', tags + '  <script src="backend.js"></script>')
        (out / "index.html").write_text(index, encoding="utf-8")
    index = (out / "index.html").read_text(encoding="utf-8")
    index = re.sub(r"<title>.*?</title>", f"<title>{label(cfg)}</title>", index)
    (out / "index.html").write_text(index, encoding="utf-8")
    overlay_custom(app, out)


def prepare_python(cfg, app, out, version):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    copy_tree(ENGINES / "python", out)
    raw = json.dumps(runtime_config(cfg), ensure_ascii=False).replace("'''", "' ' '")
    (out / "alpha_config.py").write_text(f'"""Written by factory/prepare.py from apps/{app}/alpha.json."""\nimport json\n\n'
                                         f"CONFIG = json.loads(r'''{raw}''')\n", encoding="utf-8")
    (out / "assets").mkdir(exist_ok=True)
    icon_image(cfg, app, 1024).save(out / "assets" / "icon.png")
    overlay_custom(app, out)


def prepare_kotlin(cfg, app, out, version):
    out = Path(out)
    shutil.rmtree(out, ignore_errors=True)
    copy_tree(ENGINES / "kotlin" / "project", out)
    src = out / "app" / "src" / "main" / "java" / "app" / "main"
    src.mkdir(parents=True, exist_ok=True)
    copy_tree(ENGINES / "kotlin" / "src", src)
    rc = runtime_config(cfg)
    push = rc["backend"]["push"]
    copy_tree(ENGINES / "kotlin" / ("push" if push else "nopush"), src)
    gradle = out / "app" / "build.gradle.kts"
    g = gradle.read_text(encoding="utf-8")
    g = (g.replace("__APP_ID__", package_id(cfg, app)).replace("__VERSION_CODE__", str(version or 1))
         .replace("__VERSION_NAME__", f"1.0.{version or 1}"))
    if push:
        g = g.replace("    //ALPHA_PUSH_DEPS", '    implementation("com.google.firebase:firebase-messaging:24.1.0")')
    gradle.write_text(g, encoding="utf-8")
    manifest = out / "app" / "src" / "main" / "AndroidManifest.xml"
    m = manifest.read_text(encoding="utf-8")
    if push:
        m = m.replace("<!--ALPHA_PUSH_SERVICE-->", '<service android:name=".PushService" android:exported="false">\n'
                      '            <intent-filter><action android:name="com.google.firebase.MESSAGING_EVENT" /></intent-filter>\n'
                      "        </service>")
    if not store_build():
        m = m.replace("<!--ALPHA_INSTALL_PERMISSION-->", '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />')
    manifest.write_text(m, encoding="utf-8")
    res = out / "app" / "src" / "main" / "res"
    (res / "raw").mkdir(parents=True, exist_ok=True)
    (res / "raw" / "alpha_config.json").write_text(json.dumps(rc, ensure_ascii=False), encoding="utf-8")
    write_strings(res, cfg)
    write_mipmaps(cfg, app, res)
    # Custom Kotlin files go next to the engine's sources.
    custom = app_dir(app) / "custom"
    if custom.is_dir():
        for f in custom.rglob("*.kt"):
            shutil.copy2(f, src / f.name)
        print(f"Custom Kotlin code of {app} copied")


def prepare_php(cfg, app, out, version):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    copy_tree(ENGINES / "php", out)
    (out / "assets").mkdir(exist_ok=True)
    shutil.copy2(ENGINES / "html" / "style.css", out / "assets" / "style.css")
    raw = json.dumps(runtime_config(cfg), ensure_ascii=False, indent=1)
    if "\nJSON" in raw:
        raise SystemExit("config contains a line starting with JSON")
    (out / "config.php").write_text(f"<?php\n// Written by factory/prepare.py from apps/{app}/alpha.json.\n"
                                    f"return json_decode(<<<'JSON'\n{raw}\nJSON, true, 512, JSON_THROW_ON_ERROR);\n", encoding="utf-8")
    overlay_custom(app, out)


PREPARE = {"flutter": prepare_flutter, "html": prepare_html, "python": prepare_python, "kotlin": prepare_kotlin, "php": prepare_php}


def main(argv):
    if len(argv) >= 2 and argv[0] == "check":
        cfg = load(argv[1])
        errors = validate(cfg)
        for e in errors:
            print(f"::error::{argv[1]}: {e}")
        if errors:
            raise SystemExit(1)
        print(f"{argv[1]}: alpha.json OK ({cfg.get('lang')}, {len(cfg['tables'])} tables, backend {cfg['backend'].get('type')})")
        return
    if len(argv) >= 3 and argv[0] == "vendor":
        vendor(argv[1], argv[2])
        return
    if len(argv) >= 2 and argv[0] == "npm-list":
        print(" ".join(f"{p['name']}@{p['version']}" for p in libraries()["html"]["packages"]))
        return
    if len(argv) >= 3 and argv[0] == "android":
        # Name under the icon, icon and permissions of an Android project made by another tool (Capacitor).
        cfg = load(argv[1])
        main_dir = Path(argv[2])
        write_strings(main_dir / "res", cfg)
        write_mipmaps(cfg, argv[1], main_dir / "res")
        manifest_fix(main_dir / "AndroidManifest.xml", cfg, push_on(cfg))
        if len(argv) >= 4:
            gradle_app_id(argv[3], package_id(cfg, argv[1]), int(os.environ.get("VERSION") or 0) or None)
        print(f"Android name, icon and permissions of {argv[1]} applied")
        return
    if len(argv) >= 3 and argv[0] == "meta":
        cfg = load(argv[1])
        field = argv[2]
        value = {
            "lang": cfg.get("lang", ""),
            "label": label(cfg),
            "package": package_id(cfg, argv[1]),
            "role": cfg["app"]["role"],
            "server": str(cfg.get("server") or cfg["app"].get("server") or ""),
            "push": "true" if push_on(cfg) else "false",
            "backend": cfg["backend"].get("type", "none"),
        }.get(field)
        if value is None:
            raise SystemExit(f"unknown field {field}")
        print(value)
        return
    if len(argv) >= 4 and argv[0] == "project":
        lang, app, out = argv[1], argv[2], argv[3]
        cfg = load(app)
        if cfg.get("lang") != lang:
            raise SystemExit(f"apps/{app} is a {cfg.get('lang')} app, not {lang}")
        errors = validate(cfg)
        if errors:
            for e in errors:
                print(f"::error::{app}: {e}")
            raise SystemExit(1)
        version = int(os.environ.get("VERSION") or 0) or None
        PREPARE[lang](cfg, app, out, version)
        print(f"Prepared {app} ({lang}) in {out}: {label(cfg)} / {package_id(cfg, app)} / backend "
              f"{cfg['backend'].get('type')} / push {'on' if push_on(cfg) else 'off'}")
        return
    print(__doc__)
    raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
