"""Image-only navigation helpers, shared by live OCR endpoints and replay checks."""
from pathlib import Path
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent
MAP_ASSET_CACHE = {}

def registered_map_vector(frame, map_idx=-1, target_kind='waystone', quadrant='', ocr=None):
    # A configured route target is not evidence of the current map.
    from scripts.world_map_detection import detect_world_map
    return detect_world_map(frame,map_idx,target_kind,quadrant,ocr)


def boss_minimap_target(frame):
    h,w = frame.shape[:2]
    x0,y0 = int(w*.875), int(h*.025)
    roi = frame[y0:int(h*.235),x0:int(w*.99)]
    hsv=cv2.cvtColor(roi,cv2.COLOR_BGR2HSV)
    red=cv2.inRange(hsv,np.array([0,150,140]),np.array([8,255,255]))
    contours,_=cv2.findContours(red,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    dots=[]
    for c in contours:
        area=cv2.contourArea(c)
        x,y,bw,bh=cv2.boundingRect(c)
        if 70<area<500 and .7<bw/bh<1.3:
            dots.append((x+bw//2,y+bh//2))
    yellow=cv2.inRange(hsv,np.array([20,130,150]),np.array([38,255,255]))
    cs,_=cv2.findContours(yellow,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    arrows=[]
    for c in cs:
        area=cv2.contourArea(c)
        if 35<area<250:
            x,y,bw,bh=cv2.boundingRect(c)
            arrows.append((x+bw//2,y+bh//2))
    if len(dots)!=1 or len(arrows)!=1:
        return {'target_reliable':0,'reason':'Unique boss dot and player arrow not available'}
    return {'target_reliable':1,'dx':dots[0][0]-arrows[0][0], 'dy':dots[0][1]-arrows[0][1],
            'reason':'Unique red boss dot and yellow player arrow on current minimap'}

def portal_candidates(frame):
    """Match complete static arch geometry rather than arbitrary green sprites."""
    h, w = frame.shape[:2]
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    best = None
    from scripts.indicator_regions import resolve_region
    region=resolve_region('portal')
    selected=region.get('reference') if region and region.get('enabled') else None
    paths=[ROOT/selected['path']] if selected else list((ROOT/'public/maps').glob('portals_*/*.png'))
    for path in paths:
        source = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if source is None:
            continue
        # Use outer arch: the centre swirls and changes with animation.
        for scale in (.7, .8, .9, 1.0, 1.1):
            template = cv2.resize(source, None, fx=scale, fy=scale)
            th, tw = template.shape
            if th >= h or tw >= w:
                continue
            mask = np.full(template.shape, 255, np.uint8)
            mask[int(th*.25):int(th*.82), int(tw*.30):int(tw*.70)] = 0
            scores = cv2.matchTemplate(gray, template, cv2.TM_CCORR_NORMED, mask=mask)
            scores[~np.isfinite(scores)] = 0
            # UI and nameplate/health/skills regions cannot contain a live portal.
            scores[:int(h*.18), :] = 0
            scores[int(h*.82):, :] = 0
            scores[:, int(w*.80):] = 0
            scores[:, :int(w*.04)] = 0
            _, score, _, xy = cv2.minMaxLoc(scores)
            # CCORR can be high on flat textures; require edge agreement too.
            x, y = xy
            patch = gray[y:y+th, x:x+tw]
            edge_score = float(cv2.matchTemplate(cv2.Canny(patch, 60, 130), cv2.Canny(template, 60, 130), cv2.TM_CCOEFF_NORMED)[0,0])
            confidence = min(score, max(0., edge_score))
            if best is None or confidence > best['confidence']:
                best = {'confidence': round(confidence, 3), 'x': x+tw//2, 'y': y+int(th*.78),
                        'box': [x,y,tw,th], 'reference': str(path.relative_to(ROOT))}
    if best is None or best['confidence'] < .35:
        return {'ok':1, 'found':0, 'reason':'No complete portal arch matched'}
    return {'ok':1, 'found':1, **best, 'method':'full_arch_edges', 'candidate_only':1}

def player_anchor(frame):
    """Gold VIP nameplate; return unknown if multiple plausible plates exist."""
    template = cv2.imread(str(ROOT / 'public/player_nameplate.png'), cv2.IMREAD_GRAYSCALE)
    if template is not None:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        scores = cv2.matchTemplate(gray, template, cv2.TM_CCOEFF_NORMED)
        h,w = frame.shape[:2]
        scores[:int(h*.25)] = 0
        scores[int(h*.75):] = 0
        scores[:,:int(w*.20)] = 0
        scores[:,int(w*.78):] = 0
        _, score, _, (x,y) = cv2.minMaxLoc(scores)
        if score >= .70:
            return {'player_found':1,'player_x':x+template.shape[1]//2,
                    'player_y':y+template.shape[0]+72, 'player_confidence':round(score,3)}
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, np.array([5,100,80]), np.array([25,255,255]))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3,9),np.uint8))
    contours, _ = cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    h,w = frame.shape[:2]
    boxes=[]
    for contour in contours:
        x,y,bw,bh=cv2.boundingRect(contour)
        if 85<=bw<=180 and 12<=bh<=28 and .20*w<x<.78*w and .25*h<y<.75*h:
            boxes.append((x,y,bw,bh))
    if len(boxes)!=1:
        return {'player_found':0}
    x,y,bw,bh=boxes[0]
    return {'player_found':1,'player_x':x+bw//2,'player_y':y+bh+65}
