"""One-section-at-a-time reference setup. File/preview/OCR work uses one worker."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import ctypes
from ctypes import wintypes
import hashlib
import json
import queue
import tkinter as tk
from tkinter import ttk,messagebox,filedialog
from PIL import Image,ImageTk
from scripts.reference_setup_store import SetupStore,STEPS,connect,change_association

class ReferenceSetupWindow:
    def __init__(self,parent):
        self.window=tk.Toplevel(parent);self.window.title('PixelEmpire Reference Setup');self.window.geometry('1010x900')
        self.store=SetupStore();self.current_key=None;self.events=queue.Queue();self.worker=ThreadPoolExecutor(max_workers=1)
        self.busy=False;self.closed=False;self.token=0;self.image_path=None;self.crop=None;self.frame=0;self.last_ocr={};self.photo=None
        self.request=tk.StringVar();ttk.Label(self.window,textvariable=self.request,wraplength=970).pack(fill='x',padx=12,pady=10)
        row=ttk.Frame(self.window);row.pack(fill='x',padx=12)
        self.sections=ttk.Combobox(row,state='readonly',values=[t for _,t,_ in STEPS]+['References']);self.sections.pack(side='left',fill='x',expand=True)
        self.sections.bind('<<ComboboxSelected>>',lambda _:self.select((STEPS[self.sections.current()][0] if self.sections.current()<len(STEPS) else 'references')))
        ttk.Button(row,text='Next pending',command=self.refresh).pack(side='left',padx=5)
        self.body=ttk.Frame(self.window);self.body.pack(fill='both',expand=True,padx=12,pady=8)
        self.status=tk.StringVar(value='Progress is saved locally. Unavailable items stay pending.')
        ttk.Label(self.window,textvariable=self.status,wraplength=970).pack(fill='x',padx=12,pady=7)
        bottom=ttk.Frame(self.window);bottom.pack(fill='x',padx=12,pady=6)
        ttk.Button(bottom,text='Confirm this section is complete',command=self.complete).pack(side='left')
        ttk.Button(bottom,text='Leave pending',command=self.pending).pack(side='left',padx=6)
        self.window.protocol('WM_DELETE_WINDOW',self.close)
        from scripts.window_registry import register_window
        self.window.update_idletasks();register_window('reference_setup',ctypes.windll.user32.GetAncestor(self.window.winfo_id(),2) or self.window.winfo_id())
        try:
            from scripts.macro_bridge import macro_message
            macro_message(0x8003)
        except Exception as exc:self.status.set('Start/reload the macro before drawing regions or travelling: '+str(exc))
        self.refresh();self.window.after(50,self.poll);self.window.after(2000,self.persist_draft)
    def run(self,work,done=None):
        if self.busy:self.status.set('Please wait for the current file/OCR operation');return
        self.busy=True;token=self.token;self.status.set('Working locally...')
        def execute():
            try:self.events.put((token,True,work(),done))
            except Exception as exc:self.events.put((token,False,str(exc),None))
        self.worker.submit(execute)
    def poll(self):
        if self.closed:return
        try:
            while True:
                token,ok,result,done=self.events.get_nowait();self.busy=False
                if token!=self.token:continue
                if not ok:self.status.set(result);continue
                self.status.set('Saved locally' if done is None else 'Ready')
                if done:done(result)
        except queue.Empty:pass
        self.window.after(50,self.poll)
    def refresh(self):self.select(self.store.current()['key'])
    def choose(self,label,values,default=None):
        row=ttk.Frame(self.body);row.pack(fill='x',pady=3);ttk.Label(row,text=label,width=22).pack(side='left')
        var=tk.StringVar(value=str(default if default is not None else values[0]));ttk.Combobox(row,textvariable=var,values=values,state='readonly').pack(side='left',fill='x',expand=True)
        return var
    def entry(self,label,value=''):
        row=ttk.Frame(self.body);row.pack(fill='x',pady=3);ttk.Label(row,text=label,width=22).pack(side='left')
        var=tk.StringVar(value=value);ttk.Entry(row,textvariable=var).pack(side='left',fill='x',expand=True);return var
    def text(self,label,height=3):
        ttk.Label(self.body,text=label).pack(anchor='w');widget=tk.Text(self.body,height=height,wrap='word');widget.pack(fill='x',pady=2);return widget
    def buttons(self,items):
        row=ttk.Frame(self.body);row.pack(fill='x',pady=5)
        for title,callback in items:ttk.Button(row,text=title,command=callback).pack(side='left',padx=3)
    def ws_choice(self,label):
        values=[f"WS{m['ws']} - {m['name']}" for m in self.store.maps()];return self.choose(label,values)
    def ws(self,var):return int(var.get().split(' ',1)[0][2:])
    def select(self,key):
        if self.busy:self.status.set('Wait for the current operation before changing sections');return
        self.persist_draft(schedule=False)
        self.token+=1;self.current_key=key;self.image_path=None;self.crop=None;self.frame=0;self.last_ocr={}
        for child in self.body.winfo_children():child.destroy()
        step=next((s for s in STEPS if s[0]==key),(key,'References' if key=='references' else 'Setup saved','Review, replace or explicitly clear active associations.'))
        self.request.set(step[1]+'\n'+step[2]);self.sections.set(step[1])
        if key=='references':self.references_form();return
        if key=='map_label':
            self.ws_var=self.ws_choice('Confirmed WS map');self.label=self.entry('Visible/corrected label')
            self.buttons([('Define top-label region',lambda:self.define(1)),('Read current label',self.read_map),('Confirm label -> WS',self.save_map)])
        elif key=='subareas':
            self.ws_var=self.ws_choice('WS map');self.quadrant=self.choose('Quadrant',['TL','TR','BL','BR']);self.subarea=self.entry('Subarea name')
            self.image_controls();self.buttons([('Save subarea reference',self.save_subarea)])
            self.show_records('manual_subareas')
        elif key=='portals':
            self.source_ws=self.ws_choice('Source WS map');self.destination_ws=self.ws_choice('Destination WS map')
            self.number=self.choose('Portal number',['1','2','3','4']);self.role=self.choose('Crop role',['arch','center','night_arch']);self.threshold=self.entry('Match threshold (.1-.99)','.65')
            self.image_controls();self.buttons([('Save portal crop',self.save_portal),('Save threshold',self.save_threshold),('Preview against image...',self.preview_portal)])
            self.show_records('manual_portals')
        elif key=='connections':
            self.source_ws=self.ws_choice('Source WS map');self.destination_ws=self.ws_choice('Destination WS map')
            self.direction=self.choose('Travel direction',['Up','Down','Left','Right']);self.number=self.choose('Assigned portal',['1','2','3','4']);self.bound=self.entry('Travel bound (ms)','10000')
            self.recovery=tk.BooleanVar(value=False);ttk.Checkbutton(self.body,text='Allow existing configured World Map recovery if travel fails',variable=self.recovery).pack(anchor='w')
            self.buttons([('Save directed connection',self.save_connection),('Start travel (manual)',self.start_travel)])
            ttk.Label(self.body,text='Start from a confirmed waystone. Travel is bounded; F12 stops. Destination must be confirmed by its map label.',wraplength=940).pack(anchor='w')
            self.show_records('manual_connections')
        elif key.startswith('boss_'):
            self.notification_state=key[5:].upper();self.kind=self.choose('Visible notification type',['Boss','Miniboss'])
            self.buttons([('Define notification region',lambda:self.define(2))]);self.image_controls()
            self.buttons([('OCR supplied crop',self.ocr),('Capture configured notification',lambda:self.read_capture('boss_banner'))])
            self.raw=self.text('Raw OCR (you may correct visible text below)',3)
            self.visible=self.entry('Corrected visible text');self.boss_name=self.entry('Boss/miniboss name');self.spawn_map=self.entry('Visible spawn map');self.spawn=self.entry('Visible spawn area/landmark');self.player=self.entry('Visible defeating player')
            ttk.Label(self.body,text='Leave fields blank when missing/uncertain. Names must be visible substrings; no format is guessed.').pack(anchor='w')
            self.buttons([('Confirm real format/example',self.save_notification)])
        elif key=='tooltips':
            self.ws_var=self.ws_choice('Whole map area');self.image_controls();self.buttons([('OCR supplied tooltip',self.ocr)])
            self.raw=self.text('Raw OCR / unassigned names (inspect symbols and colors in the crop)',3)
            groups=ttk.Frame(self.body);groups.pack(fill='x');self.groups={}
            for label in ('common_mobs','rare_mobs','minibosses','bosses'):
                box=ttk.Frame(groups);box.pack(side='left',fill='both',expand=True,padx=3);ttk.Label(box,text=label.replace('_',' ')).pack()
                text=tk.Text(box,height=3,width=21);text.pack(fill='x');self.groups[label]=text
            self.evidence=self.entry('Checked symbols/colors');self.confirmed=tk.BooleanVar(value=False)
            ttk.Checkbutton(self.body,text='I checked and corrected every category against the visible tooltip',variable=self.confirmed).pack(anchor='w')
            self.buttons([('Save confirmed map tooltip',self.save_tooltip)])
        elif key.startswith('tower_'):
            name={'tower_inside':'in_tower','tower_progress':'tower_progress','tower_cleared':'floor_cleared'}[key]
            code={'in_tower':3,'tower_progress':4,'floor_cleared':5}[name]
            self.buttons([('Define '+name,lambda:self.define(code)),('Read supplied region',lambda:self.read_capture(name))]);self.image_controls();self.raw=self.text('Current result / raw text',4)
            ttk.Label(self.body,text='Leave pending until you provide the region and a real example. Existing unrelated tower settings remain preserved.').pack(anchor='w')
        else:ttk.Label(self.body,text='Choose a section to review saved setup.').pack()
        self.restore_draft()
    def persist_draft(self,schedule=True):
        if self.closed:return
        if self.current_key not in (None,'references','complete') and not self.busy:
            payload={}
            for name,value in vars(self).items():
                if isinstance(value,tk.Variable) and name not in ('request','status','image_info'):
                    try:payload[name]=value.get()
                    except tk.TclError:pass
            payload.update(image_path=str(self.image_path) if self.image_path else None,crop=self.crop,frame=self.frame,last_ocr=self.last_ocr)
            if hasattr(self,'raw') and self.raw.winfo_exists():payload['raw_text']=self.raw.get('1.0','end').strip()
            if self.current_key=='tooltips':payload['groups']={k:w.get('1.0','end').strip() for k,w in self.groups.items()}
            key=self.current_key
            def save():
                with connect(self.store.root) as c:c.execute('INSERT OR REPLACE INTO reference_setup_drafts VALUES (?,?)',(key,json.dumps(payload)))
            self.worker.submit(save)
        if schedule:self.window.after(2000,self.persist_draft)
    def restore_draft(self):
        with connect(self.store.root) as c:row=c.execute('SELECT payload_json FROM reference_setup_drafts WHERE key=?',(self.current_key,)).fetchone()
        if not row:return
        payload=json.loads(row[0])
        for name,value in payload.items():
            field=getattr(self,name,None)
            if isinstance(field,tk.Variable):field.set(value)
        self.image_path=Path(payload['image_path']) if payload.get('image_path') else None
        self.crop=payload.get('crop');self.frame=payload.get('frame',0);self.last_ocr=payload.get('last_ocr',{})
        if hasattr(self,'raw') and self.raw.winfo_exists():self.raw.delete('1.0','end');self.raw.insert('end',payload.get('raw_text',''))
        if self.current_key=='tooltips':
            for key,text in payload.get('groups',{}).items():
                if key in self.groups:self.groups[key].insert('end',text)
        if self.image_path and hasattr(self,'image_info'):self.image_info.set('Saved draft: '+str(self.image_path)+' | crop '+str(self.crop))
    def image_controls(self):
        self.image_info=tk.StringVar(value='No image selected. Choose a supplied crop or exported asset; no cache matching.')
        ttk.Label(self.body,textvariable=self.image_info,wraplength=950).pack(anchor='w',pady=3)
        self.buttons([('Choose image...',self.pick_image),('Crop / choose frame...',self.crop_image)])
        self.preview=ttk.Label(self.body,anchor='center');self.preview.pack(fill='x',pady=3)
    def pick_image(self):
        path=filedialog.askopenfilename(parent=self.window,title='Select exported asset or manually supplied image',filetypes=[('Images','*.png *.jpg *.jpeg *.webp *.gif *.bmp'),('All files','*.*')])
        if not path:return
        self.image_path=Path(path);self.crop=None;self.frame=0;self.preview_image()
    def preview_image(self):
        if not self.image_path:return
        path=self.image_path;crop=self.crop;frame=self.frame
        def work():
            with Image.open(path) as image:
                image.seek(frame);dimensions=image.size;image=image.convert('RGBA')
                if crop:x,y,w,h=crop;image=image.crop((x,y,x+w,y+h))
                image.thumbnail((900,180));return image,dimensions
        def done(result):
            image,dimensions=result;self.photo=ImageTk.PhotoImage(image,master=self.window);self.preview.configure(image=self.photo)
            self.image_info.set(f'{path.name} | {dimensions} | crop {crop or "full image"} | frame {frame}')
        self.run(work,done)
    def crop_image(self):
        if not self.image_path:self.status.set('Choose an image first');return
        from scripts.reference_cropper import CropWindow
        def chosen(crop,frame):self.crop=crop;self.frame=frame;self.preview_image()
        CropWindow(self.window,self.image_path,chosen)
    def image_snapshot(self):
        if not self.image_path:raise ValueError('Choose or capture an image first')
        return self.image_path,list(self.crop) if self.crop else None,self.frame
    def working_image(self,snapshot):
        path,crop,frame=snapshot
        with Image.open(path) as image:
            image.seek(frame);image=image.convert('RGBA')
            if crop:x,y,w,h=crop;image=image.crop((x,y,x+w,y+h))
            import io
            data=io.BytesIO();image.save(data,format='PNG');data=data.getvalue()
        folder=self.store.root/'references/working';folder.mkdir(parents=True,exist_ok=True);target=folder/(hashlib.sha256(data).hexdigest()+'.png')
        if not target.exists():target.write_bytes(data)
        return target
    def ocr(self):
        try:snapshot=self.image_snapshot()
        except Exception as exc:self.status.set(str(exc));return
        def work():
            from scripts.reference_ocr import ocr_image
            return ocr_image(self.working_image(snapshot))
        self.run(work,self.ocr_done)
    def ocr_done(self,result):
        self.last_ocr=result
        if hasattr(self,'raw') and self.raw.winfo_exists():self.raw.delete('1.0','end');self.raw.insert('end',result.get('text',json.dumps(result)))
        if self.current_key.startswith('boss_'):self.visible.set(result.get('text',''))
        if self.current_key=='tooltips':
            # Headings are proposals; unknown symbol/color meanings are left unassigned.
            category=None
            for widget in self.groups.values():widget.delete('1.0','end')
            def position(item):
                box=item.get('box') or [[0,0]]
                return min(p[1] for p in box),min(p[0] for p in box)
            for item in sorted(result.get('items',[]),key=position):
                text=item['text'].strip();lower=text.lower().rstrip(':')
                heading={'common mobs':'common_mobs','rare mobs':'rare_mobs','minibosses':'minibosses','mini bosses':'minibosses','bosses':'bosses'}.get(lower)
                if heading:category=heading;continue
                if category:self.groups[category].insert('end',text+'\n')
            self.status.set('OCR proposals only. Check visible symbols/colors and move uncertain names into the correct category before saving.')
    def read_map(self):
        def work():
            from scripts.reference_ocr import read_indicator
            return read_indicator('map_name')
        self.run(work,lambda r:(self.label.set(r.get('text','')),self.status.set(json.dumps(r,ensure_ascii=False))))
    def read_capture(self,name):
        def work():
            from scripts.reference_ocr import read_indicator
            result=read_indicator(name)
            if result.get('crop_path'):
                source=Path(result['crop_path']);data=source.read_bytes()
                folder=self.store.root/'references/captures';folder.mkdir(parents=True,exist_ok=True)
                path=folder/(hashlib.sha256(data).hexdigest()+'.png')
                if not path.exists():path.write_bytes(data)
                result['crop_path']=str(path)
            return result
        def done(result):
            self.ocr_done(result)
            if result.get('crop_path'):
                self.image_path=Path(result['crop_path']);self.crop=None;self.frame=0
                self.preview_image()
        self.run(work,done)
    def define(self,code):
        from scripts.macro_bridge import macro_message
        try:macro_message(0x8004,code);self.status.set('Drag the requested region in Roblox, save it, then return to this checklist.')
        except Exception as exc:self.status.set(str(exc))
    def save_map(self):
        ws=self.ws(self.ws_var);text=self.label.get()
        def work():
            from scripts.indicator_regions import RegionStore
            row=next((r for r in RegionStore().list() if r['name']=='map_name' and r['kind']=='ocr' and r['enabled']),None)
            if not row:raise ValueError('Define and save the map_name OCR region first')
            self.store.save_map_alias(ws,text)
        self.run(work,lambda _:self.refresh())
    def save_subarea(self):
        try:path,crop,frame=self.image_snapshot();ws=self.ws(self.ws_var);q=self.quadrant.get();name=self.subarea.get()
        except Exception as exc:self.status.set(str(exc));return
        self.run(lambda:self.store.save_subarea(ws,q,name,path,crop,frame),lambda rid:self.status.set('Saved subarea '+rid+'; add more or confirm this section complete.'))
    def save_portal(self):
        try:path,crop,frame=self.image_snapshot();source=self.ws(self.source_ws);destination=self.ws(self.destination_ws);number=self.number.get();role=self.role.get();threshold=float(self.threshold.get())
        except Exception as exc:self.status.set(str(exc));return
        if crop is None:self.status.set('Crop an individual arch or animated center before saving');return
        self.run(lambda:self.store.save_portal(source,destination,number,role,path,crop,frame,threshold),lambda rid:self.status.set('Saved '+role+' '+rid+'; crop the other part or another day/night variant.'))
    def save_threshold(self):
        try:source=self.ws(self.source_ws);number=int(self.number.get());value=float(self.threshold.get())
        except Exception as exc:self.status.set(str(exc));return
        def work():
            if not .1<=value<=.99:raise ValueError('Threshold must be .1-.99')
            with connect(self.store.root) as c:
                row=c.execute('UPDATE manual_portals SET threshold=? WHERE source_ws=? AND number=?',(value,source,number))
                if row.rowcount!=1:raise ValueError('Save an arch for this portal first')
            self.store.export()
        self.run(work)
    def save_connection(self):
        try:args=(self.ws(self.source_ws),self.ws(self.destination_ws),self.direction.get(),int(self.number.get()),int(self.bound.get()),self.recovery.get())
        except Exception as exc:self.status.set(str(exc));return
        self.run(lambda:self.store.save_connection(*args))
    def start_travel(self):
        source=self.ws(self.source_ws);destination=self.ws(self.destination_ws)
        if not messagebox.askyesno('Start bounded AHK travel?',f'Confirm you are at the waystone in WS{source}. Start configured travel to WS{destination}? F12 stops.',parent=self.window):return
        try:
            from scripts.macro_bridge import macro_message
            macro_message(0x8007,source,destination);self.status.set('AHK travel requested. Report the result in VS Code; F12 stops.')
        except Exception as exc:self.status.set(str(exc))
    def save_notification(self):
        try:snapshot=self.image_snapshot();raw=self.last_ocr.get('text',self.raw.get('1.0','end').strip())
        except Exception as exc:self.status.set(str(exc));return
        fields=dict(kind=self.kind.get(),visible_text=self.visible.get(),boss_name=self.boss_name.get(),spawn_map=self.spawn_map.get(),spawn_area=self.spawn.get(),defeating_player=self.player.get())
        state=self.notification_state
        def work():return self.store.save_notification(state,self.working_image(snapshot),raw,fields,None)
        self.run(work,lambda _:self.refresh())
    def save_tooltip(self):
        if not self.confirmed.get():self.status.set('Check and confirm the categories against the crop first');return
        try:snapshot=self.image_snapshot();ws=self.ws(self.ws_var)
        except Exception as exc:self.status.set(str(exc));return
        raw=self.last_ocr.get('text',self.raw.get('1.0','end').strip());groups={key:[x.strip() for x in widget.get('1.0','end').splitlines() if x.strip()] for key,widget in self.groups.items()};evidence=self.evidence.get()
        self.run(lambda:self.store.save_tooltip(ws,self.working_image(snapshot),raw,groups,evidence))
    def preview_portal(self):
        path=filedialog.askopenfilename(parent=self.window,title='Choose a manually captured scene for portal preview',filetypes=[('Images','*.png *.jpg *.jpeg *.webp')])
        if not path:return
        source=self.ws(self.source_ws);destination=self.ws(self.destination_ws)
        def work():
            import cv2
            from scripts.portal_matching import match_portal
            frame=cv2.imread(path)
            if frame is None:raise ValueError('Image unavailable')
            result=match_portal(frame,source,destination)
            if result.get('box'):
                x,y,w,h=result['box'];cv2.rectangle(frame,(x,y),(x+w,y+h),(0,255,0),2)
            image=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB));image.thumbnail((900,220));return result,image
        def done(value):
            result,image=value;self.photo=ImageTk.PhotoImage(image,master=self.window);self.preview.configure(image=self.photo);self.status.set(json.dumps(result))
        self.run(work,done)
    def show_records(self,table):
        listing=tk.Listbox(self.body,height=3);listing.pack(fill='x',pady=4)
        for row in self.store.list_rows(table):listing.insert('end',' | '.join(f'{k}={v}' for k,v in row.items() if k not in ('reference_id','id')))
    def references_form(self):
        self.reference_list=tk.Listbox(self.body,height=12);self.reference_list.pack(fill='both',expand=True)
        self.reference_rows=[]
        for row in self.store.list_rows('manual_references'):self.reference_rows.append(dict(key='manual:'+row['id'],name=row['name'],path=row['path']))
        from scripts.indicator_regions import RegionStore
        for row in RegionStore().list():
            if row['reference_name']:self.reference_rows.append(dict(key='indicator:'+row['name'],name='Indicator '+row['name'],path=row['reference_name']))
        # Include retained AHK references; no configuration is changed unless selected explicitly.
        import configparser
        ini=self.store.root/'waystone_config.ini';raw=ini.read_bytes();text=raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8-sig')
        cfg=configparser.ConfigParser(interpolation=None);cfg.optionxform=str;cfg.read_string(text)
        for section in cfg.sections():
            for key,value in cfg.items(section):
                if Path(value).suffix.lower() in ('.png','.jpg','.jpeg','.webp','.bmp'):self.reference_rows.append(dict(key=f'ini:{section}:{key}',name=f'{section}/{key}',path=value))
        for row in self.reference_rows:self.reference_list.insert('end',row['name']+' | '+row['path'])
        self.buttons([('Replace selected...',lambda:self.change_selected(True)),('Clear selected association',lambda:self.change_selected(False))])
        ttk.Label(self.body,text='Permanent Delete is blocked while an exported image is associated here. Replacing/clearing an association keeps public files intact. AHK reference changes are applied with automation stopped.',wraplength=940).pack(anchor='w')
    def change_selected(self,replace):
        chosen=self.reference_list.curselection()
        if not chosen:return
        row=self.reference_rows[chosen[0]];replacement=None
        if replace:
            replacement=filedialog.askopenfilename(parent=self.window,title='Select replacement image',filetypes=[('Images','*.png *.jpg *.jpeg *.webp *.bmp')])
            if not replacement:return
        elif not messagebox.askyesno('Clear association?',row['name']+' will be disabled/unassigned. Keep its image file?',parent=self.window):return
        def work():change_association(row['key'],replacement);return row['key']
        def done(key):
            if key.startswith('ini:'):
                from scripts.macro_bridge import macro_message
                try:macro_message(0x8009)
                except Exception as exc:self.status.set('Saved; reload macro to apply: '+str(exc))
            self.select('references')
        self.run(work,done)
    def complete(self):
        if self.current_key in ('complete','references'):return
        if not messagebox.askyesno('Confirm section complete','Confirm you supplied and checked all references you need in this section. Unavailable items should stay pending.',parent=self.window):return
        key=self.current_key
        def work():
            table={'subareas':'manual_subareas','portals':'manual_portals','connections':'manual_connections','tooltips':'manual_map_tooltips'}.get(key)
            if table and not self.store.list_rows(table):raise ValueError('Supply a record first, or leave this section pending')
            if key.startswith('tower_'):
                from scripts.indicator_regions import RegionStore
                name={'tower_inside':'in_tower','tower_progress':'tower_progress','tower_cleared':'floor_cleared'}[key]
                if not any(r['name']==name and r['enabled'] for r in RegionStore().list()):raise ValueError('Supply this tower region first')
                if not self.last_ocr.get('ok'):raise ValueError('Read the actual tower indicator and check it before confirming')
            if key.startswith('boss_') or key=='map_label':
                if self.store.progress()[key]['status']!='complete':raise ValueError('Save and confirm the requested region/example first; leave unavailable items pending')
            self.store.mark(key)
        self.run(work,lambda _:self.refresh())
    def pending(self):
        if self.current_key not in ('complete','references'):self.store.mark(self.current_key,'pending');self.refresh()
    def close(self):
        self.persist_draft(schedule=False)
        self.closed=True;self.worker.shutdown(wait=False,cancel_futures=False);self.window.destroy()
