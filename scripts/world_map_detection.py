"""Arrow-first World Map perception. No capture, key input, or guessed map names."""
from difflib import SequenceMatcher
from functools import lru_cache
from pathlib import Path
import json
import math
import re
import time
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def configuration():
    return json.loads((ROOT/'config/world_map_detector.json').read_text(encoding='utf-8'))


@lru_cache(maxsize=2)
def catalog(stamp):
    text = (ROOT/'src/MapRoutes.ahk').read_text(encoding='utf-8-sig')
    pattern = r'(\d+),\s*\{\s*label:\s*"([^"]+)"\s*,\s*file:\s*"([^"]+)"\s*,\s*gx:\s*(-?\d+),\s*gy:\s*(-?\d+)'
    return [dict(ws=int(ws),name=re.sub(r'^WS #\d+:\s*','',name),file=file,gx=int(gx),gy=int(gy))
            for ws,name,file,gx,gy in re.findall(pattern,text)]


def clean(text):
    text = re.split(r'(?:lv|level)\.?\s*\d',text,flags=re.I)[0]
    return re.sub('[^a-z0-9]','',text.lower())


def label_identity(text, records):
    label = clean(text)
    scores = []
    for record in records:
        name = clean(record['name'])
        similarity = SequenceMatcher(None,label,name).ratio()
        if len(name)>=6 and name in label:
            similarity = max(similarity,.97)
        scores.append((similarity,record['ws']))
    scores.sort(reverse=True)
    if label and len(scores)>1 and scores[0][0]>=.82 and scores[0][0]-scores[1][0]>=.08:
        return scores[0][1]
    return None


def viewport(frame, cfg):
    from scripts.legacy_references import configured_image
    h,w = frame.shape[:2]
    header = cv2.imread(str(configured_image('WorldMap','OpenImg','public/map_open.png')),cv2.IMREAD_GRAYSCALE)
    if header is None:
        return None,None,'Map header reference unavailable'
    region = frame
    gray = cv2.cvtColor(region,cv2.COLOR_BGR2GRAY)
    best = None
    # Preserve the working header's first 145 pixels and its acceptance threshold.
    for scale in cfg['header_scales']:
        template = cv2.resize(header[:,:145],None,fx=scale,fy=scale)
        th,tw = template.shape
        if th>gray.shape[0] or tw>gray.shape[1] or template.std()<2:
            continue
        _,score,_,(x,y) = cv2.minMaxLoc(cv2.matchTemplate(gray,template,cv2.TM_CCOEFF_NORMED))
        if best is None or score>best['score']:
            best = dict(x=x,y=y,w=tw,h=th,scale=scale,score=score)
    if best is None or best['score']<cfg['header_threshold']:
        return None,best,'World Map header not confirmed'
    hsv = cv2.cvtColor(frame,cv2.COLOR_BGR2HSV)
    gold = cv2.inRange(hsv,np.array([10,45,65]),np.array([45,255,255]))
    gold = cv2.morphologyEx(gold,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    from scripts.world_map_window import locate_window
    bounds,diagnostic = locate_window(frame,gold,best)
    best['window_diagnostics'] = diagnostic
    return bounds,best,diagnostic['reason'] if bounds is None else ''


@lru_cache(maxsize=64)
def area_features(path,stamp):
    image = cv2.imread(path,cv2.IMREAD_GRAYSCALE)
    if image is None:
        return None,None,None
    orb = cv2.ORB_create(nfeatures=900,edgeThreshold=8,fastThreshold=10)
    points,descriptors = orb.detectAndCompute(image,None)
    return image,np.float32([p.pt for p in points]),descriptors


def registered_areas(query,arrow,records,cfg,occluded=None,geometry_key=None,diagnostic=None,cache_context=None):
    gray = cv2.cvtColor(query,cv2.COLOR_BGR2GRAY)
    from scripts.world_map_cache import GEOMETRY
    files = [ROOT/'src/MapRoutes.ahk', ROOT/'config/world_map_detector.json',
             *[ROOT/'public/maps/map_area'/r['file'] for r in records]]
    signature = (geometry_key, tuple((str(p),p.stat().st_mtime_ns,p.stat().st_size) for p in files if p.is_file()))
    validation_started = time.perf_counter()
    cached, cache_reason = GEOMETRY.get(gray,arrow,occluded,signature)
    if diagnostic is not None:
        diagnostic['registration_cache'] = cache_reason
        diagnostic['cache_validation_ms'] = round((time.perf_counter()-validation_started)*1000,2)
    if cache_context is not None:
        cache_context.update(gray=gray,signature=signature,hit=cached is not None)
    if cached is not None:
        return cached
    orb = cv2.ORB_create(nfeatures=2800,edgeThreshold=8,fastThreshold=10)
    feature_mask = None if occluded is None or not occluded.any() else cv2.bitwise_not(cv2.dilate(occluded,np.ones((9,9),np.uint8)))
    query_points,query_descriptors = orb.detectAndCompute(gray,feature_mask)
    if query_descriptors is None:
        return []
    locations = np.float32([p.pt for p in query_points])
    matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
    output = []
    for record in records:
        path = ROOT/'public/maps/map_area'/record['file']
        if not path.is_file():
            continue
        asset,points,descriptors = area_features(str(path),path.stat().st_mtime_ns)
        if descriptors is None:
            continue
        pairs = matcher.knnMatch(descriptors,query_descriptors,k=2)
        good = [a for pair in pairs if len(pair)==2 for a,b in [pair] if a.distance<.72*b.distance]
        if len(good)<cfg['registration_min_inliers']:
            continue
        source = np.float32([points[m.queryIdx] for m in good])
        destination = np.float32([locations[m.trainIdx] for m in good])
        matrix,inliers = cv2.estimateAffinePartial2D(source,destination,method=cv2.RANSAC,ransacReprojThreshold=3.,maxIters=1500)
        if matrix is None or inliers is None:
            continue
        keep = inliers.ravel().astype(bool)
        count,ratio = int(keep.sum()),float(keep.mean())
        scale = float(np.hypot(matrix[0,0],matrix[1,0]))
        rotation = abs(math.degrees(math.atan2(matrix[1,0],matrix[0,0])))
        ah,aw = asset.shape
        spread = np.ptp(source[keep],axis=0) if count else [0,0]
        if count<cfg['registration_min_inliers'] or ratio<cfg['registration_min_ratio'] or not .25<=scale<=3. or rotation>4 or spread[0]<.22*aw or spread[1]<.22*ah:
            continue
        quad = cv2.transform(np.float32([[[0,0],[aw,0],[aw,ah],[0,ah]]]),matrix)[0]
        contains = cv2.pointPolygonTest(quad,(arrow['ax'],arrow['ay']),False)>=0
        score = .6*ratio+.4*min(1.,count/35)
        output.append(dict(**record,quad=quad,matrix=matrix,contains=contains,score=score,inliers=count,ratio=ratio,scale=scale,size=[aw,ah]))
    return output


def layout_support(area,others):
    center = area['quad'].mean(axis=0)
    for other in others:
        dx,dy = other['gx']-area['gx'],other['gy']-area['gy']
        if not (abs(dx)+abs(dy)==1 and other['score']>=.6):
            continue
        observed = other['quad'].mean(axis=0)-center
        span = np.array(area['size'])*area['scale']
        expected = np.array([dx,dy])*span
        if np.linalg.norm(observed-expected)<.35*max(span):
            return True
    return False


def _confirm_identity_uncached(area,others,query,records,ocr,occluded=None):
    text = ''
    if ocr is not None:
        aw,ah = area['size']
        label = cv2.transform(np.float32([[[aw*.04,ah*.02],[aw*.97,ah*.16]]]),area['matrix'])[0]
        x0,y0 = np.floor(label.min(axis=0)).astype(int)
        x1,y1 = np.ceil(label.max(axis=0)).astype(int)
        x0,x1 = np.clip([x0,x1],0,query.shape[1])
        y0,y1 = np.clip([y0,y1],0,query.shape[0])
        crop = query[y0:y1,x0:x1] if x1>x0 and y1>y0 else np.empty((0,0,3),np.uint8)
        obscured = occluded is not None and x1>x0 and y1>y0 and np.any(occluded[y0:y1,x0:x1])
        if crop.size and not obscured:
            text = ' '.join(item['text'] for item in ocr(crop))
            identified = label_identity(text,records)
            if identified is not None:
                return identified==area['ws'],text,'registered area + its map label' if identified==area['ws'] else 'Map label conflicts with containing-area registration'
    if layout_support(area,others):
        return True,text,'registered containing area + authoritative neighboring layout'
    # Dense, spatially spread feature registration is itself record evidence;
    # weak single-landmark guesses never reach this branch.
    strong = area['inliers']>=30 and area['ratio']>=.70
    return strong,text,'dense containing-area registration' if strong else 'Map identity is ambiguous; label/layout confirmation unavailable'


def confirm_identity(area,others,query,records,ocr,occluded=None):
    from scripts.world_map_cache import GEOMETRY
    aw,ah = area['size']
    label = cv2.transform(np.float32([[[aw*.04,ah*.02],[aw*.97,ah*.16]]]),area['matrix'])[0]
    x0,y0 = np.floor(label.min(axis=0)).astype(int)
    x1,y1 = np.ceil(label.max(axis=0)).astype(int)
    x0,x1 = np.clip([x0,x1],0,query.shape[1])
    y0,y1 = np.clip([y0,y1],0,query.shape[0])
    crop = query[y0:y1,x0:x1] if x1>x0 and y1>y0 else np.empty((0,0,3),np.uint8)
    obscured = occluded is not None and x1>x0 and y1>y0 and np.any(occluded[y0:y1,x0:x1])
    cached = GEOMETRY.identity(area,crop,obscured)
    if cached is not None:
        return cached
    result = _confirm_identity_uncached(area,others,query,records,ocr,occluded)
    if result[0]:
        GEOMETRY.identity(area,crop,obscured,result)
    return result


@lru_cache(maxsize=40)
def icon_body(path,stamp,box):
    image = cv2.imread(path,cv2.IMREAD_UNCHANGED)
    if image is None:
        return None
    if image.ndim==2:
        image = cv2.cvtColor(image,cv2.COLOR_GRAY2BGRA)
    elif image.shape[2]==3:
        image = cv2.cvtColor(image,cv2.COLOR_BGR2BGRA)
    h,w = image.shape[:2]
    x,y,bw,bh = box
    return image[round(y*h):round((y+bh)*h),round(x*w):round((x+bw)*w)].copy()


def waystone_icon(query,area,cfg,occluded=None,track_hint=None):
    from scripts.waystone_body_matching import body_features,prepared,evidence,physical_objects
    from scripts.world_map_icon import aligned_icon,color_model,verify_colors
    from scripts.legacy_references import configured_image
    folder = (ROOT/cfg['waystone_live_dir']).resolve()
    paths = sorted(p for p in folder.glob('*.png') if not p.is_symlink()) if folder.is_relative_to(ROOT/'public') else []
    supplemental=bool(paths)
    if not paths:paths=[configured_image('WorldMap','WaystoneImg','public/map_waystone.png')]
    # Work only within the selected area's visible bounding rectangle. All
    # returned local positions remain relative to the original viewport query.
    ax0=max(0,int(np.floor(area['quad'][:,0].min())))
    ay0=max(0,int(np.floor(area['quad'][:,1].min())))
    ax1=min(query.shape[1],int(np.ceil(area['quad'][:,0].max())))
    ay1=min(query.shape[0],int(np.ceil(area['quad'][:,1].max())))
    if track_hint is not None:
        # Track only a previously confirmed icon under validated geometry. A
        # missing/ambiguous local match will broaden to the full approved area.
        pad=max(12,round(max(track_hint['w'],track_hint['h'])*.6))
        ax0=max(ax0,track_hint['x']-pad);ay0=max(ay0,track_hint['y']-pad)
        ax1=min(ax1,track_hint['x']+track_hint['w']+pad);ay1=min(ay1,track_hint['y']+track_hint['h']+pad)
    crop=query[ay0:ay1,ax0:ax1]
    diagnostic=dict(candidates=[],reference_count=len(paths),threshold=cfg['waystone_threshold'],required_margin=cfg['waystone_margin'])
    if not crop.size:return None,'Selected map area is clipped outside viewport',diagnostic
    gray,edge=body_features(crop)
    allowed=np.zeros(crop.shape[:2],np.uint8)
    cv2.fillConvexPoly(allowed,np.rint(area['quad']-np.float32([ax0,ay0])).astype(np.int32),255)
    if occluded is not None:allowed[occluded[ay0:ay1,ax0:ax1]>0]=0
    candidates=[]
    # The registered area scale accounts for map zoom and client scaling.
    hint=max(.25,float(track_hint['scale'] if track_hint is not None else area['scale']))
    scales=sorted(cfg['waystone_scales'],key=lambda v:abs(np.log(v/hint)))
    if track_hint is not None:
        scales=scales[:3]
    for path in paths:
        if not path.is_file():continue
        body=aligned_icon(str(path),path.stat().st_mtime_ns) if supplemental else icon_body(str(path),path.stat().st_mtime_ns,(0,0,1,1))
        if body is None:continue
        for scale in scales:
            w,h=round(body.shape[1]*scale),round(body.shape[0]*scale)
            if w<4 or h<10 or w>crop.shape[1] or h>crop.shape[0]:continue
            template=prepared(body.tobytes(),*body.shape[:2],w,h)
            if template is None:continue
            tg,te,mask=template
            model=color_model(body.tobytes(),*body.shape[:2],w,h) if supplemental else None
            lum=cv2.matchTemplate(gray,tg,cv2.TM_CCOEFF_NORMED)
            shape=cv2.matchTemplate(edge,te,cv2.TM_CCORR_NORMED)
            scores=np.nan_to_num(.7*shape+.3*lum,nan=-1.,posinf=-1.,neginf=-1.)
            inside=cv2.erode(allowed,np.ones((h,w),np.uint8),borderType=cv2.BORDER_CONSTANT,borderValue=0)
            scores[inside[h//2:h//2+scores.shape[0],w//2:w//2+scores.shape[1]]==0]=-1
            for _ in range(8):
                _,peak,_,(x,y)=cv2.minMaxLoc(scores)
                if peak<.3:break
                scores[max(0,y-h//2):y+h//2+1,max(0,x-w//2):x+w//2+1]=-1
                value,shape_score,luminance=evidence(gray[y:y+h,x:x+w],edge[y:y+h,x:x+w],tg,te,mask)
                reasons=[]
                if shape_score<.55 or luminance<.35:reasons.append('weak shape/luminance')
                color,dark,cyan=verify_colors(crop[y:y+h,x:x+w],model) if model else (value,1.,1.)
                if model:
                    if dark<.65:reasons.append('missing dark body/base pattern')
                    if cyan<.60:reasons.append('missing diamond/rune pattern')
                    value=.40*shape_score+.25*luminance+.35*color
                row=dict(score=float(value),x=x+ax0,y=y+ay0,w=w,h=h,reference=path.name,
                         shape_score=float(shape_score),luminance_score=float(luminance),color_score=color,
                         dark_support=dark,cyan_support=cyan,scale=scale,evidence_passed=not reasons,
                         reason=', '.join(reasons) if reasons else 'full icon evidence passed')
                diagnostic['candidates'].append(row)
                if not reasons:candidates.append(row)
    groups=physical_objects(candidates)
    diagnostic['physical_object_count']=len(groups)
    diagnostic['candidates']=sorted(diagnostic['candidates'],key=lambda r:r['score'],reverse=True)[:16]
    if not groups:
        best_rejected=diagnostic['candidates'][0] if diagnostic['candidates'] else None
        diagnostic['best_candidate']=best_rejected
        detail=': '+best_rejected['reason'] if best_rejected else ': no usable candidate'
        return None,'No full waystone icon passed verification'+detail,diagnostic
    best=groups[0][0]
    runner=groups[1][0]['score'] if len(groups)>1 else 0.
    margin=best['score']-runner
    diagnostic.update(best_score=best['score'],runner_score=runner,margin=margin,
                      best_candidate=best,competing_candidate=groups[1][0] if len(groups)>1 else None)
    if best['score']<cfg['waystone_threshold']:
        return None,f"Waystone best {best['score']:.3f} below {cfg['waystone_threshold']:.3f}",diagnostic
    if margin<cfg['waystone_margin']:
        return None,f"Waystone objects ambiguous: {best['score']:.3f}/{runner:.3f}, margin {margin:.3f} < {cfg['waystone_margin']:.3f}",diagnostic
    return dict(best,margin=margin,live_reference_count=len(paths) if supplemental else 0),'',diagnostic


def detect_world_map(frame,requested_ws=-1,target_kind='waystone',quadrant='',ocr=None):
    cfg = configuration()
    result = dict(ok=0,open=0,viewport_found=0,arrow_found=0,way_found=0,area_found=0,
                  map_ws=-1,map_name='UNKNOWN',requested_ws=requested_ws,
                  coordinate_space='Roblox client pixels',anchor_description='arrow centroid to matched waystone icon center',
                  reason='',method='arrow-first viewport + registered containing map',
                  viewport_ms=0,registration_ms=0,identity_ms=0,matching_ms=0,registration_cache='not reached')
    phase_started = time.perf_counter()
    bounds,header,reason = viewport(frame,cfg)
    result['viewport_ms'] = round((time.perf_counter()-phase_started)*1000,2)
    result['window_diagnostics'] = header.get('window_diagnostics',{}) if header else {}
    if header and header['score']>=cfg['header_threshold']:
        result['open'] = 1
    if bounds is None:
        return dict(result,reason=reason)
    result.update(header_x=header['x'],header_y=header['y'],header_scale=header['scale'])
    x0,y0,x1,y1 = bounds
    query = frame[y0:y1,x0:x1]
    result.update(viewport_found=1,viewport_x=x0,viewport_y=y0,viewport_w=x1-x0,viewport_h=y1-y0)
    from scripts.world_map_window import tooltip_mask
    from scripts.world_map_arrow import find_arrows,arrow_models
    occluded,overlays = tooltip_mask(query,header['scale'])
    result['occluders'] = [dict(box,x=box['x']+x0,y=box['y']+y0) for box in overlays]
    result['arrow_reference_count'] = len(arrow_models())
    phase_started = time.perf_counter()
    arrows,diagnostics = find_arrows(query,header['scale'],occluded)
    result['matching_ms'] += round((time.perf_counter()-phase_started)*1000,2)
    result['arrow_candidates'] = [dict(row,x=row['x']+x0,y=row['y']+y0) for row in diagnostics]
    result['arrow_diagnostics'] = f"{result['arrow_reference_count']} rendered refs; {len(arrows)} distinct arrow shapes; {sum(not d['accepted'] for d in diagnostics)} rejected components"
    if not arrows:
        from collections import Counter
        reasons = Counter(d['reason'] for d in diagnostics)
        summary = '; '.join(f'{reason}: {count}' for reason,count in reasons.most_common(3))
        return dict(result,reason='No player arrow passed color/shape checks: '+(summary or 'no red components; possibly obscured'))
    if len(arrows)>1 and arrows[0]['score']-arrows[1]['score']<.12:
        return dict(result,reason=f"Distinct arrow shapes ambiguous: scores {arrows[0]['score']:.3f}/{arrows[1]['score']:.3f}; see candidate boxes")
    arrow = arrows[0]
    result.update(arrow_found=1,acx=round(arrow['ax']+x0),acy=round(arrow['ay']+y0),
                  arrow_x=arrow['x']+x0,arrow_y=arrow['y']+y0,arrow_w=arrow['w'],arrow_h=arrow['h'])
    records = catalog((ROOT/'src/MapRoutes.ahk').stat().st_mtime_ns)
    phase_started = time.perf_counter()
    cache_context = {}
    areas = registered_areas(query,arrow,records,cfg,occluded,
        geometry_key=(tuple(frame.shape),tuple(bounds),round(header['scale'],4)),diagnostic=result,cache_context=cache_context)
    result['registration_ms'] = round((time.perf_counter()-phase_started)*1000,2)
    containing = sorted((a for a in areas if a['contains']),key=lambda a:a['score'],reverse=True)
    supported = []
    area_diagnostics = []
    for candidate in containing:
        phase_started = time.perf_counter()
        confirmed,text,identity = confirm_identity(candidate,areas,query,records,ocr,occluded)
        result['identity_ms'] += round((time.perf_counter()-phase_started)*1000,2)
        # Resolve overlapping registrations using independently local label/layout
        # evidence before comparing quality. Never use a neighboring tooltip title.
        rank = candidate['score'] + (.10 if 'map label' in identity and confirmed else 0.) + (.08 if layout_support(candidate,areas) else 0.)
        area_diagnostics.append(dict(ws=candidate['ws'],name=candidate['name'],score=round(candidate['score'],3),rank=round(rank,3),confirmed=confirmed,reason=identity,polygon=(candidate['quad']+np.float32([x0,y0])).tolist()))
        if confirmed:
            supported.append((rank,candidate,text,identity))
    result['area_candidates'] = area_diagnostics
    supported.sort(key=lambda row:row[0],reverse=True)
    if not supported:
        return dict(result,reason='No arrow-containing area confirmed by local registration/label/layout')
    if len(supported)>1 and supported[0][0]-supported[1][0]<cfg['area_margin']:
        return dict(result,reason='Overlapping arrow-containing registrations remain ambiguous after local label/layout checks')
    _,area,text,identity = supported[0]
    quad = area['quad']+np.float32([x0,y0])
    result.update(area_found=1,map_ws=area['ws'],map_name=area['name'],map_label_text=text,identity_evidence=identity,
                  area_confidence=round(area['score'],3),map_scale=round(area['scale'],4),
                  area_polygon=quad.tolist(),area_x1=round(quad[:,0].min()),area_y1=round(quad[:,1].min()),
                  area_x2=round(quad[:,0].max()),area_y2=round(quad[:,1].max()))
    from scripts.world_map_cache import GEOMETRY
    result['cache_prepare_ms'] = 0.
    if not cache_context['hit']:
        phase_started = time.perf_counter()
        # Commit only after the current map passes the unchanged identity gates.
        GEOMETRY.put(cache_context['gray'],arrow,occluded,cache_context['signature'],areas)
        result['cache_prepare_ms'] = round((time.perf_counter()-phase_started)*1000,2)
    phase_started = time.perf_counter()
    hint = GEOMETRY.icon(area) if cache_context['hit'] else None
    icon = None
    if hint is not None:
        icon,reason,icon_diagnostic = waystone_icon(query,area,cfg,occluded,track_hint=hint)
        result['icon_search'] = 'local verified' if icon is not None else 'local missed/ambiguous; broad reacquire'
    if icon is None:
        icon,reason,icon_diagnostic = waystone_icon(query,area,cfg,occluded)
        result.setdefault('icon_search','full selected-area search')
    if icon is not None:
        GEOMETRY.icon(area,icon)
    result['matching_ms'] += round((time.perf_counter()-phase_started)*1000,2)
    icon_diagnostic['candidates']=[dict(row,x=row['x']+x0,y=row['y']+y0) for row in icon_diagnostic.get('candidates',[])]
    for key in ('best_candidate','competing_candidate'):
        candidate=icon_diagnostic.get(key)
        if candidate is not None:
            icon_diagnostic[key]=dict(candidate,x=candidate['x']+x0,y=candidate['y']+y0)
    result['waystone_diagnostics']=icon_diagnostic
    if icon is None:
        return dict(result,reason=reason)
    result.update(way_found=1,way_x=icon['x']+x0,way_y=icon['y']+y0,way_w=icon['w'],way_h=icon['h'],
                  wcx=round(icon['x']+icon['w']/2+x0),wcy=round(icon['y']+icon['h']/2+y0),
                  waystone_score=round(icon['score'],3),waystone_reference=icon['reference'],
                  waystone_live_reference_count=icon['live_reference_count'])
    if target_kind=='subarea':
        from scripts.portal_matching import configuration as manual_configuration
        manual = manual_configuration()
        quadrant = {'NW':'TL','NE':'TR','SW':'BL','SE':'BR'}.get(quadrant,quadrant)
        subareas = [r for r in manual.get('subareas',[]) if r['ws']==area['ws'] and r['quadrant']==quadrant]
        if (requested_ws>=0 and requested_ws!=area['ws']) or len(subareas)!=1:
            return dict(result,reason='Subarea target must belong to the confirmed current map')
        ref = manual['references'].get(subareas[0]['reference_id'])
        image = cv2.imread(str(ROOT/ref['path']),cv2.IMREAD_GRAYSCALE) if ref else None
        if image is None:
            return dict(result,reason='Confirmed subarea image unavailable')
        best = None
        for scale in (.5,.65,.8,1.,1.2):
            template = cv2.resize(image,None,fx=scale,fy=scale)
            th,tw = template.shape
            if min(th,tw)<8 or th>query.shape[0] or tw>query.shape[1] or template.std()<3:
                continue
            _,score,_,(x,y) = cv2.minMaxLoc(cv2.matchTemplate(cv2.cvtColor(query,cv2.COLOR_BGR2GRAY),template,cv2.TM_CCOEFF_NORMED))
            if cv2.pointPolygonTest(area['quad'],(x+tw/2,y+th/2),False)>=0 and (best is None or score>best[0]):
                best = (score,x+tw/2,y+th/2)
        if best is None or best[0]<.75:
            return dict(result,reason='Subarea image not confidently matched within current area')
        result.update(wcx=round(best[1]+x0),wcy=round(best[2]+y0))
    result.update(ok=1,dx=result['wcx']-result['acx'],dy=result['wcy']-result['acy'],target_kind=target_kind,
                  reason='Current map confirmed from arrow containment; vector is not arrival confirmation')
    return result


def save_preview(frame,result,path):
    canvas = frame.copy()
    for anchor in result.get('window_diagnostics',{}).get('anchors',[]):
        x,y,w,h = (anchor[k] for k in ('x','y','w','h'))
        cv2.rectangle(canvas,(x,y),(x+w,y+h),(140,170,180),1)
    for box in result.get('occluders',[]):
        x,y,w,h = (box[k] for k in ('x','y','w','h'))
        cv2.rectangle(canvas,(x,y),(x+w,y+h),(220,70,220),1)
    for candidate in result.get('area_candidates',[]):
        cv2.polylines(canvas,[np.int32(candidate['polygon'])],True,(100,130,100),1)
    # Keep candidate text inside the viewport; detailed reasons stay in JSON.
    candidates = sorted(result.get('arrow_candidates',[]),key=lambda c:(c['accepted'],c.get('shape_iou',0)),reverse=True)
    seen=set(); passed=0; rejected=0
    for candidate in candidates:
        x,y,w,h = (candidate[k] for k in ('x','y','w','h'))
        key=(x,y,w,h)
        if key in seen:
            continue
        seen.add(key)
        if candidate['accepted']:
            passed+=1
            if passed>6:continue
            label=f"C{passed} s{candidate.get('score',0):.3f}"
        else:
            rejected+=1
            if rejected>3:continue
            label=f"R{rejected}"
        color = (40,200,240) if candidate['accepted'] else (20,130,230)
        cv2.rectangle(canvas,(x,y),(x+w,y+h),color,1)
        width=cv2.getTextSize(label,cv2.FONT_HERSHEY_SIMPLEX,.35,1)[0][0]
        left=result.get('viewport_x',0); top=result.get('viewport_y',0)
        right=left+result.get('viewport_w',canvas.shape[1])
        cv2.putText(canvas,label,(max(left,min(x,right-width-2)),max(top+12,y-3)),cv2.FONT_HERSHEY_SIMPLEX,.35,color,1)
    if result.get('viewport_found'):
        x,y,w,h = (result[k] for k in ('viewport_x','viewport_y','viewport_w','viewport_h'))
        cv2.rectangle(canvas,(x,y),(x+w,y+h),(220,170,40),2)
    icon_diagnostic=result.get('waystone_diagnostics',{})
    for index,key in enumerate(('best_candidate','competing_candidate')):
        candidate=icon_diagnostic.get(key)
        if candidate is not None:
            x,y,w,h=(candidate[k] for k in ('x','y','w','h'))
            cv2.rectangle(canvas,(x,y),(x+w,y+h),(190,120,240),1)
            cv2.putText(canvas,f"W{index+1} {candidate['score']:.3f}",(x,max(12,y-3)),cv2.FONT_HERSHEY_SIMPLEX,.35,(190,120,240),1)
    if result.get('area_found'):
        cv2.polylines(canvas,[np.int32(result['area_polygon'])],True,(80,220,80),2)
    for prefix,color in (('arrow',(30,30,240)),('way',(240,220,50))):
        if result.get('arrow_found' if prefix=='arrow' else 'way_found'):
            x,y,w,h = (result[prefix+'_'+suffix] for suffix in ('x','y','w','h'))
            cv2.rectangle(canvas,(x,y),(x+w,y+h),color,2)
            anchor = (result['acx'],result['acy']) if prefix=='arrow' else (result['wcx'],result['wcy'])
            cv2.circle(canvas,anchor,3,color,-1)
    if result.get('ok'):
        cv2.arrowedLine(canvas,(result['acx'],result['acy']),(result['wcx'],result['wcy']),(50,240,240),2)
    lines = [f"Current map: WS{result['map_ws']} {result['map_name']}" if result['area_found'] else 'Current map: UNKNOWN',
             f"Arrow ({result.get('acx','?')}, {result.get('acy','?')}) -> waystone ({result.get('wcx','?')}, {result.get('wcy','?')}) | client pixels",
             f"Vector ({result.get('dx','?')}, {result.get('dy','?')}) | {result['reason']}",
             result.get('window_diagnostics',{}).get('method','')+' | '+result.get('arrow_diagnostics','')]
    cv2.rectangle(canvas,(0,0),(min(frame.shape[1],1800),110),(20,20,20),-1)
    for i,text in enumerate(lines):
        cv2.putText(canvas,text,(8,24+i*25),cv2.FONT_HERSHEY_SIMPLEX,.55,(240,240,240),1)
    cv2.imwrite(str(path),canvas)
