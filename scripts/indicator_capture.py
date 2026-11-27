"""Rectangle capture companion: no cache search or indexing."""
import configparser, ctypes, io, json, re, queue, hashlib
from ctypes import wintypes
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tkinter as tk
from tk_runtime import configure_tk
configure_tk()
import mss
from PIL import Image
from indicator_editor import IndicatorWindow
ROOT=Path(__file__).resolve().parents[1]
TASK=ROOT/'.task-output'
TASK.mkdir(exist_ok=True)
def write_ini(path,section,values):
    parser=configparser.ConfigParser();parser[section]={k:str(v) for k,v in values.items()}
    out=io.StringIO();parser.write(out)
    temporary=path.with_suffix('.python.tmp')
    temporary.write_text(out.getvalue(),encoding='utf-16');temporary.replace(path)


def thumbnail(image,bounds=(1600,1600)):
    result=image.convert('RGBA');result.thumbnail(bounds)
    return result


def capture_selection(request):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,120}',request['id']):raise ValueError('Invalid local capture identifier')
    bx,by,bw,bh=[int(request[k]) for k in ('client_x','client_y','client_w','client_h')]
    x1,y1,x2,y2=[int(request[k]) for k in ('x1','y1','x2','y2')]
    if not ctypes.windll.user32.IsWindow(int(request['hwnd'])):raise ValueError('Roblox window closed')
    left=max(bx,min(x1,x2));top=max(by,min(y1,y2))
    right=min(bx+bw,max(x1,x2));bottom=min(by+bh,max(y1,y2))
    if right-left<4 or bottom-top<4:raise ValueError('Drag an indicator rectangle at least 4x4 pixels')
    rect=[0,0,right-left,bottom-top]
    if right<=left or bottom<=top:raise ValueError('Selection is outside the Roblox client')
    for hwnd in request.get('hidden_hwnds','').split(','):
        if hwnd.strip() and ctypes.windll.user32.IsWindowVisible(int(hwnd)):
            raise ValueError('A macro overlay is still visible; capture cancelled to avoid contamination')
    path=TASK/'indicator_capture.png'
    if ctypes.windll.user32.GetForegroundWindow()!=int(request['hwnd']):
        raise ValueError('Roblox lost focus before capture; select the region again')
    with mss.mss() as grabber:
        frame=grabber.grab({'left':left,'top':top,'width':right-left,'height':bottom-top})
        image=Image.frombytes('RGB',frame.size,frame.rgb)
    image.save(path)
    evidence=dict(request_id=request['id'],capture_path=str(path),client_box=[bx,by,bw,bh],
                  capture_box=[left,top,right-left,bottom-top],click=[x1,y1],selection=rect,
                  purpose=request.get('purpose','indicator'),target=request.get('target',''),hwnd=int(request['hwnd']),overlay_free=True)
    return image,thumbnail(image),evidence



def main():
    try:ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except OSError:pass
    kernel=ctypes.windll.kernel32;kernel.CreateMutexW.restype=wintypes.HANDLE
    handle=kernel.CreateMutexW(None,False,'Local\\PixelEmpireIndicatorCapture_'+hashlib.sha256(str(ROOT).encode()).hexdigest()[:16])
    if kernel.GetLastError()==183:return
    root=tk.Tk();root.withdraw()
    events=queue.Queue();worker=ThreadPoolExecutor(max_workers=1)
    current={'request':'','busy':False,'epoch':''}
    def command():
        cfg=configparser.ConfigParser();cfg.read(TASK/'asset_picker_command.ini',encoding='utf-16')
        return dict(cfg['Picker']) if cfg.has_section('Picker') else {}
    def exit_mode():
        value=command();value['enabled']='0'
        write_ini(TASK/'asset_picker_command.ini','Picker',value)
        window.closed=True;window.worker.shutdown(wait=False,cancel_futures=True)
        worker.shutdown(wait=False,cancel_futures=True);root.destroy()
    def reselect(target):
        value=command();value.update(enabled='1',phase='selecting',purpose='indicator',target=target)
        write_ini(TASK/'asset_picker_command.ini','Picker',value)
    window=IndicatorWindow(root,ROOT,reselect,exit_mode);window.window.withdraw()
    def poll():
        value=command()
        if value.get('enabled')!='1':exit_mode();return
        if current['epoch']!=value.get('epoch'):
            current['epoch']=value.get('epoch');window.window.withdraw()
            write_ini(TASK/'asset_picker_state.ini','Picker',{'epoch':current['epoch']})
        cfg=configparser.ConfigParser();cfg.read(TASK/'asset_picker_request.ini',encoding='utf-16')
        if cfg.has_section('Selection'):
            request=dict(cfg['Selection'])
            if request.get('epoch')==current['epoch'] and request.get('id')!=current['request'] and not current['busy']:
                current['request']=request['id'];current['busy']=True
                def work():
                    try:events.put(('capture',capture_selection(request)))
                    except Exception as exc:events.put(('error',str(exc)))
                    finally:write_ini(TASK/'asset_picker_capture_ack.ini','Capture',{'id':request['id']})
                worker.submit(work)
        try:
            while True:
                kind,result=events.get_nowait();current['busy']=False
                if kind=='capture':window.selected_capture(result[0],result[2])
                else:window.status.set(result);window.window.deiconify()
        except queue.Empty:pass
        root.after(80,poll)
    root.after(80,poll);root.mainloop()
if __name__=='__main__':main()
