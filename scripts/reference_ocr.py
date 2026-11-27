"""On-demand local OCR service access, used only by explicit setup actions."""
from pathlib import Path
import subprocess
import threading
import time
import requests
ROOT=Path(__file__).resolve().parents[1]
URL='http://127.0.0.1:8765'
_start_lock=threading.Lock()

def ensure_server():
    def ready():
        try:return requests.get(URL+'/ping',timeout=.5).status_code==200
        except requests.RequestException:return False
    if ready():return
    with _start_lock:
        if ready():return
        log=ROOT/'.task-output/ocr_startup.log';log.parent.mkdir(exist_ok=True)
        with log.open('a',encoding='utf-8') as output:
            subprocess.Popen([str(ROOT/'.venv/Scripts/pythonw.exe'),str(ROOT/'ocr_vision_server.py')],cwd=ROOT,stdout=output,stderr=output,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            if ready():return
            time.sleep(.25)
        raise RuntimeError('Local OCR did not start. See .task-output/ocr_startup.log')

def ocr_image(path):
    ensure_server()
    response=requests.post(URL+'/ocr_image',json={'path':str(Path(path).resolve())},timeout=30)
    response.raise_for_status();return response.json()

def read_indicator(name):
    ensure_server()
    from scripts.window_registry import hidden_macro_windows
    with hidden_macro_windows():
        response=requests.get(URL+'/indicator',params={'name':name,'preview':1},timeout=20)
    response.raise_for_status();return response.json()
