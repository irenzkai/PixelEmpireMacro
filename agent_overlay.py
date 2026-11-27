# agent_overlay.py
import ctypes
from ctypes import wintypes
import os
import queue
import threading
import tkinter as tk
from scripts.tk_runtime import configure_tk
configure_tk()
from datetime import datetime
import json
from pathlib import Path
import subprocess
import configparser

user32 = ctypes.windll.user32
user32.SendMessageTimeoutW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM,wintypes.UINT,wintypes.UINT,ctypes.POINTER(ctypes.c_size_t)]
user32.SendMessageTimeoutW.restype=ctypes.c_ssize_t
user32.GetAncestor.argtypes = [wintypes.HWND, wintypes.UINT]
user32.GetAncestor.restype = wintypes.HWND
kernel32 = ctypes.windll.kernel32
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalLock.restype = ctypes.c_void_p
kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
kernel32.GlobalUnlock.restype = wintypes.BOOL
kernel32.GetCurrentThreadId.argtypes = []
kernel32.GetCurrentThreadId.restype = wintypes.DWORD

user32.OpenClipboard.argtypes = [wintypes.HWND]
user32.EmptyClipboard.argtypes = []
user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
user32.SetClipboardData.restype = wintypes.HANDLE
user32.CloseClipboard.argtypes = []
user32.GetForegroundWindow.argtypes = []
user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowThreadProcessId.restype = wintypes.DWORD
user32.AttachThreadInput.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL]
user32.AttachThreadInput.restype = wintypes.BOOL
user32.BringWindowToTop.argtypes = [wintypes.HWND]
user32.BringWindowToTop.restype = wintypes.BOOL
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.SwitchToThisWindow.argtypes = [wintypes.HWND, wintypes.BOOL]
user32.SwitchToThisWindow.restype = None
user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
user32.IsIconic.argtypes = [wintypes.HWND]

CF_UNICODETEXT = 13
GMEM_MOVEABLE = 0x0002
GWL_EXSTYLE = -20
WS_EX_TOOLWINDOW = 0x00000080
WS_EX_NOACTIVATE = 0x08000000
SW_RESTORE = 9


def copy_to_clipboard(text: str) -> bool:
    if not text:
        return False
    norm = text.replace("\r\n", "\n").replace("\n", "\r\n")
    raw = norm.encode("utf-16-le") + b"\x00\x00"
    h_mem = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(raw))
    if not h_mem:
        return False
    ptr = kernel32.GlobalLock(h_mem)
    if not ptr:
        return False
    ctypes.memmove(ptr, raw, len(raw))
    kernel32.GlobalUnlock(h_mem)

    for _ in range(5):
        if user32.OpenClipboard(None):
            try:
                user32.EmptyClipboard()
                if user32.SetClipboardData(CF_UNICODETEXT, h_mem):
                    return True
            finally:
                user32.CloseClipboard()
    return False


def recording_summary(path, base):
    """Read only the selected local recording; never copy or transmit it here."""
    path = Path(path).resolve()
    folder = (Path(base)/'routes/demonstrations').resolve()
    if not path.is_relative_to(folder) or path.suffix.lower() != '.ini':
        raise ValueError('Recording must be a local demonstration INI')
    raw = path.read_bytes()
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read_string(raw.decode('utf-16') if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else raw.decode('utf-8-sig'))
    meta = cfg['Meta']
    milliseconds = meta.get('duration_ms')
    duration = f'{int(milliseconds)/1000:.2f} s' if milliseconds is not None else 'not recorded (legacy file)'
    status = meta.get('completion', 'unverified (legacy file)')
    details = [f'Recording: {path.name}', f'Path: {path}',
               f'Duration: {duration}', f'Status: {status}',
               'Stop reason: '+meta.get('stop_reason', 'unknown')]
    for key, label in (('map', 'Map'), ('subarea', 'Subarea'), ('start_landmark', 'Start'),
                       ('destination', 'Destination'), ('arrival_indicator', 'Arrival indicator')):
        if meta.get(key):
            details.append(label+': '+meta[key])
    return '\n'.join(details)


class _RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class _POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def _proc_name(pid: int) -> str:
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(512)
        sz = wintypes.DWORD(512)
        if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(sz)):
            return os.path.basename(buf.value).lower()
    finally:
        kernel32.CloseHandle(h)
    return ""


def _find_roblox_box():
    boxes = []
    EnumProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def cb(hwnd, _lp):
        if not user32.IsWindowVisible(hwnd):
            return True
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        proc = _proc_name(pid.value)

        length = user32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buf, length + 1)
        if proc == "robloxplayerbeta.exe" or buf.value == "Roblox":
            rc = _RECT()
            if user32.GetClientRect(hwnd, ctypes.byref(rc)):
                w, h = rc.right - rc.left, rc.bottom - rc.top
                if w >= 300 and h >= 200:
                    pt = _POINT(0, 0)
                    user32.ClientToScreen(hwnd, ctypes.byref(pt))
                    boxes.append((hwnd, pt.x, pt.y, w, h))
        return True

    user32.EnumWindows(EnumProc(cb), 0)
    boxes.sort(key=lambda b: b[1])
    return boxes[0] if boxes else None


def focus_roblox() -> bool:
    """Restores and reliably brings Roblox to foreground even past Windows 11 foreground lock."""
    box = _find_roblox_box()
    if not box:
        return False
    hwnd = box[0]
    try:
        if user32.IsIconic(hwnd):
            user32.ShowWindow(hwnd, SW_RESTORE)
        fg = user32.GetForegroundWindow()
        if fg == hwnd:
            return True
        fg_tid = user32.GetWindowThreadProcessId(fg, None) if fg else 0
        cur_tid = kernel32.GetCurrentThreadId()
        attached = False
        if fg_tid and fg_tid != cur_tid:
            attached = bool(user32.AttachThreadInput(cur_tid, fg_tid, True))
        try:
            user32.BringWindowToTop(hwnd)
            user32.SetForegroundWindow(hwnd)
        finally:
            if attached:
                user32.AttachThreadInput(cur_tid, fg_tid, False)
        if user32.GetForegroundWindow() != hwnd:
            user32.SwitchToThisWindow(hwnd, True)
        return True
    except Exception:
        return False


class AgentOverlay:
    def __init__(self, model_name: str):
        self.model_name = model_name
        self._q = queue.Queue()
        self._last_output = ""
        self._recording_summary = ""
        self._custom_pos = False
        self.recorder_process = None
        self._ui_ready = threading.Event()
        self._restore_error = None
        self._startup_done = threading.Event()
        self._startup_error = None
        self._thread = threading.Thread(target=self._ui_entry, daemon=True)

    def _ui_entry(self):
        try:
            self._run_ui()
        except Exception as exc:
            self._startup_error = str(exc)
        finally:
            self._ui_ready.clear()
            self._startup_done.set()

    def start(self):
        if not self._thread.is_alive():
            self._thread.start()
        if not self._startup_done.wait(8) or not self._ui_ready.is_set():
            raise RuntimeError("Overlay initialization failed: " + (self._startup_error or "UI startup timed out"))

    def set_status(self, state: str, detail: str = ""):
        self._q.put(("status", state, detail))

    def log(self, line: str):
        # Never display credentials, including those accidentally echoed by tools.
        import re
        for name, value in os.environ.items():
            if value and len(value) > 8 and any(s in name.upper() for s in ("KEY", "TOKEN", "SECRET", "PASSWORD")):
                line = line.replace(value, "[REDACTED]")
        line = re.sub(r'gsk_[A-Za-z0-9]+', '[REDACTED]', line)
        self._q.put(("log", datetime.now().strftime("%H:%M:%S") + " " + line))

    def set_preview(self, text: str):
        self._q.put(("preview", text))

    def set_last_output(self, text: str):
        self._last_output = text
        self._q.put(("output", text))

    def control(self,action):
        if not self._ui_ready.is_set():return False
        done=threading.Event();result={}
        self._q.put(('control',action,done,result))
        return done.wait(2) and result.get('ok',False)

    def dock_to_roblox(self):
        return self.control('show')

    def _calc_pos(self, w: int = 510, h: int = 390):
        box = _find_roblox_box()
        if not box:
            return 24, 320
        _hwnd, rx, ry, rw, rh = box
        ox = rx + 12
        oy = ry + max(180, min(rh - h - 115, int(rh * 0.44)))
        return ox, oy

    def _run_ui(self):
        root = tk.Tk()
        root.overrideredirect(True)
        root.wm_attributes("-topmost", True)
        root.wm_attributes("-alpha", 0.88)
        root.configure(bg="#0f1523")

        w, h = 510, min(700, root.winfo_screenheight()-60)
        ox, oy = self._calc_pos(w, h)
        oy = max(0, min(oy, root.winfo_screenheight()-h-40))
        root.geometry(f"{w}x{h}+{ox}+{oy}")

        root.update_idletasks()
        from scripts.window_registry import register_window
        register_window('agent_overlay',user32.GetAncestor(root.winfo_id(),2) or root.winfo_id())
        try:
            hwnd = user32.GetAncestor(root.winfo_id(), 2) or root.winfo_id()
            ex = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)
        except Exception:
            pass

        frame = tk.Frame(root, bg="#0f1523", highlightbackground="#3b82f6", highlightthickness=1)
        frame.pack(fill="both", expand=True)

        hdr = tk.Frame(frame, bg="#172033", height=26)
        hdr.pack(fill="x")
        title_lbl = tk.Label(hdr, text="AGENT OVERLAY", fg="#93c5fd", bg="#172033", font=("Consolas", 9, "bold"))
        title_lbl.pack(side="left", padx=8, pady=3)

        def minimize_overlay():
            # Tk refuses iconify() for override-redirect windows. Minimize the
            # native top-level instead, retaining the borderless/no-activate HUD.
            root.update_idletasks()
            hwnd = user32.GetAncestor(root.winfo_id(), 2) or root.winfo_id()
            root.withdraw()  # F10 reopens the same window.

        tk.Button(hdr, text="—", command=minimize_overlay, bg="#334155", fg="white", bd=0,
                  font=("Consolas", 9, "bold"), width=3).pack(side="right", padx=(2, 4), pady=2)
        tk.Button(hdr, text="×", command=root.withdraw, bg="#991b1b", fg="white", bd=0,
                  font=("Consolas", 9, "bold"), width=3).pack(side="right", padx=2, pady=2)
        root.protocol("WM_DELETE_WINDOW", root.withdraw)

        status_lbl = tk.Label(hdr, text="IDLE", fg="#111827", bg="#34d399", font=("Consolas", 8, "bold"), padx=6, pady=1)
        status_lbl.pack(side="right", padx=6, pady=3)

        drag = {"x": 0, "y": 0}

        def start_drag(ev):
            drag["x"], drag["y"] = ev.x, ev.y

        def on_drag(ev):
            self._custom_pos = True
            nx = root.winfo_x() + (ev.x - drag["x"])
            ny = root.winfo_y() + (ev.y - drag["y"])
            root.geometry(f"+{nx}+{ny}")

        for widget in (hdr, title_lbl):
            widget.bind("<Button-1>", start_drag)
            widget.bind("<B1-Motion>", on_drag)

        step_lbl = tk.Label(
            frame, text="Ready for command...", fg="#fde68a", bg="#0f1523",
            font=("Consolas", 9), anchor="w", justify="left", wraplength=490
        )
        step_lbl.pack(fill="x", padx=8, pady=(5, 2))

        record_bar = tk.Frame(frame, bg="#0f1523")
        record_bar.pack(fill="x", padx=8, pady=3)
        record_copy_note = tk.Label(record_bar, text='Latest F8 events; copy after stopping',
                                    fg='#94a3b8', bg='#0f1523', font=('Consolas', 8))

        def copy_f8_record():
            try:
                folder = Path(__file__).resolve().parent/'.task-output'
                name = (folder/'f8_record_latest.txt').read_text(encoding='utf-8-sig').strip()
                path = (folder/name).resolve()
                if path.parent != folder.resolve() or not path.name.startswith('f8-record-') or path.suffix != '.log':
                    raise ValueError('Invalid F8 record path')
                text = path.read_text(encoding='utf-8-sig')
                if not copy_to_clipboard(text):
                    raise RuntimeError('Clipboard unavailable; try Copy F8 Record again')
                record_copy_note.configure(text='Copied F8 record; paste in this conversation', fg='#38bdf8')
            except FileNotFoundError:
                record_copy_note.configure(text='No F8 record yet; press F8 once, then stop', fg='#fbbf24')
            except (OSError, ValueError, RuntimeError) as exc:
                record_copy_note.configure(text=str(exc), fg='#fbbf24')

        tk.Button(record_bar, text='Copy F8 Record', command=copy_f8_record,
                  bg='#2563eb', fg='white', bd=0, font=('Consolas', 8, 'bold'),
                  padx=6, pady=2).pack(side='left', padx=(0, 8))
        record_copy_note.pack(side='left')

        tk.Label(frame,text='Recordings save locally. After stopping, use Copy Recording Summary to paste the result into your chosen VS Code conversation.',
                 bg='#0f1523',fg='#93c5fd',font=('Consolas',8),wraplength=490,justify='left').pack(fill='x',padx=8)
        from scripts.reference_setup_store import SetupStore
        setup_store=SetupStore();setup_tick=[0.];setup_window=[None]
        setup_label=tk.Label(frame,text='',bg='#172033',fg='#fde68a',font=('Consolas',9),wraplength=490,justify='left',anchor='w')
        setup_label.pack(fill='x',padx=8,pady=3)
        def open_setup():
            if setup_window[0] is not None and setup_window[0].winfo_exists():
                setup_window[0].deiconify();setup_window[0].lift();return
            from scripts.reference_setup_ui import ReferenceSetupWindow
            setup_window[0]=ReferenceSetupWindow(root).window
        log_frame = tk.Frame(frame, bg="#0b101b")
        log_frame.pack(fill="both", expand=True, padx=8, pady=4)
        log_box = tk.Text(
            log_frame, bg="#0b101b", fg="#e2e8f0", font=("Consolas", 8),
            bd=0, highlightthickness=0, wrap="word", height=6
        )
        log_box.pack(side="left", fill="both", expand=True)
        log_scroll = tk.Scrollbar(log_frame,command=log_box.yview)
        log_scroll.pack(side="right",fill="y")
        log_box.configure(yscrollcommand=log_scroll.set)
        log_box.configure(state="disabled")

        ftr = tk.Frame(frame, bg="#172033", height=24)
        ftr.pack(fill="x")
        tk.Label(ftr, text=self.model_name[:26], fg="#94a3b8", bg="#172033", font=("Consolas", 8)).pack(side="left", padx=8)

        tk.Button(ftr,text='Reference Setup',command=open_setup,bg='#2563eb',fg='white',bd=0,font=('Consolas',8)).pack(side='right',padx=3)
        def manual_copy():
            if copy_to_clipboard(self._last_output):
                status_lbl.configure(text="COPIED ✓", bg="#38bdf8")

        tk.Button(
            ftr, text="Copy", command=manual_copy, bg="#2563eb", fg="white",
            activebackground="#1d4ed8", bd=0, font=("Consolas", 8, "bold"), padx=8, pady=1
        ).pack(side="right", padx=6, pady=2)

        recorder_lbl = tk.Label(frame,text="Recorder: OFF (opt-in)",bg="#172033",fg="#94a3b8",anchor="w",font=("Consolas",8))
        recorder_lbl.pack(fill="x",padx=8,pady=2)

        recording_label = tk.Label(frame, text='Last saved recording: none available', bg='#172033',
                                   fg='#e2e8f0', anchor='w', justify='left',
                                   wraplength=490, font=('Consolas', 8))
        recording_label.pack(fill='x', padx=8, pady=2)

        def copy_recording_summary():
            # This button is the only caller that copies a recording summary.
            if copy_to_clipboard(self._recording_summary):
                recorder_lbl.configure(text='Recording summary copied. Paste it into your chosen conversation.', fg='#38bdf8')
            else:
                recorder_lbl.configure(text='Copy failed; clipboard may be busy. Click Copy Recording Summary to retry.', fg='#f87171')

        recording_copy = tk.Button(frame, text='Copy Recording Summary', command=copy_recording_summary,
                                   state='disabled', bg='#2563eb', fg='white', bd=0,
                                   font=('Consolas', 8), padx=8, pady=3)
        recording_copy.pack(anchor='w', padx=8, pady=(0, 4))

        def show_recording(path):
            summary = recording_summary(path, Path(__file__).resolve().parent)
            self._recording_summary = summary
            recording_label.configure(text='Last saved recording\n'+'\n'.join(summary.splitlines()[:5]))
            recording_copy.configure(state='normal')

        # INIs are authoritative; retain the latest summary across helper restarts.
        for saved in sorted((Path(__file__).resolve().parent/'routes/demonstrations').glob('*.ini'),
                            key=lambda path: path.stat().st_mtime_ns, reverse=True):
            try:
                show_recording(saved)
                break
            except (OSError, ValueError, KeyError, configparser.Error):
                continue

        def stop_recording():
            marker=Path(__file__).resolve().parent/".task-output"/"demo_stop"
            marker.parent.mkdir(exist_ok=True)
            marker.write_text("manual_stop",encoding="utf-8")
            self.log("[RECORDER] Stop requested; capture ends and keys are released.")

        def open_recorder():
            if self.recorder_process is not None and self.recorder_process.poll() is None:
                self.log("[RECORDER] Already recording. Use Stop rec.")
                return
            dialog=tk.Toplevel(root)
            dialog.title("Record manual route")
            dialog.attributes("-topmost",True)
            dialog.geometry("470x370+30+100")
            tk.Label(dialog,text="Opt-in demonstration — maximum 120 seconds",font=("Consolas",10,"bold")).pack(pady=8)
            fields={}
            for name,label in (("map","Map area"),("subarea","Subarea"),("start_landmark","Start landmark"),("destination","Destination"),("arrival_indicator","Arrival indicator name")):
                row=tk.Frame(dialog);row.pack(fill="x",padx=10,pady=3)
                tk.Label(row,text=label,width=15,anchor="w").pack(side="left")
                entry=tk.Entry(row);entry.pack(side="left",fill="x",expand=True)
                fields[name]=entry
            consent=tk.BooleanVar(value=False)
            interactions=tk.BooleanVar(value=False)
            tk.Checkbutton(dialog,text="I closed Roblox chat/text fields; record W/A/S/D",variable=consent).pack(anchor="w",padx=10,pady=5)
            tk.Checkbutton(dialog,text="Also allow M/E for this interaction demonstration",variable=interactions).pack(anchor="w",padx=10)
            tk.Label(dialog,text="3-2-1 countdown. Stop: F12 / Stop rec.\nStops on focus loss, mouse/text activity, Escape or timeout.\nNo chat text or unrelated keys are saved.",justify="left").pack(padx=10,pady=6)
            def cancel():
                dialog.destroy()
            def start():
                if not consent.get() or any(not entry.get().strip() for entry in fields.values()):
                    self.log("[RECORDER] Fill all context labels and opt in after closing chat.")
                    return
                base=Path(__file__).resolve().parent
                request=base/".task-output/demo_request.ini"
                cfg=configparser.ConfigParser(interpolation=None)
                cfg["Demo"]={name:entry.get().strip().replace("\n"," ").replace("\r"," ")[:160] for name,entry in fields.items()}
                cfg["Demo"].update({"consent":"1","chat_closed":"1","interactions":"1" if interactions.get() else "0"})
                with request.open("w",encoding="utf-16") as stream:cfg.write(stream)
                # Explicit user Start pauses the main macro before recording.
                registry=base/'.task-output/macro_window.ini'
                macro=configparser.ConfigParser();macro.read(registry,encoding='utf-16')
                hwnd=macro.getint('Window','hwnd',fallback=0)
                if hwnd and user32.IsWindow(hwnd):
                    result=ctypes.c_size_t()
                    if not user32.SendMessageTimeoutW(hwnd,0x8003,0,0,2,1000,ctypes.byref(result)):
                        self.log('[RECORDER] Macro did not acknowledge pause; recording cancelled.');return
                dialog.destroy()
                focus_roblox()
                out=(base/".task-output/demo_output.txt").open("w",encoding="utf-8")
                try:
                    self.recorder_process=subprocess.Popen([r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe","/ErrorStdOut=utf-8",str(base/"RouteRecorder.ahk"),"record",str(request)],cwd=base,stdout=out,stderr=out)
                finally:out.close()
                self.log("[RECORDER] Explicit Start received. Capture will stop automatically within 120 seconds.")
            buttons=tk.Frame(dialog);buttons.pack(fill="x",padx=10)
            tk.Button(buttons,text="Start recording",command=start,bg="#dc2626",fg="white").pack(side="right")
            tk.Button(buttons,text="Cancel",command=cancel).pack(side="right",padx=6)
            dialog.protocol("WM_DELETE_WINDOW",cancel)

        tk.Button(ftr,text="Record…",command=open_recorder,bg="#b45309",fg="white",bd=0,font=("Consolas",8),padx=6).pack(side="right",padx=3)
        tk.Button(ftr,text="Stop rec",command=stop_recording,bg="#991b1b",fg="white",bd=0,font=("Consolas",8),padx=6).pack(side="right",padx=3)

        badge_colors = {
            "IDLE": "#34d399",
            "THINKING": "#fbbf24",
            "TOOL": "#60a5fa",
            "TESTING": "#c084fc",
            "COPIED ✓": "#38bdf8",
            "PAUSED": "#fb923c",
            "RATE WAIT": "#facc15",
            "ERROR": "#f87171",
        }

        def append_log(txt: str):
            log_box.configure(state="normal")
            log_box.insert("end", txt.rstrip() + "\n")
            if int(log_box.index("end-1c").split(".")[0]) > 2000:
                log_box.delete("1.0", "101.0")
            log_box.see("end")
            log_box.configure(state="disabled")

        append_log('[LOCAL RECORDING] Record, stop with F12 / Stop rec, then click Copy Recording Summary. '
                   'Choose the VS Code conversation and paste manually. Nothing is sent automatically.')
        history_stamp=[None]
        recorder_stamp=[None]
        runtime_stamp=[None]
        collection_notice = [None]
        def poll():
            import time
            if time.monotonic()-setup_tick[0]>1:
                setup_tick[0]=time.monotonic()
                try:
                    item=setup_store.current()
                    workflow=Path(__file__).resolve().parent/'config/manual_workflow.json'
                    if workflow.exists():
                        progress=json.loads(workflow.read_text(encoding='utf-8'))
                        current=progress['items'][progress['current_item']-1]
                        if current['number']==1:
                            item=dict(title='1/13: GUI review',request='Review the larger main GUI: resize, scroll, switch sections and inspect saved-image previews. Reply in VS Code. Later checklist items wait for your confirmation.')
                        elif current['number']==3:
                            item=dict(title='3/13: Recording handoff',request='Show/F10/close-reopen approved. Make one short recording, stop it, and click Copy Recording Summary. Paste manually into the correct conversation; item 4 waits for approval.')
                        elif current['number']==5:
                            item=dict(title='5/13: Waystone references',request='Use Waystone > Test Waystone to inspect the frame detector preview/score in current lighting and confirm the ward prompt. One generic live waystone; World Map icon is separate. F8 work waits for approval.')
                    setup_label.configure(text='SETUP: '+item['title']+'\n'+item['request'])
                except Exception as exc:setup_label.configure(text='Setup unavailable: '+str(exc))
            try:
                base=Path(__file__).resolve().parent
                history=base/'.task-output/recent_history.json'
                stamp=history.stat().st_mtime_ns
                if history_stamp[0]!=stamp:
                    history_stamp[0]=stamp
                    append_log('[HISTORY] '+history.read_text(encoding='utf-8'))
            except OSError:pass
            try:
                notice_path = Path(__file__).resolve().parent / '.task-output' / 'collection_overlay.json'
                if notice_path.exists():
                    notice = json.loads(notice_path.read_text(encoding='utf-8'))
                    if notice.get('id') != collection_notice[0]:
                        collection_notice[0] = notice.get('id')
                        step_lbl.configure(text=notice['text'])
                        status_lbl.configure(text='REJOIN', bg='#fbbf24')
                        append_log('[COLLECTION] ' + notice['text'])
                        root.deiconify()
                        root.lift()
            except (OSError,ValueError,KeyError):
                pass
            try:
                status=json.loads((Path(__file__).resolve().parent/".task-output/demo_status.json").read_text(encoding="utf-8-sig"))
                active=status.get("active",False)
                if not active and status.get('path') and recorder_stamp[0]!=status['path']:
                    show_recording(status['path'])
                    recorder_stamp[0]=status['path']
                    self.log('[RECORDER] Saved locally: '+status['path'])
                recording_copy.configure(state='disabled' if active or not self._recording_summary else 'normal')
                if active:
                    recorder_lbl.configure(text='Recorder: RECORDING - 120s limit', fg='#f87171')
                elif getattr(self, '_recorder_state', None) != (active, status.get('reason'), status.get('path')):
                    recorder_lbl.configure(text='Recorder: OFF - '+status.get('reason','idle'), fg='#94a3b8')
                self._recorder_state = (active, status.get('reason'), status.get('path'))
            except (OSError,ValueError,KeyError,configparser.Error):pass
            try:
                while True:
                    ev = self._q.get_nowait()
                    kind = ev[0]
                    if kind == 'control':
                        action,done,result=ev[1:]
                        try:
                            if action=='hide':root.withdraw()
                            elif action=='toggle' and root.winfo_viewable():root.withdraw()
                            else:
                                root.deiconify();root.lift()
                                hwnd=user32.GetAncestor(root.winfo_id(),2) or root.winfo_id()
                                user32.ShowWindow(hwnd,4)
                                if action=='setup':open_setup()
                                elif action=='record':open_recorder()
                            root.update_idletasks();result['ok']=True
                        except Exception as exc:result['error']=str(exc)
                        finally:done.set()
                    elif kind == "status":
                        st, detail = ev[1], ev[2]
                        status_lbl.configure(text=st, bg=badge_colors.get(st, "#94a3b8"))
                        if detail:
                            step_lbl.configure(text=detail)
                    elif kind == "log":
                        append_log(ev[1])
                    elif kind == "preview":
                        snippet = ev[1].strip().splitlines()[-1] if ev[1].strip() else ""
                        if snippet:
                            step_lbl.configure(text=snippet)
                    elif kind == "output":
                        append_log("--- Final Output ---")
                        append_log(ev[1])
                    elif kind in ("dock", "restore"):
                        done = ev[1] if kind == "restore" and len(ev) > 1 else None
                        result = ev[2] if kind == "restore" and len(ev) > 2 else None
                        try:
                            root.update_idletasks()
                            hwnd = user32.GetAncestor(root.winfo_id(), 2) or root.winfo_id()
                            if not hwnd or not root.winfo_exists():
                                raise RuntimeError("overlay window unavailable")
                            if kind == "dock" and not self._custom_pos:
                                nx, ny = self._calc_pos(w, h)
                                root.geometry(f"+{nx}+{ny}")
                            root.deiconify()
                            user32.ShowWindow(hwnd, 4)  # SW_SHOWNOACTIVATE also restores native minimization.
                            root.lift()
                            root.update_idletasks()
                            if user32.IsIconic(hwnd) or not root.winfo_viewable():
                                raise RuntimeError("overlay did not become visible")
                            if done is not None:
                                result["ok"] = True
                        except Exception as exc:
                            self._restore_error = str(exc)
                            if result is not None:
                                result["error"] = self._restore_error
                        finally:
                            if done is not None:
                                done.set()
                    elif kind == "record_dialog":
                        open_recorder()
                    elif kind == "hide":
                        root.withdraw()
                    elif kind == "toggle":
                        root.withdraw() if root.winfo_viewable() else root.deiconify()
            except queue.Empty:
                pass
            # Main AHK runtime publishes current F8 action without HTTP waits or
            # adding each direction change to conversation/history storage.
            try:
                runtime = Path(__file__).resolve().parent/'.task-output/runtime_status.ini'
                stamp = runtime.stat().st_mtime_ns
                if runtime_stamp[0] != stamp:
                    values = dict(line.split('=', 1) for line in runtime.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
                    state = values.get('state', 'STOPPED')
                    status_lbl.configure(text=state, bg='#34d399' if state == 'RUNNING' else '#fbbf24')
                    step_lbl.configure(text=values.get('action', '')+'\n'+values.get('detail', ''))
                    runtime_stamp[0] = stamp
            except (OSError, ValueError):
                pass
            root.after(80, poll)

        root.after(80, poll)
        self._ui_ready.set()
        self._startup_done.set()
        root.mainloop()
