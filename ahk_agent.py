# ahk_agent.py
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import time
import requests

from agent_overlay import AgentOverlay, copy_to_clipboard, focus_roblox

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
OLLAMA_URL = "http://localhost:11434/api/chat"
OCR_SERVER = "http://127.0.0.1:8765"

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "").strip()
PROVIDER = os.environ.get("LLM_PROVIDER", "groq" if GROQ_API_KEY else "ollama").lower()
DEFAULT_MODEL = "openai/gpt-oss-120b" if PROVIDER == "groq" else "qwen3:4b"
MODEL = os.environ.get("LLM_MODEL", os.environ.get("OLLAMA_MODEL", DEFAULT_MODEL))
GROQ_FALLBACK_MODELS = ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"]

MAX_ITERS = int(os.environ.get("AGENT_MAX_ITERS", "6"))
ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "agent_memory.db"


# ============================================================================
# SQLITE PERSISTENT MEMORY (SESSIONS + PINNED NOTES)
# ============================================================================
def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            tool_calls_json TEXT,
            tool_call_id TEXT,
            created_at TEXT NOT NULL
        )"""
    )
    try:
        conn.execute("ALTER TABLE messages ADD COLUMN tool_call_id TEXT")
    except sqlite3.OperationalError:
        pass
    conn.execute(
        """CREATE TABLE IF NOT EXISTS notes (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )"""
    )
    conn.commit()
    return conn


def get_latest_session_id(conn) -> str:
    row = conn.execute("SELECT session_id FROM messages ORDER BY id DESC LIMIT 1").fetchone()
    return row[0] if row else datetime.now().strftime("session_%Y%m%d_%H%M%S")


def db_add_message(conn, session_id: str, msg: dict):
    tc_json = json.dumps(msg["tool_calls"]) if msg.get("tool_calls") else None
    conn.execute(
        "INSERT INTO messages (session_id, role, content, tool_calls_json, tool_call_id, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (
            session_id,
            msg["role"],
            msg.get("content") or "",
            tc_json,
            msg.get("tool_call_id"),
            datetime.now().isoformat(timespec="seconds"),
        ),
    )
    conn.commit()


def db_load_window(conn, session_id: str, max_msgs: int = 14) -> list:
    rows = conn.execute(
        "SELECT role, content, tool_calls_json, tool_call_id FROM messages WHERE session_id = ? ORDER BY id ASC",
        (session_id,),
    ).fetchall()
    msgs = []
    for role, content, tc_json, tc_id in rows:
        m = {"role": role, "content": content}
        if tc_json:
            m["tool_calls"] = json.loads(tc_json)
        if tc_id:
            m["tool_call_id"] = tc_id
        msgs.append(m)

    user_idxs = [i for i, m in enumerate(msgs) if m["role"] == "user"]
    if not user_idxs:
        return []

    if len(msgs) <= max_msgs:
        sliced = msgs[user_idxs[0]:]
    else:
        cutoff = len(msgs) - max_msgs
        valid_starts = [i for i in user_idxs if i >= cutoff]
        start_idx = valid_starts[0] if valid_starts else user_idxs[-1]
        sliced = msgs[start_idx:]

    # Self-heal any dangling assistant tool_calls from a previously interrupted turn
    healed = []
    i = 0
    while i < len(sliced):
        m = sliced[i]
        if m["role"] == "assistant" and m.get("tool_calls"):
            need_ids = {tc.get("id") for tc in m["tool_calls"] if tc.get("id")}
            j = i + 1
            got_ids = set()
            while j < len(sliced) and sliced[j]["role"] == "tool":
                got_ids.add(sliced[j].get("tool_call_id"))
                j += 1
            if need_ids and not need_ids.issubset(got_ids):
                i = j
                continue
        healed.append(m)
        i += 1
    return healed


def db_get_all_notes(conn) -> dict:
    rows = conn.execute("SELECT key, value FROM notes ORDER BY updated_at DESC").fetchall()
    return {k: v for k, v in rows}


def db_set_note(conn, key: str, value: str):
    conn.execute(
        """INSERT INTO notes (key, value, updated_at) VALUES (?, ?, ?)
           ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at""",
        (key, value, datetime.now().isoformat(timespec="seconds")),
    )
    conn.commit()


DB_CONN = init_db()
OVERLAY = None
LAST_OUTPUT = ""
LAST_REQ_TS = 0.0
RATE_INFO = {}
MODEL_COOLDOWNS = {}


# ============================================================================
# HELPERS & TOOLS
# ============================================================================
def find_ahk_exe() -> str:
    local_v2 = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "AutoHotkey" / "v2" / "AutoHotkey64.exe"
    candidates = [
        shutil.which("AutoHotkey64.exe"),
        shutil.which("AutoHotkey.exe"),
        r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        r"C:\Program Files\AutoHotkey\AutoHotkey.exe",
        str(local_v2),
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return ""


def _safe_path(rel_path: str) -> Path:
    p = (ROOT / rel_path).resolve()
    if ROOT not in p.parents and p != ROOT:
        raise ValueError(f"Path outside project root denied: {rel_path}")
    return p


def _normalize_llm_newlines(path: str, text: str) -> str:
    if path.lower().endswith(".ahk") and "\n" not in text and "\\n" in text:
        text = text.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\t", "\t")
    return text


def _numbered_source(src: str, max_lines: int = 80) -> str:
    lines = src.splitlines()[:max_lines]
    return "\n".join(f"{i + 1}: {ln}" for i, ln in enumerate(lines))


def _inject_warn_stdout(src: str) -> str:
    src = src.lstrip("\ufeff")
    if re.search(r"^\s*#Warn\b", src, flags=re.MULTILINE | re.IGNORECASE):
        return src
    if re.search(r"^\s*#Requires\b", src, flags=re.MULTILINE | re.IGNORECASE):
        return re.sub(r"(^\s*#Requires[^\r\n]*)", r"\1\n#Warn All, StdOut", src, count=1, flags=re.MULTILINE | re.IGNORECASE)
    return "#Warn All, StdOut\n" + src


def _parse_reset_seconds(raw: str) -> float:
    if not raw:
        return 5.0
    total = 0.0
    for val, unit in re.findall(r"(\d+(?:\.\d+)?)(ms|m|s)", raw.lower()):
        v = float(val)
        if unit == "m":
            total += v * 60.0
        elif unit == "ms":
            total += v / 1000.0
        else:
            total += v
    return total if total > 0 else 5.0


def query_ocr_state(debug: bool = False) -> dict:
    try:
        r = requests.get(f"{OCR_SERVER}/state?debug={'1' if debug else '0'}", timeout=20)
        r.raise_for_status()
        return r.json()
    except requests.ConnectionError:
        return {"ok": 0, "error": "OCR server not reachable at http://127.0.0.1:8765."}


def query_ocr_roi(roi: str, preset: str = "full", debug: bool = True) -> dict:
    try:
        r = requests.get(
            f"{OCR_SERVER}/ocr?roi={roi}&preset={preset}&debug={'1' if debug else '0'}",
            timeout=20,
        )
        r.raise_for_status()
        return r.json()
    except requests.ConnectionError:
        return {"ok": 0, "error": "OCR server not reachable at http://127.0.0.1:8765."}


def tool_list_files(subdir: str = ".") -> str:
    base = _safe_path(subdir)
    skip_dirs = {".venv", "__pycache__", ".git", "debug_ocr"}
    if subdir in {".", "./", ""}:
        skip_dirs.add("public")
    out = []
    for p in sorted(base.rglob("*")):
        if any(part in skip_dirs for part in p.parts):
            continue
        if p.is_file():
            out.append(str(p.relative_to(ROOT)))
    return json.dumps(out[:120], indent=2)


def tool_read_file(path: str, start_line: int = 1, end_line: int = 0, **kwargs) -> str:
    if "line_start" in kwargs:
        start_line = kwargs["line_start"]
    if "line_end" in kwargs:
        end_line = kwargs["line_end"]
    p = _safe_path(path)
    if not p.exists():
        return f"ERROR: File not found: {path}"
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    s = max(1, int(start_line))
    e = len(lines) if int(end_line) <= 0 else min(len(lines), int(end_line))
    e = min(e, s + 99)
    numbered = [f"{i}: {lines[i - 1]}" for i in range(s, e + 1)]
    return f"File: {path} (lines {s}-{e} of {len(lines)})\n" + "\n".join(numbered)


def tool_write_file(path: str, content: str) -> str:
    p = _safe_path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    content = _normalize_llm_newlines(path, content)
    p.write_text(content, encoding="utf-8")
    return f"Wrote {len(content)} chars ({len(content.splitlines())} lines) to {path}"


def tool_patch_file(path: str, old_text: str, new_text: str) -> str:
    p = _safe_path(path)
    if not p.exists():
        return f"ERROR: File not found: {path}"
    txt = p.read_text(encoding="utf-8")
    if old_text not in txt:
        return "ERROR: old_text not found verbatim in file."
    new_text = _normalize_llm_newlines(path, new_text)
    p.write_text(txt.replace(old_text, new_text, 1), encoding="utf-8")
    return f"Patched {path} successfully."


def tool_capture_roblox_and_ocr(roi: str = "state") -> str:
    focus_roblox()
    if roi == "state":
        res = query_ocr_state(debug=True)
        if res.get("ok"):
            db_set_note(DB_CONN, "last_ocr_map", f"ws_idx={res.get('ws_idx')} ({res.get('ws_name')}), in_tower={res.get('in_tower')}")
        return json.dumps(res, indent=2)
    return json.dumps(query_ocr_roi(roi, preset="full", debug=True), indent=2)


def _validate_ahk(ahk_exe: str, p: Path, src: str):
    tmp_p = p.parent / f"._validate_{p.name}"
    tmp_p.write_text(_inject_warn_stdout(src), encoding="utf-8")
    try:
        return subprocess.run(
            [ahk_exe, "/force", "/validate", "/ErrorStdOut=utf-8", str(tmp_p)],
            stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=8, cwd=str(ROOT),
        )
    finally:
        tmp_p.unlink(missing_ok=True)


def tool_test_ahk_script(script_path: str, run_live_seconds: int = 0) -> str:
    ahk_exe = find_ahk_exe()
    if not ahk_exe:
        return "ERROR: AutoHotkey v2 executable not found."
    p = _safe_path(script_path)
    if not p.exists():
        return f"ERROR: Script not found: {script_path}"

    src = p.read_text(encoding="utf-8", errors="replace")
    if re.search(r"^\s*(FileAppend|MsgBox|Sleep|Send|SendEvent)\s*,", src, flags=re.MULTILINE | re.IGNORECASE):
        return (
            "SYNTAX_ERROR: Found AHK v1 comma syntax (e.g. 'FileAppend, ...'). "
            'In AHK v2 use parentheses: FileAppend("Map=" mapIdx "`n", "*")\n'
            f"Current {script_path}:\n{_numbered_source(src)}"
        )

    try:
        chk = _validate_ahk(ahk_exe, p, src)
        if chk.returncode != 0:
            return f"SYNTAX_ERROR (code {chk.returncode}):\n{chk.stdout}\n{chk.stderr}\n{_numbered_source(src)}"
    except subprocess.TimeoutExpired:
        return f"SYNTAX_ERROR: /validate timed out (possible modal warning/dialog).\n{_numbered_source(src)}"
    except Exception as e:
        return f"ERROR running /validate: {e}"

    if run_live_seconds <= 0:
        db_set_note(DB_CONN, f"validated:{script_path}", "SYNTAX_OK")
        return f"SYNTAX_OK: {script_path} passed /validate with 0 errors."

    focus_roblox()
    before = query_ocr_state(debug=False)

    tmp_live = p.parent / f"._live_{p.name}"
    tmp_live.write_text(_inject_warn_stdout(src), encoding="utf-8")
    try:
        proc = subprocess.Popen(
            [ahk_exe, "/force", "/ErrorStdOut=utf-8", str(tmp_live)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=str(ROOT),
        )
        deadline = time.time() + min(15, max(1, int(run_live_seconds)))
        timed_out = False
        while time.time() < deadline and proc.poll() is None:
            time.sleep(0.2)
        if proc.poll() is None:
            timed_out = True
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        out, err = proc.communicate()
    finally:
        tmp_live.unlink(missing_ok=True)

    after = query_ocr_state(debug=False)
    return json.dumps({
        "syntax": "OK",
        "timed_out": timed_out,
        "exit_code": proc.returncode,
        "stdout": out,
        "stderr": err,
        "ocr_before": before,
        "ocr_after": after,
    }, indent=2)


def tool_save_note(key: str, value: str) -> str:
    db_set_note(DB_CONN, key, value)
    return f"Saved note '{key}' to SQLite."


def tool_get_notes() -> str:
    return json.dumps(db_get_all_notes(DB_CONN), indent=2)


TOOLS_SCHEMA = [
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "List project files.",
            "parameters": {"type": "object", "properties": {"subdir": {"type": "string"}}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read up to 100 lines of a project file.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "start_line": {"type": "integer"},
                    "end_line": {"type": "integer"},
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write or overwrite a file in the project.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}, "content": {"type": "string"}},
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "patch_file",
            "description": "Replace exact old_text with new_text in a file.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "old_text": {"type": "string"},
                    "new_text": {"type": "string"},
                },
                "required": ["path", "old_text", "new_text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "capture_roblox_and_ocr",
            "description": "Auto-screenshot Roblox and run binarized OCR (roi='state' for full game state).",
            "parameters": {"type": "object", "properties": {"roi": {"type": "string"}}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "test_ahk_script",
            "description": "Validate AHK v2 script and optionally run live for N seconds.",
            "parameters": {
                "type": "object",
                "properties": {
                    "script_path": {"type": "string"},
                    "run_live_seconds": {"type": "integer"},
                },
                "required": ["script_path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "save_note",
            "description": "Save a short note in SQLite.",
            "parameters": {
                "type": "object",
                "properties": {"key": {"type": "string"}, "value": {"type": "string"}},
                "required": ["key", "value"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_notes",
            "description": "Read saved notes from SQLite.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]

TOOL_DISPATCH = {
    "list_files": tool_list_files,
    "read_file": tool_read_file,
    "write_file": tool_write_file,
    "patch_file": tool_patch_file,
    "capture_roblox_and_ocr": tool_capture_roblox_and_ocr,
    "test_ahk_script": tool_test_ahk_script,
    "save_note": tool_save_note,
    "get_notes": tool_get_notes,
}


def build_system_prompt() -> str:
    notes = db_get_all_notes(DB_CONN)
    notes_txt = "\n".join(f"- {k}: {v}" for k, v in list(notes.items())[:10]) or "(none yet)"
    return f"""You are an AutoHotkey v2 & Roblox OCR engineer ({MAX_ITERS}-step budget/turn).
Rules:
1. Call tools directly without preambles. Keep replies concise to save tokens.
2. AutoHotkey v2 rules (see AHK_V2_GUIDE.md):
   - NEVER end lines with `;` (`;` is a comment in AHK).
   - NEVER use AHK v1 comma syntax (`FileAppend, ...`). Always use `(...)`:
     FileAppend("Map=" mapIdx " (" mapName ")`n", "*")
   - Always include `#Requires AutoHotkey v2.0` and `#Include "src/OcrVision.ahk"`.
   - Avoid naming variables `map`, `array`, `string`, `integer` (use `mapIdx`, `mapName`, `bossRaw`).
3. src/OcrVision.ahk exports:
   EnsureOcrServerRunning(), OcrDetectCurrentMap(&mapName), OcrIsOnWaystone(), OcrGetBossState(&rawText), OcrCheckBossBanner(&kind, &defeated, &youDefeated, &rawText), OcrIsInTower(), OcrIsFloorCleared(), OcrScanWorldMapVector().
4. After writing/editing an .ahk file, call test_ahk_script(script_path, run_live_seconds).
5. If unclear or failing twice, stop calling tools and ask 1-3 short questions.

Notes:
{notes_txt}
"""


def _sanitize_openai_messages(messages: list) -> list:
    cleaned = []
    for m in messages:
        role = m["role"]
        if role == "assistant":
            out = {"role": "assistant", "content": m.get("content") or ""}
            if m.get("tool_calls"):
                out["tool_calls"] = [
                    {
                        "id": tc.get("id") or f"call_{i}",
                        "type": "function",
                        "function": {
                            "name": tc["function"]["name"],
                            "arguments": tc["function"]["arguments"]
                            if isinstance(tc["function"]["arguments"], str)
                            else json.dumps(tc["function"].get("arguments") or {}),
                        },
                    }
                    for i, tc in enumerate(m["tool_calls"])
                ]
            cleaned.append(out)
        elif role == "tool":
            cleaned.append({
                "role": "tool",
                "tool_call_id": m.get("tool_call_id") or "call_0",
                "content": m.get("content") or "",
            })
        else:
            cleaned.append({"role": role, "content": m.get("content") or ""})
    return cleaned


def stream_groq_chat(messages: list, allow_tools: bool = True):
    global LAST_REQ_TS, RATE_INFO
    if not GROQ_API_KEY:
        raise RuntimeError("GROQ_API_KEY is missing. Set $env:GROQ_API_KEY first.")

    gap = time.time() - LAST_REQ_TS
    if gap < 1.5:
        time.sleep(1.5 - gap)

    now = time.time()
    all_models = [MODEL] + [m for m in GROQ_FALLBACK_MODELS if m != MODEL]
    models_to_try = [m for m in all_models if MODEL_COOLDOWNS.get(m, 0) <= now] or all_models
    clean_msgs = _sanitize_openai_messages(messages)

    for candidate_model in models_to_try:
        for attempt in range(2):
            payload = {
                "model": candidate_model,
                "messages": clean_msgs,
                "stream": True,
                "temperature": 0.2,
                "max_completion_tokens": 4096,
            }
            if candidate_model.startswith("openai/gpt-oss"):
                payload["reasoning_effort"] = "low"
            elif candidate_model.startswith("qwen/qwen3.8"):
                payload["reasoning_effort"] = "none"
            if allow_tools:
                payload["tools"] = TOOLS_SCHEMA
                payload["tool_choice"] = "auto"

            headers = {
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
            }
            LAST_REQ_TS = time.time()
            resp = requests.post(GROQ_URL, headers=headers, json=payload, stream=True, timeout=(10, 90))

            if resp.status_code == 429:
                wait_s = min(15.0, float(resp.headers.get("retry-after", "4")) + 0.5)
                resp.close()
                MODEL_COOLDOWNS[candidate_model] = time.time() + wait_s
                print(f"\n[Groq 429] Rate limited on {candidate_model} — rotating...")
                if OVERLAY:
                    OVERLAY.set_status("RATE WAIT", f"429 on {candidate_model}")
                break

            if resp.status_code != 200:
                err_body = resp.text[:400]
                resp.close()
                raise RuntimeError(f"Groq HTTP {resp.status_code}: {err_body}")

            rem_tok_raw = resp.headers.get("x-ratelimit-remaining-tokens", "?")
            rst_tok_raw = resp.headers.get("x-ratelimit-reset-tokens", "?")
            RATE_INFO = {
                "model": candidate_model,
                "rem_req": resp.headers.get("x-ratelimit-remaining-requests", "?"),
                "lim_req": resp.headers.get("x-ratelimit-limit-requests", "?"),
                "rst_req": resp.headers.get("x-ratelimit-reset-requests", "?"),
                "rem_tok": rem_tok_raw,
                "lim_tok": resp.headers.get("x-ratelimit-limit-tokens", "?"),
                "rst_tok": rst_tok_raw,
            }
            if rem_tok_raw.isdigit() and int(rem_tok_raw) < 1200:
                MODEL_COOLDOWNS[candidate_model] = time.time() + min(45.0, _parse_reset_seconds(rst_tok_raw))

            content_parts = []
            tc_acc = {}
            printed_header = False

            with resp:
                for raw_line in resp.iter_lines(decode_unicode=True):
                    if not raw_line or not raw_line.startswith("data:"):
                        continue
                    data_str = raw_line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    chunk = json.loads(data_str)
                    choices = chunk.get("choices") or []
                    if not choices:
                        continue
                    delta = choices[0].get("delta") or {}

                    if delta.get("content"):
                        if not printed_header:
                            print("\nAgent> ", end="", flush=True)
                            printed_header = True
                        print(delta["content"], end="", flush=True)
                        content_parts.append(delta["content"])
                        if OVERLAY:
                            OVERLAY.set_preview("".join(content_parts))

                    for tc in delta.get("tool_calls") or []:
                        idx = tc.get("index", 0)
                        entry = tc_acc.setdefault(idx, {
                            "id": f"call_{idx}",
                            "type": "function",
                            "function": {"name": "", "arguments": ""},
                        })
                        if tc.get("id"):
                            entry["id"] = tc["id"]
                        fn = tc.get("function") or {}
                        if fn.get("name"):
                            entry["function"]["name"] += fn["name"]
                        if fn.get("arguments"):
                            entry["function"]["arguments"] += fn["arguments"]

            if printed_header:
                print()

            tool_calls = [tc_acc[i] for i in sorted(tc_acc)] if allow_tools else []
            out_msg = {"role": "assistant", "content": "".join(content_parts)}
            if tool_calls:
                out_msg["tool_calls"] = tool_calls
            return out_msg

    soonest = min(MODEL_COOLDOWNS.values()) - time.time() if MODEL_COOLDOWNS else 5.0
    if 0 < soonest <= 20:
        time.sleep(soonest + 0.5)
        MODEL_COOLDOWNS.clear()
        return stream_groq_chat(messages, allow_tools=allow_tools)
    raise RuntimeError("All Groq free-tier models hit rate limits (429). Wait ~30s and retry.")


def stream_ollama_chat(messages: list, allow_tools: bool = True):
    payload = {
        "model": MODEL,
        "messages": messages,
        "stream": True,
        "keep_alive": "15m",
        "options": {"num_ctx": 6144, "num_predict": 2048, "temperature": 0.1},
    }
    if allow_tools:
        payload["tools"] = TOOLS_SCHEMA
    if MODEL.startswith("qwen3"):
        payload["think"] = False

    content_parts, tool_calls, printed_header = [], [], False
    with requests.post(OLLAMA_URL, json=payload, stream=True, timeout=(10, 300)) as resp:
        resp.raise_for_status()
        for line in resp.iter_lines(decode_unicode=True):
            if not line:
                continue
            chunk = json.loads(line)
            msg = chunk.get("message") or {}
            if msg.get("content"):
                if not printed_header:
                    print("\nAgent> ", end="", flush=True)
                    printed_header = True
                print(msg["content"], end="", flush=True)
                content_parts.append(msg["content"])
                if OVERLAY:
                    OVERLAY.set_preview("".join(content_parts))
            if allow_tools and msg.get("tool_calls"):
                tool_calls.extend(msg["tool_calls"])
            if chunk.get("done"):
                break
    if printed_header:
        print()
    out_msg = {"role": "assistant", "content": "".join(content_parts)}
    if tool_calls:
        out_msg["tool_calls"] = tool_calls
    return out_msg


def stream_chat(messages: list, allow_tools: bool = True):
    if PROVIDER == "groq":
        return stream_groq_chat(messages, allow_tools=allow_tools)
    return stream_ollama_chat(messages, allow_tools=allow_tools)


def _finish_turn(final_text: str, tool_summaries: list, status_label: str = "COPIED ✓"):
    global LAST_OUTPUT
    copy_payload = final_text.strip()
    if tool_summaries:
        copy_payload = copy_payload + "\n\n[Tool Runs]\n" + "\n".join(tool_summaries)

    limit_line = ""
    if RATE_INFO:
        limit_line = (
            f"model={RATE_INFO['model']} | "
            f"req={RATE_INFO['rem_req']}/{RATE_INFO['lim_req']} (reset {RATE_INFO['rst_req']}) | "
            f"tok={RATE_INFO['rem_tok']}/{RATE_INFO['lim_tok']} (reset {RATE_INFO['rst_tok']})"
        )
        copy_payload = copy_payload + "\n\n[Groq Limits]\n" + limit_line

    LAST_OUTPUT = copy_payload
    copied = copy_to_clipboard(copy_payload)
    if OVERLAY:
        OVERLAY.set_last_output(copy_payload)
        OVERLAY.set_status(status_label if copied else "IDLE", "Done — copied to clipboard!" if copied else status_label)
    if limit_line:
        print(f"[Groq Limits] {limit_line}")
    if copied:
        print(f"[Clipboard] Auto-copied output ({len(copy_payload)} chars).")


def run_agent_turn(session_id: str, user_text: str):
    db_add_message(DB_CONN, session_id, {"role": "user", "content": user_text})
    seen_calls = set()
    error_count = 0
    tool_summaries = []

    focus_roblox()
    if OVERLAY:
        OVERLAY.dock_to_roblox()
        OVERLAY.set_status("THINKING", f"Goal: {user_text[:80]}")
        OVERLAY.log(f"> {user_text}")

    for step in range(1, MAX_ITERS + 1):
        if OVERLAY:
            OVERLAY.set_status("THINKING", f"Step {step}/{MAX_ITERS}: Calling {PROVIDER}...")
        window = [{"role": "system", "content": build_system_prompt()}] + db_load_window(DB_CONN, session_id, max_msgs=14)
        msg = stream_chat(window, allow_tools=True)
        db_add_message(DB_CONN, session_id, msg)

        tool_calls = msg.get("tool_calls") or []
        if not tool_calls:
            txt = (msg.get("content") or "").strip()
            if not txt and tool_summaries:
                db_add_message(DB_CONN, session_id, {"role": "user", "content": "Summarize the tool outputs above clearly in plain text."})
                w2 = [{"role": "system", "content": build_system_prompt()}] + db_load_window(DB_CONN, session_id, max_msgs=14)
                msg2 = stream_chat(w2, allow_tools=False)
                db_add_message(DB_CONN, session_id, msg2)
                txt = (msg2.get("content") or "").strip()
            _finish_turn(txt, tool_summaries)
            return

        batch_sigs = set()
        for idx, tc in enumerate(tool_calls):
            tc_id = tc.get("id") or f"call_{idx}"
            fn = tc["function"]["name"]
            raw_args = tc["function"].get("arguments") or {}

            parse_err = None
            if isinstance(raw_args, str):
                try:
                    args = json.loads(raw_args)
                except json.JSONDecodeError as je:
                    args = {}
                    parse_err = f"TOOL_ERROR: Malformed JSON arguments ({je}). Retry with valid JSON or smaller patch_file."
            else:
                args = raw_args

            if parse_err:
                result = parse_err
                print(f"  [bad args] {fn}: {parse_err}")
                if OVERLAY:
                    OVERLAY.log(f"[bad args] {fn}")
            else:
                call_sig = (fn, json.dumps(args, sort_keys=True))
                if call_sig in batch_sigs:
                    db_add_message(DB_CONN, session_id, {"role": "tool", "tool_call_id": tc_id, "content": "Duplicate skipped."})
                    continue
                batch_sigs.add(call_sig)

                if call_sig in seen_calls:
                    result = f"SKIPPED_REPEAT_TOOL_CALL: {fn}({args}) already ran without file edits."
                    print(f"  [skipped repeat] {fn}({args})")
                else:
                    seen_calls.add(call_sig)
                    print(f"  [tool {step}/{MAX_ITERS}] {fn}({args})")
                    if OVERLAY:
                        st_label = "TESTING" if fn == "test_ahk_script" else "TOOL"
                        OVERLAY.set_status(st_label, f"[{step}/{MAX_ITERS}] {fn}({args})")
                        OVERLAY.log(f"[{step}/{MAX_ITERS}] {fn}({args})")
                    try:
                        result = str(TOOL_DISPATCH[fn](**args))
                    except Exception as e:
                        result = f"TOOL_ERROR: {e}"

                    if fn in {"write_file", "patch_file"} and not result.startswith("ERROR:"):
                        seen_calls = {s for s in seen_calls if s[0] not in {"test_ahk_script", "read_file"}}

            if any(err in result for err in ("ERROR:", "SYNTAX_ERROR", "TOOL_ERROR")):
                error_count += 1
                if error_count >= 2:
                    result += "\n[HINT] Multiple errors occurred. Stop calling tools and ask the user what is unclear."

            if len(result) > 2500:
                result = result[:2500] + "\n...[truncated]..."

            short_res = result.replace("\n", " ")[:180]
            tool_summaries.append(f"- {fn}: {short_res}")
            if OVERLAY:
                OVERLAY.log(f"  -> {short_res}")

            db_add_message(DB_CONN, session_id, {"role": "tool", "tool_call_id": tc_id, "content": result})

    print(f"\n[Cap] Reached {MAX_ITERS}/{MAX_ITERS} iterations. Asking agent why it stalled...")
    if OVERLAY:
        OVERLAY.set_status("PAUSED", f"Cap {MAX_ITERS}/{MAX_ITERS} reached")

    diag_prompt = (
        f"You hit the {MAX_ITERS}-iteration limit without finishing. Briefly explain: "
        "(1) what succeeded, (2) why you stalled, and (3) 1-3 short questions to clarify."
    )
    db_add_message(DB_CONN, session_id, {"role": "user", "content": diag_prompt})
    window = [{"role": "system", "content": build_system_prompt()}] + db_load_window(DB_CONN, session_id, max_msgs=14)
    diag_msg = stream_chat(window, allow_tools=False)
    db_add_message(DB_CONN, session_id, diag_msg)
    _finish_turn(diag_msg.get("content", ""), tool_summaries, status_label="PAUSED")


def main():
    global OVERLAY
    session_id = get_latest_session_id(DB_CONN)
    print(f"AHK + OCR Agent ready (provider={PROVIDER}, model={MODEL}, max_iters={MAX_ITERS}, db={DB_PATH.name})")
    try:
        ping = requests.get(f"{OCR_SERVER}/ping", timeout=3).json()
        print(f"OCR Server connected (Roblox windows found: {ping.get('windows', 0)})")
    except Exception:
        print("WARNING: OCR Server not running at http://127.0.0.1:8765 — start ocr_vision_server.py first.")
    print("Commands: 'new' (fresh session), 'notes', 'history', 'copy', 'exit'\n")

    OVERLAY = AgentOverlay(f"{PROVIDER}:{MODEL}")
    OVERLAY.start()

    while True:
        try:
            user_in = input("You> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not user_in:
            continue
        cmd = user_in.lower()
        if cmd in {"exit", "quit"}:
            break
        if cmd == "new":
            session_id = datetime.now().strftime("session_%Y%m%d_%H%M%S")
            print(f"Started fresh session: {session_id} (SQLite notes kept).\n")
            continue
        if cmd == "notes":
            print(json.dumps(db_get_all_notes(DB_CONN), indent=2) + "\n")
            continue
        if cmd == "history":
            for m in db_load_window(DB_CONN, session_id, max_msgs=8):
                print(f"[{m['role']}] {m['content'][:160]}")
            print()
            continue
        if cmd == "copy":
            if copy_to_clipboard(LAST_OUTPUT):
                print(f"[Clipboard] Re-copied last output ({len(LAST_OUTPUT)} chars).\n")
            else:
                print("[Clipboard] Nothing to copy yet.\n")
            continue

        try:
            run_agent_turn(session_id, user_in)
        except Exception as e:
            print(f"\n[Error] {e}\n")
            if OVERLAY:
                OVERLAY.set_status("ERROR", str(e)[:100])
                OVERLAY.log(f"[error] {e}")
        print()


if __name__ == "__main__":
    main()