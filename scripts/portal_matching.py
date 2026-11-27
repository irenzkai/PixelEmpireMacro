"""Local brightness-tolerant portal reference matching; no cache search or input."""
from pathlib import Path
import json
import cv2
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
_cache={}

def configuration():
    path=ROOT/'config/navigation_references.json'
    try:
        stamp=path.stat().st_mtime_ns
        if _cache.get('stamp')!=stamp:_cache.update(stamp=stamp,data=json.loads(path.read_text(encoding='utf-8')))
        return _cache['data']
    except (OSError,ValueError):return dict(references={},portals=[],connections=[])

def connection(source,destination):
    return next((e for e in configuration()['connections'] if e['source_ws']==source and e['destination_ws']==destination),None)

def match_portal(frame,source,destination):
    cfg=configuration();edge=connection(source,destination)
    portal=next((p for p in cfg['portals'] if p['source_ws']==source and p['destination_ws']==destination and (not edge or p['number']==edge['portal_number'])),None)
    if not portal or not portal.get('arch_id'):return dict(ok=1,configured=bool(edge),found=0,reason='Assigned portal arch is pending')
    gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY);clahe=cv2.createCLAHE(clipLimit=2.,tileGridSize=(8,8))
    normalized=clahe.apply(gray);edges=cv2.Canny(normalized,60,140);best=None
    for role in ('arch_id','night_arch_id'):
        ref=cfg['references'].get(portal.get(role))
        if not ref:continue
        path=(ROOT/ref['path']).resolve()
        if not path.is_relative_to(ROOT):continue
        rgba=cv2.imread(str(path),cv2.IMREAD_UNCHANGED)
        if rgba is None:continue
        template=cv2.cvtColor(rgba,cv2.COLOR_BGRA2GRAY if rgba.ndim==3 and rgba.shape[2]==4 else cv2.COLOR_BGR2GRAY) if rgba.ndim==3 else rgba
        for scale in (.5,.65,.8,1.,1.2,1.5):
            t=cv2.resize(template,None,fx=scale,fy=scale);h,w=t.shape
            if min(h,w)<8 or h>gray.shape[0] or w>gray.shape[1]:continue
            t=clahe.apply(t);te=cv2.Canny(t,60,140)
            if cv2.countNonZero(te)<12:continue
            edge_scores=cv2.matchTemplate(edges,te,cv2.TM_CCOEFF_NORMED)
            gray_scores=cv2.matchTemplate(normalized,t,cv2.TM_CCOEFF_NORMED)
            scores=np.nan_to_num(.7*edge_scores+.3*gray_scores,nan=-1,posinf=-1,neginf=-1)
            _,score,_,(x,y)=cv2.minMaxLoc(scores)
            if best is None or score>best['score']:best=dict(score=round(score,4),x=x+w//2,y=y+int(h*.82),box=[x,y,w,h],reference=ref['name'],variant=role)
    if best is None:return dict(ok=1,configured=1,found=0,reason='No usable arch template; refine the crop')
    return dict(ok=1,configured=1,found=int(best['score']>=portal['threshold']),threshold=portal['threshold'],method='CLAHE + normalized edge/luminance correlation',source_ws=source,destination_ws=destination,portal_number=portal['number'],**best)
