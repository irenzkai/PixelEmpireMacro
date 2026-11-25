# agent_overlay.py
import ctypes
from ctypes import wintypes
import os
import queue
import threading
import tkinter as tk

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

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
        self._custom_pos = False
        self._thread = threading.Thread(target=self._run_ui, daemon=True)

    def start(self):
        self._thread.start()

    def set_status(self, state: str, detail: str = ""):
        self._q.put(("status", state, detail))

    def log(self, line: str):
        self._q.put(("log", line))

    def set_preview(self, text: str):
        self._q.put(("preview", text))

    def set_last_output(self, text: str):
        self._last_output = text
        self._q.put(("output", text))

    def dock_to_roblox(self):
        self._q.put(("dock",))

    def _calc_pos(self, w: int = 385, h: int = 235):
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

        w, h = 385, 235
        ox, oy = self._calc_pos(w, h)
        root.geometry(f"{w}x{h}+{ox}+{oy}")

        root.update_idletasks()
        try:
            hwnd = user32.GetParent(root.winfo_id()) or root.winfo_id()
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
            font=("Consolas", 9), anchor="w", justify="left", wraplength=365
        )
        step_lbl.pack(fill="x", padx=8, pady=(5, 2))

        log_box = tk.Text(
            frame, bg="#0b101b", fg="#e2e8f0", font=("Consolas", 8),
            bd=0, highlightthickness=0, wrap="word", height=9
        )
        log_box.pack(fill="both", expand=True, padx=8, pady=4)
        log_box.configure(state="disabled")

        ftr = tk.Frame(frame, bg="#172033", height=24)
        ftr.pack(fill="x")
        tk.Label(ftr, text=f"{self.model_name} | Auto-Copy: ON", fg="#94a3b8", bg="#172033", font=("Consolas", 8)).pack(side="left", padx=8)

        def manual_copy():
            if copy_to_clipboard(self._last_output):
                status_lbl.configure(text="COPIED ✓", bg="#38bdf8")

        tk.Button(
            ftr, text="Copy", command=manual_copy, bg="#2563eb", fg="white",
            activebackground="#1d4ed8", bd=0, font=("Consolas", 8, "bold"), padx=8, pady=1
        ).pack(side="right", padx=6, pady=2)

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
            if int(log_box.index("end-1c").split(".")[0]) > 140:
                log_box.delete("1.0", "25.0")
            log_box.see("end")
            log_box.configure(state="disabled")

        def poll():
            try:
                while True:
                    ev = self._q.get_nowait()
                    kind = ev[0]
                    if kind == "status":
                        st, detail = ev[1], ev[2]
                        status_lbl.configure(text=st, bg=badge_colors.get(st, "#94a3b8"))
                        if detail:
                            step_lbl.configure(text=detail[:110])
                    elif kind == "log":
                        append_log(ev[1])
                    elif kind == "preview":
                        snippet = ev[1].strip().splitlines()[-1] if ev[1].strip() else ""
                        if snippet:
                            step_lbl.configure(text=snippet[:110])
                    elif kind == "output":
                        append_log("--- Final Output ---")
                        append_log(ev[1][:600])
                    elif kind == "dock" and not self._custom_pos:
                        nx, ny = self._calc_pos(w, h)
                        root.geometry(f"+{nx}+{ny}")
            except queue.Empty:
                pass
            root.after(80, poll)

        root.after(80, poll)
        root.mainloop()