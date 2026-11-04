#!/usr/bin/env python3
"""Signs an APK (and an AAB) with the repository's permanent key, so every new build installs as an update.

    python factory/sign.py <file.apk> [<file.aab>]

The key: the ALPHA_KEYSTORE_B64 secret (PKCS12, base64) with ALPHA_KEYSTORE_PASSWORD, or signing/alpha.p12 in this
repository (made on the first build; keep the repository private, or move the key into the secret).
"""
import base64
import glob
import json
import os
import secrets
import shutil
import string
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_KEY = ROOT / "signing" / "alpha.p12"
REPO_INFO = ROOT / "signing" / "alpha.json"
ALIAS = "alpha"


def build_tool(name):
    home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or "/usr/local/lib/android/sdk"
    found = sorted(glob.glob(f"{home}/build-tools/*/{name}"))
    if not found:
        raise SystemExit(f"{name} not found in {home}/build-tools")
    return found[-1]


def keystore():
    b64 = os.environ.get("ALPHA_KEYSTORE_B64", "").strip()
    if b64:
        path = Path(tempfile.mkdtemp()) / "key.p12"
        path.write_bytes(base64.b64decode(b64))
        pw = os.environ.get("ALPHA_KEYSTORE_PASSWORD", "")
        return path, pw, os.environ.get("ALPHA_KEY_ALIAS", ALIAS)
    if not REPO_KEY.exists():
        REPO_KEY.parent.mkdir(exist_ok=True)
        pw = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
        subprocess.run(["keytool", "-genkeypair", "-keystore", str(REPO_KEY), "-storetype", "PKCS12", "-storepass", pw,
                        "-alias", ALIAS, "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
                        "-dname", "CN=Alpha, O=Alpha Apps, C=SD"], check=True, capture_output=True)
        REPO_INFO.write_text(json.dumps({"alias": ALIAS, "password": pw, "note": "Permanent signing key of every app built in this repository. Keep the repository private."}, indent=1) + "\n")
        print("::notice::A permanent signing key was created (signing/alpha.p12). Every app of this repository is signed with it from now on.")
    info = json.loads(REPO_INFO.read_text())
    return REPO_KEY, info["password"], info.get("alias", ALIAS)


def sign_apk(apk, ks, pw, alias):
    aligned = apk + ".aligned"
    subprocess.run([build_tool("zipalign"), "-f", "-p", "4", apk, aligned], check=True)
    subprocess.run([build_tool("apksigner"), "sign", "--ks", str(ks), "--ks-type", "PKCS12", "--ks-pass", f"pass:{pw}",
                    "--ks-key-alias", alias, "--out", apk, aligned], check=True)
    os.remove(aligned)
    subprocess.run([build_tool("apksigner"), "verify", apk], check=True)
    print(f"Signed {apk}")


def sign_aab(aab, ks, pw, alias):
    subprocess.run(["jarsigner", "-keystore", str(ks), "-storetype", "PKCS12", "-storepass", pw, "-sigalg", "SHA256withRSA",
                    "-digestalg", "SHA-256", aab, alias], check=True, capture_output=True)
    print(f"Signed {aab}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    ks, pw, alias = keystore()
    for f in sys.argv[1:]:
        if f.endswith(".apk"):
            sign_apk(f, ks, pw, alias)
        elif f.endswith(".aab"):
            sign_aab(f, ks, pw, alias)
