"""Known macro window registration and temporary native visibility preservation."""
from contextlib import contextmanager
import configparser
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import time

ROOT=Path(__file__).resolve().parent.parent
u=ctypes.windll.user32
u.GetAncestor.argtypes=[wintypes.HWND,wintypes.UINT];u.GetAncestor.restype=wintypes.HWND
u.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
u.ShowWindow.argtypes=[wintypes.HWND,ctypes.c_int];u.IsWindowVisible.argtypes=[wintypes.HWND];u.IsIconic.argtypes=[wintypes.HWND]


def register_window(kind,hwnd,root=ROOT,pid=None):
    folder=Path(root)/'.task-output';folder.mkdir(exist_ok=True)
    (folder/(kind+'_window.ini')).write_text(f'[Window]\nhwnd={hwnd}\npid={pid or os.getpid()}\n',encoding='utf-16')


def known_windows():
    pids=set()
    for kind in ('macro','agent_overlay','image_review','asset_picker','reference_setup'):
        parser=configparser.ConfigParser()
        try:
            parser.read(ROOT/'.task-output'/(kind+'_window.ini'),encoding='utf-16')
            hwnd=int(parser['Window']['hwnd']);pid=int(parser['Window']['pid']);owner=wintypes.DWORD()
            u.GetWindowThreadProcessId(hwnd,ctypes.byref(owner))
            if owner.value==pid:pids.add(pid)
        except (ValueError,KeyError,OSError):pass
    windows=[]
    @ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
    def visit(hwnd,_):
        owner=wintypes.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(owner))
        if owner.value in pids:windows.append(hwnd)
        return True
    u.EnumWindows(visit,0)
    return windows


@contextmanager
def hidden_macro_windows():
    previous=[(h,bool(u.IsWindowVisible(h)),bool(u.IsIconic(h))) for h in known_windows()]
    try:
        for hwnd,visible,_ in previous:
            if visible:u.ShowWindow(hwnd,0)
        try:ctypes.windll.dwmapi.DwmFlush()
        except OSError:pass
        time.sleep(.06)
        yield
    finally:
        for hwnd,visible,iconic in previous:
            if visible:u.ShowWindow(hwnd,6 if iconic else 4)
