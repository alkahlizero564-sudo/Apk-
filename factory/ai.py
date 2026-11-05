"""One client for the AI models Alpha uses in GitHub Actions: Claude (ANTHROPIC_API_KEY) and Gemini
(GEMINI_API_KEY, _2, _3, _4). Tries the chosen provider first, then the other one, rotating keys and models on
quota errors, so a build keeps going when one key runs out.

    from ai import ask
    text = ask(prompt, system="...")            # plain text answer
"""
import json
import os
import time
import urllib.error
import urllib.request

CLAUDE_MODELS = [m for m in [os.environ.get("CLAUDE_MODEL"), "claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"] if m]
GEMINI_MODELS = [m for m in [os.environ.get("GEMINI_MODEL"), "gemini-3.8-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite"] if m]


class AIError(Exception):
    pass


def _post(url, body, headers, timeout=600):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise AIError(f"{e.code}: {e.read().decode('utf-8', 'replace')[:400]}")
    except Exception as e:  # network / timeout
        raise AIError(f"0: {e}")


def _claude(model, key, prompt, system, max_tokens):
    data = _post("https://api.anthropic.com/v1/messages",
                 {"model": model, "max_tokens": max_tokens, "system": system or "You are an expert mobile app engineer.",
                  "messages": [{"role": "user", "content": prompt}]},
                 {"x-api-key": key, "anthropic-version": "2023-06-01"})
    return "".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text")


def _gemini(model, key, prompt, system, max_tokens):
    body = {"contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.3, "maxOutputTokens": max_tokens},
            # App ideas about security, health and the like must not be cut off as "unsafe".
            "safetySettings": [{"category": c, "threshold": "BLOCK_ONLY_HIGH"} for c in (
                "HARM_CATEGORY_HARASSMENT", "HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_SEXUALLY_EXPLICIT", "HARM_CATEGORY_DANGEROUS_CONTENT")]}
    if system:
        body["systemInstruction"] = {"parts": [{"text": system}]}
    data = _post(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", body, {"x-goog-api-key": key})
    try:
        return "".join(p.get("text", "") for p in data["candidates"][0]["content"]["parts"])
    except (KeyError, IndexError):
        raise AIError("-1: empty or blocked answer")


def providers():
    out = []
    claude_keys = [k for k in [os.environ.get("ANTHROPIC_API_KEY")] if k]
    gemini_keys = [os.environ.get(n) for n in ("GEMINI_API_KEY", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3", "GEMINI_API_KEY_4")]
    gemini_keys = [k for k in gemini_keys if k]
    if claude_keys:
        out.append(("claude", _claude, CLAUDE_MODELS, claude_keys))
    if gemini_keys:
        out.append(("gemini", _gemini, GEMINI_MODELS, gemini_keys))
    if os.environ.get("AI_PROVIDER") == "gemini":
        out.reverse()
    return out


def available():
    return bool(providers())


def ask(prompt, system=None, max_tokens=32000, rounds=2):
    provs = providers()
    if not provs:
        raise AIError("No AI key: add a Claude or Gemini key in Alpha > الإعدادات (it is saved as a repository secret).")
    last = ""
    dead = set()
    for round_no in range(rounds):
        for name, fn, models, keys in provs:
            for model in dict.fromkeys(models):
                for i, key in enumerate(keys):
                    if (name, model, i) in dead:
                        continue
                    try:
                        text = fn(model, key, prompt, system, max_tokens)
                        if text.strip():
                            print(f"AI: {name} {model}", flush=True)
                            return text
                    except AIError as e:
                        last = str(e)
                        code = last.split(":", 1)[0]
                        print(f"AI {name} {model} key#{i + 1} failed: {last[:200]}", flush=True)
                        if code in ("400", "401", "403", "404"):
                            dead.add((name, model, i))
        time.sleep(20 * (round_no + 1))
    raise AIError(f"Every AI model failed. Last error: {last[:300]}")


def code_blocks(text):
    """{path: code} from blocks written as  ```lang path/to/file  ...  ```  (path optional -> key = lang)."""
    import re
    out = {}
    for m in re.finditer(r"```([\w+.-]*)[ \t]*([^\n`]*)\n(.*?)\n```", text, re.S):
        lang, path, code = m.group(1).strip().lower(), m.group(2).strip(), m.group(3)
        out[path or lang] = code.rstrip() + "\n"
    return out
