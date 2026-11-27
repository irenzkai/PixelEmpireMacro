"""Stable World Map window anchors; no map identity or gameplay candidates."""
from pathlib import Path
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def _white(image):
    hsv = cv2.cvtColor(image,cv2.COLOR_BGR2HSV)
    return cv2.inRange(hsv,np.array([0,0,150]),np.array([180,115,255]))


def _close_buttons(frame,gold,header):
    s = header['scale']
    boxes = []
    contours,_ = cv2.findContours(gold,cv2.RETR_LIST,cv2.CHAIN_APPROX_SIMPLE)
    for contour in contours:
        x,y,w,h = cv2.boundingRect(contour)
        if not (.6*header['h']<=w<=1.7*header['h'] and .7<=w/h<=1.3 and
                abs(y+h/2-header['y']-header['h']/2)<header['h']*.75 and
                x>header['x']+header['w']+30*s):
            continue
        white = cv2.resize(_white(frame[y:y+h,x:x+w]),(24,24),interpolation=cv2.INTER_NEAREST)>0
        diagonal = []
        for reverse in (False,True):
            mask = np.zeros((24,24),np.uint8)
            cv2.line(mask,(6,18) if reverse else (6,6),(18,6) if reverse else (18,18),255,3)
            diagonal.append(float(white[mask>0].mean()))
        if min(diagonal)<.32:
            continue
        box = dict(x=x,y=y,w=w,h=h,score=min(diagonal))
        if not any(abs(b['x']-x)<8*s for b in boxes):
            boxes.append(box)
    return boxes


def _zoom_anchor(frame,close,header):
    path = ROOT/'public/map_zoom_minus.png'
    template = cv2.imread(str(path),cv2.IMREAD_GRAYSCALE)
    if template is None:
        return None
    s = header['scale']
    x0,y0 = max(0,round(close['x']-65*s)),max(0,round(header['y']+header['h']))
    x1,y1 = min(frame.shape[1],round(close['x']+close['w'])),min(frame.shape[0],round(y0+150*s))
    gray = cv2.cvtColor(frame[y0:y1,x0:x1],cv2.COLOR_BGR2GRAY)
    best = None
    for factor in (.9,1.,1.1):
        t = cv2.resize(template,None,fx=s*factor,fy=s*factor)
        th,tw = t.shape
        if th>gray.shape[0] or tw>gray.shape[1]:
            continue
        _,score,_,(x,y) = cv2.minMaxLoc(cv2.matchTemplate(gray,t,cv2.TM_CCOEFF_NORMED))
        if best is None or score>best['score']:
            best = dict(x=x+x0,y=y+y0,w=tw,h=th,score=score)
    if best is None or best['score']<.70:
        return None
    # Plus is directly above minus. Confirm its two strokes independently.
    px,py = best['x'],round(best['y']-1.15*best['h'])
    if py>=0:
        patch = frame[py:py+best['h'],px:px+best['w']]
        inner = cv2.resize(_white(patch),(24,24),interpolation=cv2.INTER_NEAREST)>0
        horizontal = inner[10:14,6:19].any(axis=0).mean()
        vertical = inner[6:19,10:14].any(axis=1).mean()
        best['plus_confirmed'] = bool(min(horizontal,vertical)>=.35)
        best['plus_box'] = [px,py,best['w'],best['h']]
    return best


def _vertical(gold,xlo,xhi,top,s):
    xlo,xhi = max(0,round(xlo)),min(gold.shape[1],round(xhi))
    y0 = max(0,round(top-5*s))
    if xhi<=xlo:
        return []
    strip = gold[y0:,xlo:xhi]
    joined = cv2.morphologyEx(strip,cv2.MORPH_CLOSE,np.ones((max(3,round(7*s)),1),np.uint8))
    long = cv2.morphologyEx(joined,cv2.MORPH_OPEN,np.ones((max(20,round(75*s)),1),np.uint8))
    contours,_ = cv2.findContours(long,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    result = []
    for contour in contours:
        x,y,w,h = cv2.boundingRect(contour)
        if y<=35*s and h>=100*s:
            result.append(dict(x=x+xlo,w=w,y=y+y0,bottom=y+y0+h))
    return result


def locate_window(frame,gold,header):
    """Retain the intact-frame result; recover occluded bounds from observed edges."""
    h,w = frame.shape[:2]
    s = header['scale']
    diagnostic = dict(method='',reason='',anchors=[dict(kind='header',x=header['x'],y=header['y'],w=header['w'],h=header['h'])])
    closes = _close_buttons(frame,gold,header)
    anchors = []
    for close in closes:
        zoom = _zoom_anchor(frame,close,header)
        if zoom is not None:
            anchors.append((close,zoom))
    contours,_ = cv2.findContours(gold,cv2.RETR_LIST,cv2.CHAIN_APPROX_SIMPLE)
    rectangles = []
    for contour in contours:
        x,y,bw,bh = cv2.boundingRect(contour)
        if not (.30*w<=bw<=.95*w and .23*h<=bh<=.90*h and 1.1<=bw/bh<=3.5):
            continue
        if not (x<=header['x'] and header['x']+header['w']<=x+bw and y-5<=header['y']<=y+bh*.16):
            continue
        if cv2.contourArea(contour)/(bw*bh)<.72:
            continue
        # A tooltip rectangle must not replace the window: its right/title edge
        # must agree with the close/zoom column when that anchor is visible.
        if anchors and not any(abs(x+bw-close['x']-close['w'])<25*s for close,_ in anchors):
            continue
        rectangles.append((bw*bh,x,y,bw,bh))
    if anchors:
        close,zoom = max(anchors,key=lambda pair:pair[0]['score']+pair[1]['score'])
        diagnostic['anchors'] += [dict(kind='close',**close),dict(kind='zoom_minus',x=zoom['x'],y=zoom['y'],w=zoom['w'],h=zoom['h'])]
        if zoom.get('plus_confirmed'):
            x,y,bw,bh = zoom['plus_box']
            diagnostic['anchors'].append(dict(kind='zoom_plus',x=x,y=y,w=bw,h=bh))
    else:
        close=zoom=None
    if rectangles:
        _,x,y,bw,bh = max(rectangles)
        bounds = (max(0,x+round(12*s)),max(header['y']+header['h']+round(5*s),y+round(36*s)),min(w,x+bw-round(12*s)),min(h,y+bh-round(24*s)))
        diagnostic.update(method='intact header-anchored gold frame',reason='Window frame confirmed')
        return bounds,diagnostic
    if close is None:
        diagnostic['reason']='No intact window frame or corroborated close/zoom anchors'
        return None,diagnostic
    top = header['y']+header['h']+round(5*s)
    lefts = _vertical(gold,header['x']-60*s,header['x']-8*s,top,s)
    rights = _vertical(gold,zoom['x']+zoom['w']+2*s,close['x']+close['w']+16*s,top,s)
    if not lefts or not rights:
        diagnostic['reason']='Window anchors found; stable side-border segments missing'
        return None,diagnostic
    left = max(lefts,key=lambda b:b['x'])
    right = min(rights,key=lambda b:b['x'])
    x0,x1 = left['x']+left['w']+round(2*s),right['x']-round(2*s)
    if x1-x0<2.5*header['w'] or not (x0<zoom['x']<zoom['x']+zoom['w']<x1):
        diagnostic['reason']='Side borders disagree with header/zoom geometry'
        return None,diagnostic
    # Bottom may be interrupted by a tooltip. A long visible segment and the
    # end of either anchored side is sufficient; a closed contour is not needed.
    ylo = min(h-1,round(top+180*s))
    strip = gold[ylo:,max(0,x0-round(5*s)):min(w,x1+round(5*s))]
    line = cv2.morphologyEx(strip,cv2.MORPH_OPEN,np.ones((1,max(30,round((x1-x0)*.25))),np.uint8))
    votes = np.count_nonzero(line,axis=1)
    rows = [y+ylo for y,count in enumerate(votes) if count>.4*(x1-x0) and
            min(abs(y+ylo-left['bottom']),abs(y+ylo-right['bottom']))<30*s]
    if not rows:
        diagnostic['reason']='Window sides confirmed; bottom boundary actually obscured'
        return None,diagnostic
    bottom = min(rows,key=lambda y:min(abs(y-left['bottom']),abs(y-right['bottom'])))
    diagnostic.update(method='header + close/zoom + partial side/bottom borders',reason='Viewport recovered despite an interrupted frame')
    diagnostic['anchors'] += [dict(kind='left_border',x=left['x'],y=left['y'],w=left['w'],h=left['bottom']-left['y']),
                              dict(kind='right_border',x=right['x'],y=right['y'],w=right['w'],h=right['bottom']-right['y'])]
    return (max(0,x0),max(0,top),min(w,x1),min(h,bottom-round(24*s))),diagnostic


def tooltip_mask(query,ui_scale):
    """Flat dark overlay panels only; never infer an area's name from their text."""
    hsv=cv2.cvtColor(query,cv2.COLOR_BGR2HSV)
    dark=cv2.inRange(hsv,np.array([0,0,0]),np.array([180,200,90]))
    dark=cv2.morphologyEx(dark,cv2.MORPH_CLOSE,np.ones((9,9),np.uint8))
    contours,_=cv2.findContours(dark,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    mask=np.zeros(query.shape[:2],np.uint8)
    boxes=[]
    for contour in contours:
        x,y,w,h=cv2.boundingRect(contour)
        if w<60*ui_scale or h<65*ui_scale or cv2.contourArea(contour)/(w*h)<.80:
            continue
        patch=query[y:y+h,x:x+w]
        median=np.median(patch.reshape(-1,3),axis=0)
        flat=np.max(np.abs(patch.astype(np.float32)-median),axis=2)<12
        if flat.mean()<.45 or np.max(median)>95:
            continue
        pad=max(3,round(5*ui_scale))
        bx,by=max(0,x-pad),max(0,y-pad)
        br,bb=min(query.shape[1],x+w+pad),min(query.shape[0],y+h+pad)
        expanded=query[by:bb,bx:br]
        edges=cv2.Canny(cv2.cvtColor(expanded,cv2.COLOR_BGR2GRAY),50,120)
        # Require two perpendicular straight overlay edges, including clipped panels.
        horizontal=np.count_nonzero(cv2.morphologyEx(edges,cv2.MORPH_OPEN,np.ones((1,max(20,round(w*.5))),np.uint8)))
        vertical=np.count_nonzero(cv2.morphologyEx(edges,cv2.MORPH_OPEN,np.ones((max(25,round(h*.4)),1),np.uint8)))
        if horizontal<w*.4 or vertical<h*.3:
            continue
        mask[by:bb,bx:br]=255
        boxes.append(dict(x=bx,y=by,w=br-bx,h=bb-by))
    return mask,boxes
