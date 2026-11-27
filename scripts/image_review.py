"""Offline review UI. Workers own I/O; only the Tk thread owns widgets."""
import ctypes
import hashlib
import queue
import threading
import time
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import tkinter as tk
from tk_runtime import configure_tk
configure_tk()
from tkinter import messagebox, ttk
from PIL import Image, ImageTk
from image_review_store import ReviewStore
from image_review_preview import ZoomPreview, raster

ROOT = Path(__file__).resolve().parent.parent
TITLE = 'PixelEmpire Image Review'


def load_preview(path, bounds=(2048,2048)):
    with Image.open(path) as image:
        dimensions = image.size
        if image.width*image.height>64_000_000:
            raise ValueError('Preview exceeds the 64-megapixel memory limit; export a smaller copy or use Next')
        image.draft('RGB',bounds)  # JPEG decode reduction where supported.
        image.thumbnail(bounds,Image.Resampling.LANCZOS,reducing_gap=3)
        return image.convert('RGBA'),dimensions


class ReviewWindow:
    def __init__(self,root,assets,db):
        self.root = root
        self.assets,self.db = assets,db
        self.events = queue.Queue()
        self.actions = ThreadPoolExecutor(max_workers=1,thread_name_prefix='review-action')
        self.previews = ThreadPoolExecutor(max_workers=1,thread_name_prefix='review-preview')
        self.reviewed=False
        self.stop = threading.Event()
        self.items=[]; self.position=0; self.generation=0
        self.busy=False; self.scanning=False; self.closed=False
        self.action_epoch=0; self.last_action_started=0
        self.cache=OrderedDict()  # Preview worker only; at most three small images.
        self.buttons=[]
        root.title(TITLE); root.geometry('820x740')
        self.zoom_text=tk.StringVar(value='Zoom: 100% (fit)')
        self.preview=ZoomPreview(root,self.request_render,self.zoom_text)
        self.preview.pack(fill='both',expand=True,padx=12,pady=8)
        self.preview.show_message('Opening saved index...')
        ttk.Label(root,textvariable=self.zoom_text).pack(anchor='w',padx=12)
        self.details=tk.StringVar(value='Opening saved index...')
        ttk.Label(root,textvariable=self.details,wraplength=790).pack(fill='x',padx=12,pady=4)
        row=ttk.Frame(root); row.pack(fill='x',padx=12,pady=5)
        ttk.Label(row,text='Editable name:').pack(side='left')
        self.name=tk.StringVar()
        self.entry=ttk.Entry(row,textvariable=self.name)
        self.entry.pack(side='left',fill='x',expand=True,padx=8)
        self.count=tk.StringVar(value='Remaining: loading saved index')
        ttk.Label(root,textvariable=self.count).pack(anchor='w',padx=12)
        self.status=tk.StringVar(value='Opening locally; no model calls.')
        ttk.Label(root,textvariable=self.status,wraplength=790).pack(fill='x',padx=12,pady=5)
        browse=ttk.Frame(root);browse.pack(fill='x',padx=12,pady=4)
        self.view=tk.StringVar(value='Incoming')
        self.view_picker=ttk.Combobox(browse,textvariable=self.view,values=('Incoming','Reviewed'),state='readonly',width=14)
        self.view_picker.pack(side='left')
        self.view_picker.bind('<<ComboboxSelected>>',self.change_view)
        for label,step in [('Previous',-1),('Next',1)]:
            button=ttk.Button(browse,text=label,command=lambda n=step:self.browse(n))
            button.pack(side='left',padx=4);self.buttons.append(button)
        self.import_button=ttk.Button(browse,text='Import current cache',command=self.import_cache)
        self.import_button.pack(side='right');self.buttons.append(self.import_button)
        ttk.Label(root,text='Local incoming to reviewed. Keep / Next or Rename retains an image. Delete permanently removes exported copies.\n'
            'Import reads the current cache once; it does not reset the cache or run a watcher.',wraplength=790).pack(fill='x',padx=12,pady=5)
        controls=ttk.Frame(root); controls.pack(fill='x',padx=12,pady=12)
        for label,kind in [('Keep / Next','keep'),('Rename','rename'),('Delete','delete')]:
            button=ttk.Button(controls,text=label,command=lambda k=kind:self.act(k))
            button.pack(side='left',padx=4); self.buttons.append(button)
        crop_button=ttk.Button(controls,text='Crop for reference',command=self.crop_reference)
        crop_button.pack(side='left',padx=4);self.buttons.append(crop_button)
        
        self.entry.bind('<Return>',lambda _:self.act('rename'))
        self.enable(False)
        self.actions.submit(self.initialize)
        root.after(30,self.poll)
        root.after(30000,self.checkpoint)
        root.protocol('WM_DELETE_WINDOW',self.close)
        root.update_idletasks()
        from window_registry import register_window
        register_window('image_review',ctypes.windll.user32.GetAncestor(root.winfo_id(),2) or root.winfo_id(),ROOT)

    def initialize(self):
        try:
            self.store=ReviewStore(self.assets,self.db)
            from cache_image_import import CacheImport
            manager=CacheImport(ROOT,self.assets,self.db)
            manager.stop()
            deadline=time.monotonic()+40
            while manager.session()['status']=='stopping':
                if time.monotonic()>deadline:raise RuntimeError('Old collector has not stopped; reopen after it stops')
                time.sleep(.2)
            self.store.migrate()
            self.events.put(('ready',self.store.pending()))
        except Exception as exc:
            self.events.put(('startup_error',str(exc)))

    def enable(self,enabled):
        for button in self.buttons:
            button.configure(state='normal' if enabled else 'disabled')
        self.entry.configure(state='normal' if enabled else 'disabled')
        self.view_picker.configure(state='readonly' if enabled else 'disabled')

    def selected(self):
        return self.items[self.position] if self.items else None

    def set_items(self,items,preserve=True):
        current=self.selected()
        digest=current['sha256'] if current else None
        self.items=items
        found=next((i for i,r in enumerate(items) if r['sha256']==digest),None)
        self.count.set(f"{'Reviewed' if self.reviewed else 'Incoming'}: {len(items)} unique images")
        if preserve and found is not None:
            self.position=found
            self.items[found]=current  # Never switch to a different duplicate path under an edited name.
            return  # Never reset the editor/preview on a scan result.
        if preserve and current is not None:
            self.items.insert(min(self.position,len(self.items)),current)
            self.position=min(self.position,len(self.items)-1)
            self.status.set('The selected file changed outside this window. Skip or Refresh before retrying.')
            return
        self.position=self.position % len(items) if items else 0
        self.show()

    def show(self):
        self.generation+=1
        token=self.generation
        item=self.selected()
        self.preview.show_message('Loading preview...' if item else 'No images in this view. Import current cache or switch views.')
        if not item:
            self.details.set('No image selected'); self.name.set(''); return
        self.details.set(f"Original: {item['original_filename']}\nCurrent: {item['path']}\nSHA-256: {item['sha256']}")
        self.name.set(Path(item['path']).name)
        upcoming=[item.copy()]
        self.previews.submit(self.preview_work,token,upcoming)

    def preview_work(self,token,items):
        for i,item in enumerate(items):
            if self.stop.is_set() or token!=self.generation:
                return
            try:
                path=self.store.safe_path(item['path'])
                stat=path.stat()
                key=(item['path'],stat.st_size,stat.st_mtime_ns)
                if key not in self.cache:
                    self.cache[key]=load_preview(path)
                self.cache.move_to_end(key)
                while len(self.cache)>3:
                    self.cache.popitem(last=False)
                if i==0:
                    self.events.put(('preview',token,item['sha256'],self.cache[key]))
            except Exception as exc:
                if i==0:
                    self.events.put(('preview_error',token,str(exc)))

    def act(self,kind):
        if self.busy or not hasattr(self,'store'):
            return
        if time.monotonic()-self.last_action_started<.45:
            return
        if kind=='keep' and self.reviewed:
            self.browse(1);return
        item=self.selected()
        if not item:
            return
        entered=self.name.get()  # Capture edited text on the UI thread exactly once.
        self.action_epoch+=1; self.last_action_started=time.monotonic()
        self.busy=True; self.enable(False)
        if kind=='delete' and not messagebox.askyesno('Permanently delete exports?',
            'Permanently delete all exported copies of this image? Detection references already saved separately are retained.',parent=self.root):
            self.busy=False; self.enable(True); return
        token=self.generation
        snapshot=item.copy() if item else None
        self.status.set('Renaming and verifying...' if kind=='rename' else 'Deleting exported copies...' if kind=='delete' else 'Keeping image in reviewed...')
        self.actions.submit(self.action_work,kind,token,snapshot,entered)

    def action_work(self,kind,token,item,entered):
        try:
            result=self.store.act(item['sha256'],item['path'],
                (entered if kind=='rename' else Path(item['path']).name) if kind in ('rename','keep') else None,
                allow_reviewed=True)
            self.store.migrate()
            self.events.put(('action',token,result,self.store.pending(self.reviewed)))
        except Exception as exc:
            self.events.put(('action_error',token,str(exc)))

    def checkpoint(self):
        if not self.closed and hasattr(self,'store'):
            def work():
                try:
                    with self.store.connect() as conn:
                        dirty=conn.execute('SELECT 1 FROM image_review_manifest_dirty LIMIT 1').fetchone()
                    if dirty:
                        self.store.sync_manifest()
                except Exception as exc:
                    self.events.put(('manifest_error',str(exc)))
            self.actions.submit(work)
        if not self.closed:
            self.root.after(30000,self.checkpoint)

    def request_render(self,render_token,master,size,transform):
        generation=self.generation
        def work():
            if self.closed or generation!=self.generation or render_token!=self.preview.render_token:return
            image=raster(master,size,transform)
            self.events.put(('viewport',generation,render_token,image))
        self.previews.submit(work)

    def crop_reference(self):
        item=self.selected()
        if not item:return
        from scripts.reference_setup_ui import ReferenceSetupWindow
        setup=ReferenceSetupWindow(self.root);setup.select('portals')
        setup.image_path=self.store.safe_path(item['path']);setup.crop=None;setup.frame=0
        setup.preview_image()
        setup.window.after(250,setup.crop_image)

    def browse(self,step):
        if self.busy or not self.items:return
        self.position=(self.position+step)%len(self.items)
        self.show()

    def change_view(self,event=None):
        if self.busy:return
        self.reviewed=self.view.get()=='Reviewed'
        self.busy=True;self.enable(False)
        def work():
            try:self.events.put(('view',self.store.pending(self.reviewed)))
            except Exception as exc:self.events.put(('import_error',str(exc)))
        self.actions.submit(work)

    def import_cache(self):
        if self.busy or not hasattr(self,'store'):return
        self.busy=True;self.enable(False)
        self.status.set('Importing current cache locally...')
        def work():
            try:
                from cache_image_import import CacheImport
                count,failures=CacheImport(ROOT,self.assets,self.db).import_current(self.stop,
                    lambda n,total:self.events.put(('import_progress',n,total)))
                self.events.put(('import_done',count,failures,self.store.pending(self.reviewed)))
            except Exception as exc:self.events.put(('import_error',str(exc)))
        self.actions.submit(work)

    def poll(self):
        if self.closed:return
        try:
            while True:
                event=self.events.get_nowait(); kind=event[0]
                if kind=='ready':
                    self.enable(True); self.set_items(event[1],False)
                    self.status.set('Ready. Import current cache, then Keep / Next, Rename or Delete. Browse retained images in Reviewed.')
                elif kind=='startup_error':
                    self.status.set('Cannot open saved index: '+event[1])
                elif kind=='preview' and event[1]==self.generation and self.selected() and event[2]==self.selected()['sha256']:
                    image,dimensions=event[3]
                    self.preview.set_image(image)
                    item=self.selected()
                    self.details.set(f"Original: {item['original_filename']}\nCurrent: {item['path']}\nDimensions: {dimensions[0]} × {dimensions[1]}    SHA-256: {item['sha256']}")
                elif kind=='preview_error' and event[1]==self.generation:
                    self.preview.show_message('Preview unavailable: '+event[2])
                elif kind=='viewport' and event[1]==self.generation and event[2]==self.preview.render_token:
                    self.preview.display(ImageTk.PhotoImage(event[3],master=self.root),event[2])
                elif kind in ('action','action_error') and event[1]==self.generation:
                    self.busy=False; self.enable(True)
                    if kind=='action_error':
                        self.status.set('Action failed: '+event[2]+' — edit the name or Refresh and retry.')
                        self.entry.focus_set()  # Keep text and current item; do not advance.
                    else:
                        self.status.set('Saved. Manifest checkpoint pending. Delete is permanent.')
                        self.set_items(event[3],False)
                elif kind=='manifest_error' and not self.busy:
                    self.status.set('Action is saved in SQLite; manifest checkpoint will retry: '+event[1])
                elif kind=='view':
                    self.busy=False;self.enable(True);self.position=0;self.set_items(event[1],False)
                elif kind=='import_progress':
                    self.status.set(f'Importing current cache: {event[1]} / {event[2]}')
                elif kind=='import_done':
                    self.busy=False;self.enable(True);self.set_items(event[3],False)
                    self.status.set(f'Import finished: {event[1]} cache images checked; {event[2]} failed (retry Import). Saved images and tombstones deduplicate by content.')
                elif kind=='import_error':
                    self.busy=False;self.enable(True);self.status.set('Import failed: '+event[1])
        except queue.Empty:
            pass
        self.root.after(30,self.poll)

    def close(self):
        self.closed=True; self.stop.set()
        if hasattr(self,'store'):
            self.actions.submit(self.store.sync_manifest)
        self.actions.shutdown(wait=False)
        self.previews.shutdown(wait=False,cancel_futures=True)
        self.root.destroy()


def main():
    kernel=ctypes.windll.kernel32
    kernel.CreateMutexW.restype=ctypes.c_void_p
    mutex=kernel.CreateMutexW(None,False,'Local\\PixelEmpireImageReview_'+hashlib.sha256(str(ROOT).encode()).hexdigest()[:16])
    if kernel.GetLastError()==183:
        u=ctypes.windll.user32; u.FindWindowW.restype=ctypes.c_void_p
        u.ShowWindow.argtypes=[ctypes.c_void_p,ctypes.c_int]; u.SetForegroundWindow.argtypes=[ctypes.c_void_p]
        hwnd=u.FindWindowW(None,TITLE)
        if hwnd:u.ShowWindow(hwnd,9); u.SetForegroundWindow(hwnd)
        return
    root=tk.Tk()
    root.review=ReviewWindow(root,ROOT/'public/cache_assets',ROOT/'agent_memory.db')
    root.mainloop()
    kernel.CloseHandle.argtypes=[ctypes.c_void_p]; kernel.CloseHandle(mutex)


if __name__=='__main__':main()
