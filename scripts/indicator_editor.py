"""Local indicator CRUD and on-demand OCR/image tests; no detection timer."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import queue
import tkinter as tk
from tkinter import ttk,messagebox
import requests
from PIL import Image,ImageTk
from indicator_regions import RegionStore,normalized,screen_bounds,client_geometry,BUILTINS
from window_registry import hidden_macro_windows


class IndicatorWindow:
    def __init__(self,parent,project,reselect,exit_mode):
        self.project=Path(project);self.reselect=reselect;self.exit_mode=exit_mode
        self.window=tk.Toplevel(parent);self.window.title('PixelEmpire Indicator Regions');self.window.geometry('820x760')
        self.events=queue.Queue();self.worker=ThreadPoolExecutor(max_workers=1);self.store=None;self.current=None
        self.reference=[1,1,96];self.capture_data=None;self.busy=False;self.closed=False
        self.list=ttk.Treeview(self.window,columns=('type','enabled','roi','alias'),show='tree headings',height=6)
        self.list.heading('#0',text='Name');self.list.column('#0',width=150)
        for field,width in [('type',60),('enabled',60),('roi',320),('alias',90)]:
            self.list.heading(field,text=field.title());self.list.column(field,width=width)
        self.list.pack(fill='x',padx=10,pady=8);self.list.bind('<<TreeviewSelect>>',self.select)
        self.name=tk.StringVar(value='map_name');self.kind=tk.StringVar(value='ocr');self.enabled=tk.BooleanVar(value=True)
        self.norm=tk.StringVar();self.pixels=tk.StringVar();self.expected=tk.StringVar();self.ref=tk.StringVar();self.alias=tk.StringVar(value='top_bar');self.threshold=tk.StringVar(value='.8')
        for label,var in [('Name',self.name),('Normalized x,y,w,h',self.norm),('Reference pixels x,y,w,h',self.pixels),('Expected OCR text (separate by |)',self.expected)]:
            row=ttk.Frame(self.window);row.pack(fill='x',padx=10,pady=3)
            ttk.Label(row,text=label,width=28).pack(side='left');ttk.Entry(row,textvariable=var).pack(side='left',fill='x',expand=True)
        settings=ttk.Frame(self.window);settings.pack(fill='x',padx=10,pady=4)
        ttk.Combobox(settings,textvariable=self.kind,values=['ocr','image'],width=9,state='readonly').pack(side='left')
        ttk.Checkbutton(settings,text='Enabled',variable=self.enabled).pack(side='left',padx=6)
        ttk.Label(settings,text='Reuse built-in ROI').pack(side='left')
        ttk.Combobox(settings,textvariable=self.alias,values=['',*BUILTINS],width=15).pack(side='left')
        ttk.Label(settings,text='Image threshold').pack(side='left',padx=5);ttk.Entry(settings,textvariable=self.threshold,width=5).pack(side='left')
        refs=ttk.Frame(self.window);refs.pack(fill='x',padx=10,pady=4)
        ttk.Label(refs,text='Asset / saved capture').pack(side='left');self.references=ttk.Combobox(refs,textvariable=self.ref,state='readonly');self.references.pack(side='left',fill='x',expand=True)
        buttons=ttk.Frame(self.window);buttons.pack(fill='x',padx=10,pady=4)
        for label,callback in [('Save',self.save),('Save capture as reference',self.capture_reference),('Test',self.test),('Apply pixels',self.apply_pixels),('Recalibrate / draw',self.draw),('Disable / Enable',self.toggle),('Delete',self.delete),('Map labels',self.map_labels)]:
            index=len(buttons.winfo_children())
            ttk.Button(buttons,text=label,command=callback).grid(row=index//4,column=index%4,padx=3,pady=2)
        ttk.Label(self.window,text='Names: map_name, tower_progress, in_tower, floor_cleared, boss_banner, boss_coming/appeared/already_in/defeated,\nminiboss_coming/appeared/already_in/defeated, waystone_prompt, waystone, portal.\nFor map images, put the map name in Expected OCR text. Other names can verify route arrivals.',wraplength=790).pack(fill='x',padx=10)
        self.status=tk.StringVar(value='Loading saved indicators...');ttk.Label(self.window,textvariable=self.status,wraplength=790).pack(fill='x',padx=10,pady=6)
        self.preview=ttk.Label(self.window,anchor='center');self.preview.pack(fill='both',expand=True,padx=10,pady=6)
        ttk.Label(self.window,text='OCR uses the existing local server on 8765. Tests are on demand; no extra detection loop.\n'
            'Normalized coordinates follow the client position/size. Recalibrate if the game changes its UI layout.',wraplength=790).pack(padx=10,pady=6)
        self.window.protocol('WM_DELETE_WINDOW',self.exit_mode);self.window.bind('<Escape>',lambda _:self.exit_mode())
        self.submit('load',self.load)
        self.window.after(40,self.poll)

    def submit(self,event,fn):
        if self.busy:self.status.set('Please wait for the current local operation.');return
        self.busy=True
        def work():
            try:self.events.put((event,fn()))
            except Exception as exc:self.events.put(('error',str(exc)))
        self.worker.submit(work)

    def load(self):
        if self.store is None:self.store=RegionStore(self.project)
        return self.store.list(),self.store.named_references()

    def populate(self,record):
        self.current=record['name'];self.name.set(record['name']);self.kind.set(record['kind']);self.enabled.set(record['enabled'])
        self.norm.set(','.join(f'{v:.7f}' for v in record['normalized']))
        self.reference=[record['reference_w'],record['reference_h'],record['reference_dpi']]
        self.pixels.set(','.join(map(str,screen_bounds(record['normalized'],[0,0,*self.reference[:2]]))))
        self.expected.set(' | '.join(record['expected_text']));self.ref.set(record.get('reference_name') or '')
        self.alias.set(record.get('builtin_alias') or '');self.threshold.set(str(record['threshold']))

    def select(self,*_):
        selected=self.list.selection()
        if selected and hasattr(self,'records'):
            record=next((r for r in self.records if r['name']==selected[0]),None)
            if record:self.populate(record)

    def selected_capture(self,image,evidence):
        self.capture_data=(image,evidence)
        if self.store is None or self.busy:
            self.window.after(100,lambda:self.selected_capture(image,evidence));return
        target=evidence.get('target','')
        if target:
            row=next((r for r in getattr(self,'records',[]) if r['name']==target),None)
            if row:self.populate(row)
            else:self.current=None;self.name.set(target);self.alias.set('top_bar' if target=='map_name' else '')
        elif getattr(self,'records',[]):
            self.current=None;self.name.set('new_indicator');self.alias.set('')
        client=evidence['client_box'];box=evidence['capture_box']
        _,dpi=client_geometry(evidence['hwnd'])
        self.reference=[client[2],client[3],dpi]
        values=normalized(box,client);self.norm.set(','.join(f'{v:.7f}' for v in values))
        self.pixels.set(','.join(map(str,[box[0]-client[0],box[1]-client[1],box[2],box[3]])))
        # Image is already bounded/captured on the worker; thumbnail decode also stays there.
        def work():
            thumb=image.copy();thumb.thumbnail((780,260));return thumb
        self.submit('preview',work);self.window.deiconify();self.window.lift()
        self.status.set(f'Selected {box[2]}x{box[3]} client pixels at {dpi} DPI. Name and Save this region.')

    def capture_reference(self):
        if not self.capture_data:self.status.set('Draw a region first.');return
        image=self.capture_data[0].copy()
        def work():
            digest=self.store.add_reference(image)
            return 'public/detection_references/'+digest+'.png',self.store.named_references()
        self.submit('reference',work)

    def data(self):
        return dict(name=self.name.get(),kind=self.kind.get(),enabled=self.enabled.get(),
            normalized=list(map(float,self.norm.get().split(','))),reference_w=self.reference[0],reference_h=self.reference[1],
            reference_dpi=self.reference[2],expected_text=[v.strip() for v in self.expected.get().split('|') if v.strip()],
            reference_name=self.ref.get(),builtin_alias=self.alias.get(),threshold=float(self.threshold.get()))

    def save(self):
        try:data=self.data();old=self.current
        except Exception as exc:self.status.set(str(exc));return
        def work():
            name=self.store.save(data,old);return name,self.load()
        self.submit('saved',work)

    def apply_pixels(self):
        try:
            values=list(map(float,self.pixels.get().split(',')))
            norm=normalized(values,[0,0,*self.reference[:2]])
            self.norm.set(','.join(f'{v:.7f}' for v in norm))
        except Exception as exc:self.status.set(str(exc))

    def draw(self):
        self.window.withdraw();self.reselect(self.current or self.name.get())

    def toggle(self):
        self.enabled.set(not self.enabled.get());self.save()

    def delete(self):
        name=self.current
        if not name:return
        if not messagebox.askyesno('Delete indicator?',f'Delete saved region {name}? Images and review history are kept.',parent=self.window):return
        def work():self.store.delete(name);return self.load()
        self.current=None;self.submit('load',work)

    def map_labels(self):
        from map_labels import edit_labels
        edit_labels(self.window,self.project)

    def test(self):
        name=self.current
        if not name:self.status.set('Save or select a region before testing.');return
        if self.busy:return
        self.status.set('Testing in Roblox; overlays return when capture/OCR completes...')
        self.window.withdraw()
        from agent_overlay import focus_roblox
        focus_roblox()
        def work():
            with hidden_macro_windows():
                result=requests.get('http://127.0.0.1:8765/indicator',params={'name':name,'preview':1},timeout=12).json()
            thumb=None
            if result.get('crop_path'):
                with Image.open(result['crop_path']) as image:
                    thumb=image.convert('RGBA');thumb.thumbnail((780,260))
            return result,thumb
        self.submit('tested',work)

    def poll(self):
        if self.closed:return
        try:
            while True:
                kind,result=self.events.get_nowait();self.busy=False
                if kind in ('load','saved'):
                    if kind=='saved':self.current=result[0];result=result[1];self.status.set('Saved locally; existing OCR workflow reloads this definition automatically.')
                    self.records,references=result;self.list.delete(*self.list.get_children())
                    self.references.configure(values=[r['name'] for r in references])
                    for r in self.records:self.list.insert('','end',iid=r['name'],text=r['name'],values=(r['kind'],bool(r['enabled']),str([round(v,4) for v in r['normalized']]),r['builtin_alias']))
                    if self.current and self.current in self.list.get_children():self.list.selection_set(self.current)
                elif kind=='reference':
                    self.ref.set(result[0]);self.references.configure(values=[r['name'] for r in result[1]]);self.status.set('Direct capture reference saved; choose image and Save.')
                elif kind in ('preview','tested'):
                    image=result if kind=='preview' else result[1]
                    if image is not None:
                        photo=ImageTk.PhotoImage(image,master=self.window);self.preview.configure(image=photo);self.preview.image=photo
                    if kind=='tested':self.status.set(json.dumps(result[0],ensure_ascii=False));self.window.deiconify();self.window.lift()
                elif kind=='error':self.status.set('Region operation failed: '+result);self.window.deiconify()
        except queue.Empty:pass
        self.window.after(40,self.poll)
