"""Whitelisted messages for explicit local UI actions; no keyboard injection."""
import configparser
import ctypes
from ctypes import wintypes
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
u=ctypes.windll.user32
u.IsWindow.argtypes=[wintypes.HWND]
u.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
u.SendMessageTimeoutW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM,wintypes.UINT,wintypes.UINT,ctypes.POINTER(ctypes.c_size_t)]
u.SendMessageTimeoutW.restype=ctypes.c_ssize_t

def macro_message(message,wparam=0,lparam=0):
    if message not in (0x8003,0x8004,0x8007,0x8009):raise ValueError('Unsupported macro action')
    cfg=configparser.ConfigParser();cfg.read(ROOT/'.task-output/macro_window.ini',encoding='utf-16')
    hwnd=cfg.getint('Window','hwnd',fallback=0);pid=cfg.getint('Window','pid',fallback=0);owner=wintypes.DWORD()
    if hwnd:u.GetWindowThreadProcessId(hwnd,ctypes.byref(owner))
    if not hwnd or owner.value!=pid or not u.IsWindow(hwnd):raise RuntimeError('Start or reload PixelEmpireMacro.ahk first')
    result=ctypes.c_size_t()
    if not u.SendMessageTimeoutW(hwnd,message,wparam,lparam,2,2000,ctypes.byref(result)) or result.value!=1:
        raise RuntimeError('Macro did not acknowledge the action; reload the macro and try again')
