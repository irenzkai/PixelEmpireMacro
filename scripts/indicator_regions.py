"""Saved client-relative indicator geometry. No polling/detection loop is added."""
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import json
from pathlib import Path
import re
import sqlite3
import time
import uuid

ROOT=Path(__file__).resolve().parent.parent
CONFIG=ROOT/'config/indicator_regions.json'
ALIASES={'map_name':'top_bar'}
BUILTINS=('top_bar','minimap_label','center_prompt','boss_banner','world_map','tower_progress')


def normalized(rect,client):
    x,y,w,h=map(float,rect);cx,cy,cw,ch=map(float,client)
    result=[(x-cx)/cw,(y-cy)/ch,w/cw,h/ch]
    if min(result)<0 or result[2]<=0 or result[3]<=0 or result[0]+result[2]>1.000001 or result[1]+result[3]>1.000001:
        raise ValueError('Region must stay inside the Roblox client')
    return result


def screen_bounds(norm,client):
    x,y,w,h=norm;cx,cy,cw,ch=client
    left=cx+round(x*cw);top=cy+round(y*ch)
    right=min(cx+cw,cx+round((x+w)*cw));bottom=min(cy+ch,cy+round((y+h)*ch))
    return [left,top,max(1,right-left),max(1,bottom-top)]


def client_geometry(hwnd):
    u=ctypes.windll.user32
    # Other existing modules use equivalent custom RECT/POINT ctypes structures.
    u.GetClientRect.argtypes=[wintypes.HWND,ctypes.c_void_p]
    u.ClientToScreen.argtypes=[wintypes.HWND,ctypes.c_void_p]
    rect=wintypes.RECT();point=wintypes.POINT()
    if not u.GetClientRect(hwnd,ctypes.byref(rect)) or not u.ClientToScreen(hwnd,ctypes.byref(point)):
        raise ValueError('Roblox client is unavailable')
    dpi=96
    try:
        u.GetDpiForWindow.argtypes=[wintypes.HWND];dpi=u.GetDpiForWindow(hwnd) or 96
    except AttributeError:pass
    return [point.x,point.y,rect.right,rect.bottom],dpi


class RegionStore:
    def __init__(self,root=ROOT,db=None):
        self.root=Path(root);self.db=Path(db or self.root/'agent_memory.db')
        self.config=self.root/'config/indicator_regions.json'
        with self.connect() as conn:
            conn.execute('''CREATE TABLE IF NOT EXISTS indicator_regions (
                name TEXT PRIMARY KEY,kind TEXT NOT NULL,enabled INTEGER NOT NULL,
                normalized_json TEXT NOT NULL,reference_w INTEGER NOT NULL,reference_h INTEGER NOT NULL,
                reference_dpi INTEGER NOT NULL,expected_json TEXT NOT NULL,reference_name TEXT,
                builtin_alias TEXT,threshold REAL NOT NULL,updated_at REAL NOT NULL)''')
    @contextmanager
    def connect(self):
        conn=sqlite3.connect(self.db,timeout=10);conn.row_factory=sqlite3.Row
        try:
            with conn:yield conn
        finally:conn.close()
    @staticmethod
    def unpack(row):
        result=dict(row);result['normalized']=json.loads(result.pop('normalized_json'))
        result['expected_text']=json.loads(result.pop('expected_json'))
        return result
    def list(self):
        with self.connect() as conn:return [self.unpack(r) for r in conn.execute('SELECT * FROM indicator_regions ORDER BY name')]
    def add_reference(self,image):
        import hashlib
        folder=self.root/'public/detection_references';folder.mkdir(parents=True,exist_ok=True)
        import io
        output=io.BytesIO();image.convert('RGBA').save(output,format='PNG')
        data=output.getvalue();digest=hashlib.sha256(data).hexdigest();path=folder/(digest+'.png')
        if not path.exists():path.write_bytes(data)
        return digest

    def named_references(self):
        import hashlib
        references=[]
        # Existing confirmed references remain usable without their former index.
        for folder in ('public/detection_references','public/picker_assets','public/cache_assets','public/maps/map_area/subareas','references/portals','references/notifications','references/tooltips'):
            base=self.root/folder
            if not base.exists():continue
            for path in base.rglob('*'):
                if path.is_symlink() or any(p.startswith('.review_') for p in path.parts):continue
                if path.suffix.lower() not in ('.png','.jpg','.jpeg','.webp','.bmp'):continue
                references.append(dict(name=path.relative_to(self.root).as_posix(),path=path.relative_to(self.root).as_posix(),derived_sha=''))
        return sorted(references,key=lambda r:r['name'])
    def save(self,data,old_name=None):
        name=data['name'].strip()
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}',name):raise ValueError('Use a name such as map_name (letters, digits, _ or -)')
        kind=data['kind']
        if kind not in ('ocr','image'):raise ValueError('Choose OCR text or image match')
        norm=list(map(float,data['normalized']));normalized(norm,[0,0,1,1])
        expected=data.get('expected_text',[])
        if not isinstance(expected,list) or len(expected)>64 or any(not isinstance(t,str) or len(t)>512 for t in expected):
            raise ValueError('Expected text must be a list of short strings')
        alias=(data.get('builtin_alias') or ALIASES.get(name,'')) if kind=='ocr' else ''
        if alias and alias not in BUILTINS:raise ValueError('Unknown built-in ROI alias')
        threshold=float(data.get('threshold',.8))
        if not 0<=threshold<=1:raise ValueError('Threshold must be between 0 and 1')
        reference_name=data.get('reference_name') or None
        references={r['name']:r for r in self.named_references()}
        if kind=='image':
            if reference_name not in references:raise ValueError('Choose an exported asset or Save capture as reference')
            from PIL import Image
            with Image.open(self.root/references[reference_name]['path']) as image:digest=self.add_reference(image)
            reference_name='public/detection_references/'+digest+'.png' 
        enabled=bool(data.get('enabled',True))
        if min(int(data['reference_w']),int(data['reference_h']))<1:raise ValueError('Reference client dimensions must be positive')
        for existing in self.list():
            if existing['name'] in (name,old_name):continue
            if enabled and existing['enabled'] and alias and existing['builtin_alias']==alias:
                raise ValueError('Equivalent indicator already exists: '+existing['name']+'; edit it instead')
        with self.connect() as conn:
            if old_name!=name and conn.execute('SELECT 1 FROM indicator_regions WHERE name=?',(name,)).fetchone():
                raise ValueError('Region name already exists; select it to edit')
            if old_name and old_name!=name:conn.execute('DELETE FROM indicator_regions WHERE name=?',(old_name,))
            conn.execute('INSERT OR REPLACE INTO indicator_regions VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
                (name,kind,int(enabled),json.dumps(norm),int(data['reference_w']),int(data['reference_h']),
                 int(data.get('reference_dpi',96)),json.dumps(expected),reference_name,alias,threshold,time.time()))
        self.export()
        return name
    def delete(self,name):
        with self.connect() as conn:conn.execute('DELETE FROM indicator_regions WHERE name=?',(name,))
        self.export()
    def export(self):
        records=self.list();references={r['name']:r for r in self.named_references()}
        for row in records:
            ref=references.get(row.get('reference_name'))
            if ref:
                import hashlib
                ref['derived_sha']=hashlib.sha256((self.root/ref['path']).read_bytes()).hexdigest()
                row['reference']=ref
        self.config.parent.mkdir(exist_ok=True)
        temporary=self.config.with_name('.indicator_'+uuid.uuid4().hex+'.tmp')
        temporary.write_text(json.dumps({'version':1,'coordinate_space':'normalized Roblox client pixels',
            'regions':records},indent=2),encoding='utf-8');temporary.replace(self.config)


_cache={}
def configured_regions(path=CONFIG):
    path=Path(path)
    try:
        stamp=(path.stat().st_mtime_ns,path.stat().st_size)
        if _cache.get('stamp')!=stamp or _cache.get('path')!=str(path):
            _cache.update(stamp=stamp,path=str(path),regions=json.loads(path.read_text(encoding='utf-8')).get('regions',[]))
        return _cache['regions']
    except (OSError,ValueError):return []


def resolve_region(name,path=CONFIG):
    return next((r for r in configured_regions(path) if r['name']==name),None)


def effective_roi(name,defaults,path=CONFIG):
    for row in configured_regions(path):
        if row['enabled'] and row['kind']=='ocr' and (row['name']==name or row.get('builtin_alias')==name):
            x,y,w,h=row['normalized'];return x,y,x+w,y+h
    return defaults.get(name,defaults['full'])
