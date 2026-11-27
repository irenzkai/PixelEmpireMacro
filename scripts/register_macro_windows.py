"""Bootstrap registries for already-running windows; future app starts self-register."""
import argparse
import ctypes
from ctypes import wintypes
from window_registry import register_window

def run(agent_pid):
    u=ctypes.windll.user32
    @ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
    def visit(hwnd,_):
        title=ctypes.create_unicode_buffer(512);u.GetWindowTextW(hwnd,title,512)
        pid=wintypes.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid))
        if pid.value==agent_pid and title.value=='tk':
            register_window('agent_overlay',hwnd,pid=pid.value);print('Registered agent',hwnd,pid.value)
        for kind,name in [('image_review','PixelEmpire Image Review'),('asset_picker','PixelEmpire Asset Picker')]:
            if title.value==name:register_window(kind,hwnd,pid=pid.value);print('Registered',kind,hwnd,pid.value)
        return True
    u.EnumWindows(visit,0)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--agent-pid',type=int,default=0)
    run(parser.parse_args().agent_pid)
