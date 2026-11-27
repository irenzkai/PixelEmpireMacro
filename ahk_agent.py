"""Local overlay/history integration. Groq performs text analysis only; no game tools.
VS Code conversations are not captured by this process. Only explicit local events
and prompts sent to this CLI/localhost endpoint enter SQLite.
"""
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json
import os
import sqlite3
import threading
import uuid
import requests
from contextlib import contextmanager
from agent_overlay import AgentOverlay

ROOT=Path(__file__).resolve().parent
DB_PATH=ROOT/'agent_memory.db'
GROQ_API_KEY=os.environ.get('GROQ_API_KEY','').strip()
MODEL=os.environ.get('LLM_MODEL','openai/gpt-oss-20b')
OVERLAY=None


@contextmanager
def connect():
    conn=sqlite3.connect(DB_PATH,timeout=10)
    conn.executescript('''CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,session_id TEXT NOT NULL,
        role TEXT NOT NULL,content TEXT NOT NULL,tool_calls_json TEXT,
        tool_call_id TEXT,created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS notes (key TEXT PRIMARY KEY,value TEXT NOT NULL,updated_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS local_agent_events (
        id INTEGER PRIMARY KEY,provider TEXT NOT NULL,kind TEXT NOT NULL,text TEXT NOT NULL,created_at TEXT NOT NULL);''')
    try:
        with conn:yield conn
    finally:conn.close()


def history():
    with connect() as conn:
        rows=conn.execute('SELECT provider,kind,text,created_at FROM local_agent_events ORDER BY id DESC LIMIT 8').fetchall()
        legacy=conn.execute("SELECT role,substr(content,1,220),created_at FROM messages WHERE role IN ('user','assistant') ORDER BY id DESC LIMIT 4").fetchall()
        notes=conn.execute('SELECT key,substr(value,1,240) FROM notes ORDER BY updated_at DESC LIMIT 5').fetchall()
    lines=[f'[{provider}] {kind}: {text[:240]}' for provider,kind,text,_ in reversed(rows)]
    lines += [f'[legacy local; provider unknown] {role}: {text}' for role,text,_ in reversed(legacy)]
    lines += [f'[note] {key}: {value}' for key,value in notes]
    return '\n'.join(lines)


def refresh_history():
    path=ROOT/'.task-output/recent_history.json';path.parent.mkdir(exist_ok=True)
    temporary=path.with_name('history_'+uuid.uuid4().hex+'.tmp');temporary.write_text(history(),encoding='utf-8');temporary.replace(path)


def event(provider,kind,text):
    text=str(text)[:4000]
    if GROQ_API_KEY:text=text.replace(GROQ_API_KEY,'[REDACTED]')
    with connect() as conn:
        conn.execute('INSERT INTO local_agent_events(provider,kind,text,created_at) VALUES (?,?,?,?)',
                     (str(provider)[:40],str(kind)[:40],text,datetime.now().astimezone().isoformat(timespec='seconds')))
    refresh_history()
    if OVERLAY:OVERLAY.log(f'[{provider}] {text}')


def analyze(text):
    if not GROQ_API_KEY:raise RuntimeError('Set GROQ_API_KEY to use optional analysis')
    event('user','analysis request',text)
    response=requests.post('https://api.groq.com/openai/v1/chat/completions',headers={'Authorization':'Bearer '+GROQ_API_KEY},
        json={'model':MODEL,'max_tokens':450,'messages':[
            {'role':'system','content':'Analyze only the evidence explicitly supplied in this request. No tools or game actions. Routes are approximate. Ask the user for manual confirmation when uncertain.'},
            {'role':'user','content':text[:6000]}]},timeout=40)
    response.raise_for_status();answer=response.json()['choices'][0]['message']['content']
    event('Groq:'+MODEL,'analysis',answer)
    return answer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path!='/health':self.send_error(404);return
        ready=OVERLAY is not None and OVERLAY._ui_ready.is_set()
        self.send_response(200 if ready else 503);self.end_headers()
        self.wfile.write(('PixelEmpireOverlay/2 pid='+str(os.getpid())).encode())
    def do_POST(self):
        try:
            length=int(self.headers.get('Content-Length',0))
            if length>16000:self.send_error(413);return
            data=json.loads(self.rfile.read(length) or b'{}')
            action=self.path.strip('/') or data.get('action','log')
            if action in ('restore','show','hide','toggle','record','setup'):
                if not OVERLAY.control('show' if action=='restore' else action):
                    raise RuntimeError('Overlay window did not acknowledge '+action)
            elif action in ('event','log','request'):
                provider=data.get('provider',data.get('who','local'))
                event(provider,action,data.get('text',''))
                if action=='request':OVERLAY.set_status('MANUAL',data.get('text',''))
            else:self.send_error(404);return
            self.send_response(200);self.end_headers();self.wfile.write(b'ok')
        except Exception as exc:
            error=ROOT/'.task-output/agent_startup_error.txt';error.parent.mkdir(exist_ok=True)
            error.write_text(type(exc).__name__+': '+str(exc),encoding='utf-8')
            self.send_error(500,'Local overlay operation failed; see .task-output/agent_startup_error.txt')
    def log_message(self,*args):pass


def watch_recordings():
    last=None
    while True:
        try:
            state=json.loads((ROOT/'.task-output/demo_status.json').read_text(encoding='utf-8-sig'))
            path=state.get('path')
            if path and path!=last and not state.get('active'):
                last=path;event('AHK','recording',json.dumps(state))
        except (OSError,ValueError):pass
        threading.Event().wait(1)


def main():
    global OVERLAY
    parser=argparse.ArgumentParser();parser.add_argument('--analyze');args=parser.parse_args()
    if args.analyze:print(analyze(args.analyze));return
    import ctypes
    from ctypes import wintypes
    kernel=ctypes.windll.kernel32;kernel.CreateMutexW.restype=wintypes.HANDLE
    mutex=kernel.CreateMutexW(None,False,'Local\\PixelEmpireOverlay_'+str(ROOT).replace('\\','_').replace(':','_'))
    if kernel.GetLastError()==183:raise RuntimeError('An overlay helper already exists. Close the old helper and use Show again.')
    OVERLAY=AgentOverlay('Local history | optional Groq analysis');OVERLAY.start()
    refresh_history()
    threading.Thread(target=watch_recordings,daemon=True).start()
    # Existing AHK NavProgress callers retain port 8766; GUI controls use 8767.
    for port in (8767,8766):
        try:
            server=ThreadingHTTPServer(('127.0.0.1',port),Handler)
            threading.Thread(target=server.serve_forever,daemon=True).start()
        except OSError:
            if port==8767:raise RuntimeError('Port 8767 is occupied. Close the old overlay helper, then Show again.')
            OVERLAY.log('[local] Optional progress port 8766 occupied; overlay controls remain on 8767.')
    (ROOT/'.task-output/agent_startup_error.txt').unlink(missing_ok=True)
    OVERLAY.set_status('MANUAL','Manual checklist below. Communicate through VS Code. Runtime awaits your testing.')
    threading.Event().wait()

if __name__=='__main__':main()
