"""Persistent, local-only manual reference setup. Existing public assets are immutable inputs."""
from contextlib import contextmanager
from pathlib import Path
import configparser
import hashlib
import json
import re
import sqlite3
import time
import uuid

ROOT=Path(__file__).resolve().parents[1]
STEPS=[
 ('map_label','Map identity','Stand where the top map name is visible. Use Define Indicator Region, crop only the top map-name label, name it map_name, choose OCR and Save. Then read it and confirm its WS number in Reference Setup.'),
 ('subareas','Subareas','Choose a WS number, TL/TR/BL/BR, type the subarea name, and choose its image. Save each manually confirmed subarea.'),
 ('portals','Portal references','Choose source and destination WS numbers and portal 1/2 (optional 3/4). Open an exported sheet, crop the arch and center separately; set thresholds and review previews.'),
 ('connections','Directed connections','Choose source and destination WS numbers, Up/Down/Left/Right and the assigned portal. Travel starts only when you explicitly choose Start travel.'),
 ('boss_coming','Boss/miniboss: Coming','Save a notification region named boss_banner. Capture a real Coming notification and supply its exact visible fields; missing fields stay unknown.'),
 ('boss_appeared','Boss/miniboss: Appeared','Capture a real Appeared notification in the configured notification region. Confirm visible names, map/area, and exact raw text.'),
 ('boss_already_in','Boss/miniboss: Already In','Capture a real Already In notification; annotate only fields actually shown.'),
 ('boss_defeated','Boss/miniboss: Defeated','Capture a Defeated notification; confirm the visible defeating player when present.'),
 ('tooltips','World Map tooltips','Choose WS number and supply a cropped World Map tooltip. Run local OCR; confirm each categorized name and its visible symbol/color before saving.'),
 ('tower_inside','Tower: inside','Pending your later example. Draw an OCR/image region named in_tower when you can supply an inside-tower indicator.'),
 ('tower_progress','Tower: floor/progress','Pending your later example. Supply tower_progress region and visible current floor/progress text.'),
 ('tower_cleared','Tower: floor cleared','Pending your later example. Supply floor_cleared region and a real cleared example.')]

@contextmanager
def connect(root=ROOT):
    conn=sqlite3.connect(Path(root)/'agent_memory.db',timeout=15);conn.row_factory=sqlite3.Row
    try:
        with conn:yield conn
    finally:conn.close()

def atomic_json(path,data):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    temp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(path)

def map_catalog(root=ROOT):
    text=(Path(root)/'src/MapRoutes.ahk').read_text(encoding='utf-8-sig')
    return [dict(ws=int(ws),name=re.sub(r'^WS #\d+:\s*','',label),file=file) for ws,label,file in
            re.findall(r'(\d+),\s*\{\s*label:\s*"([^"]+)"\s*,\s*file:\s*"([^"]+)"',text)]

class SetupStore:
    def __init__(self,root=ROOT):
        self.root=Path(root)
        with connect(self.root) as c:
            c.executescript('''CREATE TABLE IF NOT EXISTS reference_setup_progress(key TEXT PRIMARY KEY,status TEXT NOT NULL,notes TEXT NOT NULL DEFAULT '',updated_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS reference_setup_drafts(key TEXT PRIMARY KEY,payload_json TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS manual_references(id TEXT PRIMARY KEY,kind TEXT NOT NULL,name TEXT NOT NULL,path TEXT NOT NULL,source_path TEXT,source_sha TEXT,crop_json TEXT NOT NULL,metadata_json TEXT NOT NULL,updated_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS manual_subareas(id TEXT PRIMARY KEY,ws INTEGER NOT NULL,quadrant TEXT NOT NULL,name TEXT NOT NULL,reference_id TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS manual_portals(id TEXT PRIMARY KEY,source_ws INTEGER NOT NULL,number INTEGER NOT NULL,destination_ws INTEGER NOT NULL,arch_id TEXT,center_id TEXT,night_arch_id TEXT,threshold REAL NOT NULL DEFAULT .65,UNIQUE(source_ws,number));
                CREATE TABLE IF NOT EXISTS manual_portal_frames(portal_id TEXT NOT NULL,reference_id TEXT NOT NULL,PRIMARY KEY(portal_id,reference_id));
                CREATE TABLE IF NOT EXISTS manual_connections(source_ws INTEGER NOT NULL,destination_ws INTEGER NOT NULL,direction TEXT NOT NULL,portal_number INTEGER NOT NULL,travel_ms INTEGER NOT NULL,recovery INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(source_ws,destination_ws));
                CREATE TABLE IF NOT EXISTS manual_notification_examples(id TEXT PRIMARY KEY,status TEXT NOT NULL,reference_id TEXT NOT NULL,raw_text TEXT NOT NULL,fields_json TEXT NOT NULL,pattern TEXT,confirmed INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS manual_map_tooltips(ws INTEGER PRIMARY KEY,reference_id TEXT NOT NULL,raw_text TEXT NOT NULL,confirmed_json TEXT NOT NULL);
            ''')
            for key,_,_ in STEPS:c.execute('INSERT OR IGNORE INTO reference_setup_progress(key,status,updated_at) VALUES (?,\'pending\',?)',(key,time.time()))
    def progress(self):
        with connect(self.root) as c:return {r['key']:dict(r) for r in c.execute('SELECT * FROM reference_setup_progress')}
    def current(self):
        progress=self.progress()
        return next((dict(key=k,title=t,request=r,**{a:b for a,b in progress[k].items() if a not in ('key',)}) for k,t,r in STEPS if progress[k]['status']!='complete'),dict(key='complete',title='Setup saved',request='All sections marked complete. Reopen Reference Setup to review or correct them.'))
    def mark(self,key,status='complete',notes=''):
        if key not in {s[0] for s in STEPS}:raise ValueError('Unknown setup section')
        with connect(self.root) as c:c.execute('UPDATE reference_setup_progress SET status=?,notes=?,updated_at=? WHERE key=?',(status,notes,time.time(),key))
    def export(self):
        (self.root/'config').mkdir(exist_ok=True)
        with connect(self.root) as c:
            refs={r['id']:dict(r) for r in c.execute('SELECT * FROM manual_references')}
            portals=[dict(r) for r in c.execute('SELECT * FROM manual_portals')]
            for portal in portals:portal['center_frames']=[r[0] for r in c.execute('SELECT reference_id FROM manual_portal_frames WHERE portal_id=?',(portal['id'],))]
            edges=[dict(r) for r in c.execute('SELECT * FROM manual_connections')]
            subareas=[dict(r) for r in c.execute('SELECT * FROM manual_subareas')]
        atomic_json(self.root/'config/navigation_references.json',dict(version=1,maps=map_catalog(self.root),references=refs,portals=portals,connections=edges,subareas=subareas))
        cfg=configparser.ConfigParser(interpolation=None)
        for edge in edges:cfg[f"Connection_{edge['source_ws']}_{edge['destination_ws']}"]={k:str(v) for k,v in edge.items()}
        target=self.root/'config/manual_navigation.ini';temp=target.with_suffix('.tmp')
        with temp.open('w',encoding='utf-16') as out:cfg.write(out)
        temp.replace(target)

    def maps(self):return map_catalog(self.root)
    def valid_ws(self,ws):
        ws=int(ws)
        if ws not in {m['ws'] for m in self.maps()}:raise ValueError('Choose an existing WS number')
        return ws
    def list_rows(self,table):
        allowed={'manual_references','manual_subareas','manual_portals','manual_connections','manual_map_tooltips','manual_notification_examples'}
        if table not in allowed:raise ValueError('Unknown record type')
        with connect(self.root) as c:return [dict(r) for r in c.execute('SELECT * FROM '+table)]
    def save_map_alias(self,ws,text):
        ws=self.valid_ws(ws);text=' '.join(text.split()).strip()
        if not text:raise ValueError('Confirm a visible map label first')
        with connect(self.root) as c:
            c.execute('CREATE TABLE IF NOT EXISTS manual_map_aliases(text_key TEXT PRIMARY KEY,ws INTEGER NOT NULL,visible_text TEXT NOT NULL)')
            c.execute('INSERT OR REPLACE INTO manual_map_aliases VALUES (?,?,?)',(text.casefold(),ws,text))
        self.mark('map_label','complete',f'WS{ws}: {text}')
    def save_image(self,source,kind,name,crop=None,frame=0,metadata=None,subarea=False):
        from PIL import Image
        source=Path(source).resolve()
        if not source.is_file():raise ValueError('Choose an available image')
        source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
        with Image.open(source) as image:
            frame=int(frame)
            if frame<0 or frame>=getattr(image,'n_frames',1):raise ValueError('Frame does not exist')
            image.seek(frame);image=image.convert('RGBA')
            if crop is None:crop=[0,0,*image.size]
            x,y,w,h=map(int,crop)
            if min(x,y)<0 or min(w,h)<2 or x+w>image.width or y+h>image.height:raise ValueError('Crop must stay inside the source image')
            image=image.crop((x,y,x+w,y+h))
            import io
            out=io.BytesIO();image.save(out,format='PNG');data=out.getvalue()
        name=re.sub(r'[^\w .-]+','_',name,flags=re.UNICODE).strip(' ._')[:150]
        if not name:raise ValueError('Provide a reference name')
        # Add new files without touching any pre-existing public asset.
        folder=self.root/'public/maps/map_area/subareas'/('WS'+str((metadata or {}).get('ws',0))) if subarea else self.root/'references'/kind
        folder.mkdir(parents=True,exist_ok=True);target=folder/(name+'.png')
        suffix=1
        while target.exists():
            if target.read_bytes()==data:break
            suffix+=1;target=folder/(name+f'_{suffix}.png')
        if not target.exists():
            with target.open('xb') as out:out.write(data)
        digest=hashlib.sha256(data).hexdigest()
        rid=hashlib.sha256((kind+'|'+target.relative_to(self.root).as_posix()).encode()).hexdigest()[:24]
        meta=dict(metadata or {});meta.update(frame=frame,image_sha=digest)
        with connect(self.root) as c:c.execute('INSERT OR REPLACE INTO manual_references VALUES (?,?,?,?,?,?,?,?,?)',
            (rid,kind,target.stem,target.relative_to(self.root).as_posix(),str(source),source_sha,json.dumps([x,y,w,h]),json.dumps(meta),time.time()))
        return rid
    def save_subarea(self,ws,quadrant,name,source,crop=None,frame=0):
        ws=self.valid_ws(ws)
        if quadrant not in ('TL','TR','BL','BR'):raise ValueError('Choose TL/TR/BL/BR')
        name=name.strip()
        if not name:raise ValueError('Type the subarea name')
        rid=self.save_image(source,'subareas',f'WS{ws}_{quadrant}_{name}',crop,frame,dict(ws=ws,quadrant=quadrant,subarea=name),subarea=True)
        with connect(self.root) as c:c.execute('INSERT OR REPLACE INTO manual_subareas VALUES (?,?,?,?,?)',(rid,ws,quadrant,name,rid))
        self.export();return rid
    def save_portal(self,source_ws,destination_ws,number,role,source,crop,frame=0,threshold=.65):
        source_ws=self.valid_ws(source_ws);destination_ws=self.valid_ws(destination_ws);number=int(number);threshold=float(threshold)
        if source_ws==destination_ws:raise ValueError('Source and destination must differ')
        if number not in (1,2,3,4) or role not in ('arch','center','night_arch'):raise ValueError('Choose portal 1-4 and arch/center/night_arch')
        if not .1<=threshold<=.99:raise ValueError('Threshold must be .1-.99')
        with connect(self.root) as c:
            prior=c.execute('SELECT * FROM manual_portals WHERE source_ws=? AND number=?',(source_ws,number)).fetchone()
            if prior and prior['destination_ws']!=destination_ws:
                if any(prior[k] for k in ('arch_id','center_id','night_arch_id')):
                    raise ValueError('This portal has another destination; clear its existing arch/center associations first')
                c.execute('UPDATE manual_portals SET destination_ws=? WHERE id=?',(destination_ws,prior['id']))
        label=next(m['name'] for m in self.maps() if m['ws']==source_ws)
        rid=self.save_image(source,'portals',f'WS{source_ws}-{label}_Portal{number}_to_WS{destination_ws}_{role}',crop,frame,
            dict(source_ws=source_ws,destination_ws=destination_ws,portal_number=number,role=role,threshold=threshold))
        with connect(self.root) as c:
            previous=c.execute('SELECT * FROM manual_portals WHERE source_ws=? AND number=?',(source_ws,number)).fetchone()
            if previous and previous['destination_ws']!=destination_ws:raise ValueError('This portal already has another destination; clear its association before reassigning')
            portal_id=f'WS{source_ws}_Portal{number}'
            c.execute('INSERT OR IGNORE INTO manual_portals(id,source_ws,number,destination_ws,threshold) VALUES (?,?,?,?,?)',(portal_id,source_ws,number,destination_ws,threshold))
            column={'arch':'arch_id','center':'center_id','night_arch':'night_arch_id'}[role]
            c.execute('UPDATE manual_portals SET '+column+'=?,threshold=? WHERE id=?',(rid,threshold,portal_id))
            if role=='center':c.execute('INSERT OR IGNORE INTO manual_portal_frames VALUES (?,?)',(portal_id,rid))
        self.export();return rid
    def save_connection(self,source,destination,direction,portal,travel_ms,recovery=False):
        source=self.valid_ws(source);destination=self.valid_ws(destination);portal=int(portal);travel_ms=int(travel_ms)
        if source==destination or direction not in ('Up','Down','Left','Right'):raise ValueError('Choose distinct maps and a direction')
        if not 250<=travel_ms<=30000:raise ValueError('Travel bound must be 250-30000 ms')
        with connect(self.root) as c:
            row=c.execute('SELECT arch_id FROM manual_portals WHERE source_ws=? AND number=? AND destination_ws=?',(source,portal,destination)).fetchone()
            if not row or not row['arch_id']:raise ValueError('Save the assigned portal arch for these maps first')
            c.execute('INSERT OR REPLACE INTO manual_connections VALUES (?,?,?,?,?,?)',(source,destination,direction,portal,travel_ms,int(recovery)))
        self.export()
    def save_notification(self,status,source,raw,fields,pattern):
        if status not in ('COMING','APPEARED','ALREADY_IN','DEFEATED'):raise ValueError('Choose a notification state')
        from scripts.notification_formats import make_pattern
        pattern=make_pattern(fields.get('visible_text',raw),fields)
        rid=self.save_image(source,'notifications',status+'_'+hashlib.sha256(raw.encode()).hexdigest()[:10])
        eid=hashlib.sha256((status+'|'+raw).encode()).hexdigest()[:24]
        with connect(self.root) as c:c.execute('INSERT OR REPLACE INTO manual_notification_examples VALUES (?,?,?,?,?,?,1)',(eid,status,rid,raw,json.dumps(fields),pattern))
        self.mark('boss_'+status.lower(),'complete','User-confirmed example saved');return rid
    def save_tooltip(self,ws,source,raw,groups,evidence):
        ws=self.valid_ws(ws)
        if not evidence.strip():raise ValueError('Record the visible symbol/color evidence you checked')
        if set(groups)!={'common_mobs','rare_mobs','minibosses','bosses'}:raise ValueError('Confirm all four categories; empty lists are allowed')
        rid=self.save_image(source,'tooltips',f'WS{ws}_Tooltip')
        with connect(self.root) as c:c.execute('INSERT OR REPLACE INTO manual_map_tooltips VALUES (?,?,?,?)',(ws,rid,raw,json.dumps(dict(categories=groups,evidence=evidence))))
        return rid
    def clear_reference(self,rid):
        with connect(self.root) as c:
            for column in ('arch_id','center_id','night_arch_id'):c.execute('UPDATE manual_portals SET '+column+'=NULL WHERE '+column+'=?',(rid,))
            c.execute('DELETE FROM manual_portal_frames WHERE reference_id=?',(rid,))
            c.execute('DELETE FROM manual_subareas WHERE reference_id=?',(rid,))
            c.execute('DELETE FROM manual_notification_examples WHERE reference_id=?',(rid,))
            c.execute('DELETE FROM manual_map_tooltips WHERE reference_id=?',(rid,))
            c.execute('DELETE FROM manual_references WHERE id=?',(rid,))
        self.export()

    def replace_reference(self,rid,source):
        with connect(self.root) as c:row=c.execute('SELECT * FROM manual_references WHERE id=?',(rid,)).fetchone()
        if not row:raise ValueError('Reference no longer exists')
        new_id=self.save_image(source,row['kind'],row['name']+'_replacement',metadata=json.loads(row['metadata_json']))
        with connect(self.root) as c:
            for col in ('arch_id','center_id','night_arch_id'):c.execute('UPDATE manual_portals SET '+col+'=? WHERE '+col+'=?',(new_id,rid))
            c.execute('UPDATE OR IGNORE manual_portal_frames SET reference_id=? WHERE reference_id=?',(new_id,rid))
            for table in ('manual_subareas','manual_notification_examples','manual_map_tooltips'):c.execute('UPDATE '+table+' SET reference_id=? WHERE reference_id=?',(new_id,rid))
            if new_id!=rid:c.execute('DELETE FROM manual_references WHERE id=?',(rid,))
        self.export();return new_id

def active_image_uses(digest,root=ROOT):
    """Conservative content-based guard, including independent crops' source sheets."""
    root=Path(root);uses=[]
    def matches(path):
        try:return hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest
        except OSError:return False
    with connect(root) as c:
        if c.execute("SELECT 1 FROM sqlite_master WHERE name='manual_references'").fetchone():
            for row in c.execute('SELECT * FROM manual_references'):
                if row['source_sha']==digest or matches(root/row['path']):uses.append(dict(key='manual:'+row['id'],name=row['name'],path=row['path']))
        if c.execute("SELECT 1 FROM sqlite_master WHERE name='indicator_regions'").fetchone():
            for row in c.execute('SELECT name,reference_name FROM indicator_regions WHERE enabled=1 AND reference_name IS NOT NULL'):
                if matches(root/row['reference_name']):uses.append(dict(key='indicator:'+row['name'],name='Indicator '+row['name'],path=row['reference_name']))
    ini=root/'waystone_config.ini'
    if ini.exists():
        raw=ini.read_bytes();text=raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8-sig')
        cfg=configparser.ConfigParser(interpolation=None);cfg.optionxform=str;cfg.read_string(text)
        for section in cfg.sections():
            for key,value in cfg.items(section):
                if Path(value).suffix.lower() in ('.png','.jpg','.jpeg','.webp','.bmp') and matches(root/value):
                    uses.append(dict(key=f'ini:{section}:{key}',name=f'{section} / {key}',path=value))
    return uses

def change_association(key,replacement=None,root=ROOT):
    root=Path(root)
    if key.startswith('manual:'):
        store=SetupStore(root)
        return store.replace_reference(key[7:],replacement) if replacement else store.clear_reference(key[7:])
    if key.startswith('indicator:'):
        from scripts.indicator_regions import RegionStore
        regions=RegionStore(root);name=key[10:]
        if replacement:
            from PIL import Image
            with Image.open(replacement) as image:digest=regions.add_reference(image)
            with regions.connect() as c:c.execute('UPDATE indicator_regions SET reference_name=?,enabled=1 WHERE name=?',('public/detection_references/'+digest+'.png',name))
        else:
            with regions.connect() as c:c.execute('UPDATE indicator_regions SET reference_name=NULL,enabled=0 WHERE name=?',(name,))
        regions.export();return
    if key.startswith('ini:'):
        _,section,option=key.split(':',2);path=root/'waystone_config.ini';raw=path.read_bytes()
        encoding='utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig'
        text=raw.decode(encoding);current='';lines=[]
        for line in text.splitlines(keepends=True):
            if line.strip().startswith('['):current=line.strip()[1:-1]
            if current==section and line.split('=',1)[0].strip()==option and '=' in line:
                line=option+'='+(str(Path(replacement).resolve()) if replacement else '__CLEARED__')+'\n'
            lines.append(line)
        path.write_text(''.join(lines),encoding=encoding)
        return
    raise ValueError('Unknown reference association')
