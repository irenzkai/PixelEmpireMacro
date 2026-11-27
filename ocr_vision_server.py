# ocr_vision_server.py
import ctypes
from ctypes import wintypes
from difflib import SequenceMatcher
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re
import threading
import time
import traceback
from navigation_vision import portal_candidates, player_anchor, boss_minimap_target, registered_map_vector
from urllib.parse import parse_qs, urlparse

import cv2
import mss
import numpy as np
from pathlib import Path
from PIL import Image
from scripts.indicator_regions import effective_roi,resolve_region,configured_regions,screen_bounds
from scripts.local_matching import match_template

try:
    ctypes.windll.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

try:
    from rapidocr import RapidOCR
    RAPID_V3 = True
except ImportError:
    from rapidocr_onnxruntime import RapidOCR
    RAPID_V3 = False

OCR_ENGINE = RapidOCR(params={"Global.use_cls": False}) if RAPID_V3 else RapidOCR()
OCR_LOCK = threading.Lock()
LAST_BOSS_CUE = {}

ROIS = {
    "tower_progress": (0.28, 0.008, 0.72, 0.095),
    "top_bar":       (0.28, 0.008, 0.72, 0.095),
    "minimap_label": (0.83, 0.145, 0.996, 0.285),
    "center_prompt": (0.35, 0.140, 0.65, 0.560),
    "boss_banner":   (0.28, 0.065, 0.72, 0.355),
    "world_map":     (0.18, 0.200, 0.82, 0.820),
    "game_play":     (0.08, 0.080, 0.92, 0.880),
    "full":          (0.00, 0.000, 1.00, 1.000),
}

WAYSTONE_NAMES = {
    0:  "Eldoria",
    1:  "Whisperwood",
    2:  "Elderwood Deep",
    3:  "Mirewood Bog",
    4:  "Sunscar Oasis",
    5:  "Dunes of Khar",
    6:  "Emberfall Caldera",
    7:  "Fallen Outskirts",
    8:  "Ashen Ruins",
    9:  "Varn Necropolis",
    10: "Abyssal Rift",
    11: "Frostvale Hills",
    12: "Glacier Pass",
    13: "Crown of Winter",
    14: "Skyreach Spires",
    15: "Blightwood Wastes",
    16: "Bonebleach Barrens",
    17: "Shardglow Caverns",
    18: "Starfall Isles",
    19: "Coralhollow Reef",
    20: "Ashveil Badlands",
    21: "The Crimson Deep",
    22: "Rimeveil Abyss",
    23: "Glimmerfen Hollows",
    24: "The Sunforge",
    25: "Drumfield Carnival",
    26: "Candlewax Abbey",
    27: "Toppled Gameboard",
    28: "Gilded Glass Palace",
    29: "Mossbound Tribunal",
    30: "Duskhollow of Lost Things",
}

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def _get_process_name(pid: int) -> str:
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(512)
        size = wintypes.DWORD(512)
        if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            return os.path.basename(buf.value).lower()
    finally:
        kernel32.CloseHandle(h)
    return ""


def find_roblox_client_boxes():
    boxes = []
    EnumProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def callback(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        proc = _get_process_name(pid.value)

        length = user32.GetWindowTextLengthW(hwnd)
        title_buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, title_buf, length + 1)
        title = title_buf.value

        if proc == "robloxplayerbeta.exe" or title == "Roblox":
            rc = RECT()
            if user32.GetClientRect(hwnd, ctypes.byref(rc)):
                w = rc.right - rc.left
                h = rc.bottom - rc.top
                if w >= 300 and h >= 200:
                    pt = POINT(0, 0)
                    user32.ClientToScreen(hwnd, ctypes.byref(pt))
                    boxes.append({
                        "hwnd": int(hwnd),
                        "x": int(pt.x),
                        "y": int(pt.y),
                        "w": int(w),
                        "h": int(h),
                    })
        return True

    user32.EnumWindows(EnumProc(callback), 0)
    boxes.sort(key=lambda b: b["x"])
    return boxes


def grab_client_bgr(win_idx: int = 0, roi_name: str = "full"):
    boxes = find_roblox_client_boxes()
    if not boxes:
        return None, None
    box = boxes[min(win_idx, len(boxes) - 1)]
    rx1, ry1, rx2, ry2 = effective_roi(roi_name, ROIS)
    left = box["x"] + int(round(box["w"] * rx1))
    top = box["y"] + int(round(box["h"] * ry1))
    width = max(16, int(round(box["w"] * (rx2 - rx1))))
    height = max(16, int(round(box["h"] * (ry2 - ry1))))
    with mss.mss() as sct:
        raw = sct.grab({"left": left, "top": top, "width": width, "height": height})
        bgr = np.asarray(raw)[:, :, :3].copy()
    return bgr, box


def crop_roi(full_bgr: np.ndarray, roi_name: str) -> np.ndarray:
    h, w = full_bgr.shape[:2]
    rx1, ry1, rx2, ry2 = effective_roi(roi_name, ROIS)
    x1, y1 = max(0, int(round(w * rx1))), max(0, int(round(h * ry1)))
    x2, y2 = min(w, int(round(w * rx2))), min(h, int(round(h * ry2)))
    return full_bgr[y1:y2, x1:x2]


def _pad(img: np.ndarray, pad: int = 12) -> np.ndarray:
    val = 255 if img.ndim == 2 else (255, 255, 255)
    return cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=val)


def _to_bgr(img: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR) if img.ndim == 2 else img


def build_ui_mask(bgr: np.ndarray, mode: str = "ui"):
    up = cv2.resize(bgr, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_NEAREST)
    hsv = cv2.cvtColor(up, cv2.COLOR_BGR2HSV)

    white = cv2.inRange(hsv, np.array([0, 0, 175]), np.array([180, 95, 255]))
    gold = cv2.inRange(hsv, np.array([10, 65, 135]), np.array([40, 255, 255]))
    r1 = cv2.inRange(hsv, np.array([0, 105, 155]), np.array([12, 255, 255]))
    r2 = cv2.inRange(hsv, np.array([168, 105, 155]), np.array([180, 255, 255]))
    red = cv2.bitwise_or(r1, r2)

    if mode == "white":
        mask = white
    elif mode == "gold":
        mask = gold
    else:
        mask = cv2.bitwise_or(white, cv2.bitwise_or(gold, red))

    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((2, 2), np.uint8))
    return mask, up


def tight_crop_bin(mask: np.ndarray, min_pixels: int = 45):
    pts = cv2.findNonZero(mask)
    if pts is None or len(pts) < min_pixels:
        return None
    x, y, w, h = cv2.boundingRect(pts)
    if w < 14 or h < 8:
        return None
    crop = mask[y:y + h, x:x + w]
    return _to_bgr(_pad(255 - crop, pad=12))


def run_rapidocr(img_bgr: np.ndarray):
    with OCR_LOCK:
        res = OCR_ENGINE(img_bgr)

    items = []
    if RAPID_V3:
        txts = getattr(res, "txts", None)
        scores = getattr(res, "scores", None)
        boxes = getattr(res, "boxes", None)
        if txts is None:
            return items
        if scores is None:
            scores = ()
        if boxes is None:
            boxes = ()
        for idx, txt in enumerate(txts):
            sc = float(scores[idx]) if idx < len(scores) else 0.0
            bx = boxes[idx].tolist() if idx < len(boxes) and hasattr(boxes[idx], "tolist") else []
            t = str(txt).strip()
            if t:
                items.append({"text": t, "score": round(sc, 3), "box": bx})
    else:
        raw = res[0] if isinstance(res, tuple) else res
        if raw is not None:
            for entry in raw:
                bx, txt, sc = entry[0], entry[1], float(entry[2])
                t = str(txt).strip()
                if t:
                    items.append({"text": t, "score": round(sc, 3), "box": bx})
    return items


def ocr_roi(roi_name: str, preset: str = "auto", save_debug: bool = False):
    configured=resolve_region(roi_name)
    if configured and (not configured['enabled'] or configured['kind']!='ocr'):
        return {'ok':False,'error':'Region disabled or uses image matching','items':[],'text':''}
    bgr, win_box = grab_client_bgr(roi_name=roi_name)
    if bgr is None:
        return {"ok": False, "error": "Roblox window not found", "items": [], "text": ""}
    result=ocr_bgr(bgr,roi_name,preset,save_debug,win_box)
    if roi_name in ('map_name','top_bar') and result.get('text'):
        from scripts.map_labels import record
        record(Path(__file__).resolve().parent,result['text'],bgr,max((i['score'] for i in result['items']),default=0))
    return result


def ocr_bgr(bgr,roi_name='custom',preset='auto',save_debug=False,win_box=None):

    mode = "gold" if roi_name == "minimap_label" else ("white" if roi_name == "center_prompt" else "ui")
    mask, up = build_ui_mask(bgr, mode=mode)
    ui_bin = tight_crop_bin(mask, min_pixels=30)

    variants = []
    if ui_bin is not None:
        variants.append(("ui_bin", ui_bin))

    if preset == "full" or (preset != "fast" and ui_bin is None):
        blur = cv2.GaussianBlur(up, (0, 0), 1.0)
        sharp = cv2.addWeighted(up, 1.5, blur, -0.5, 0)
        variants.append(("sharp", sharp))

    if save_debug:
        os.makedirs("debug_ocr", exist_ok=True)
        cv2.imwrite(f"debug_ocr/{roi_name}_raw.png", bgr)
        for vname, vimg in variants:
            cv2.imwrite(f"debug_ocr/{roi_name}_{vname}.png", vimg)

    seen = {}
    for idx, (vname, vimg) in enumerate(variants):
        hits = run_rapidocr(vimg)
        for it in hits:
            norm = re.sub(r"\s+", " ", it["text"]).strip()
            key = norm.lower()
            if key not in seen or it["score"] > seen[key]["score"]:
                seen[key] = {"text": norm, "score": it["score"], "variant": vname, "box": it["box"]}
        if preset != "full" and idx == 0 and any(h["score"] >= 0.70 and len(h["text"]) >= 3 for h in hits):
            break

    items = sorted(seen.values(), key=lambda x: x["score"], reverse=True)
    return {"ok": True, "roi": roi_name, "meta": win_box, "items": items, "text": " | ".join(it["text"] for it in items)}


def _clean(s: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def detect_portal_swirl(save_debug: bool = False):
    """Detects animated portal by its glowing green/cyan rotating swirl + wooden vine arch."""
    t0 = time.perf_counter()
    bgr, win_box = grab_client_bgr(roi_name="full")
    if bgr is None:
        return {"ok": 0, "found": 0}

    result = portal_candidates(bgr)
    result.update(player_anchor(bgr))
    for key in ('x', 'player_x'):
        if key in result:
            result[key] += win_box['x']
    for key in ('y', 'player_y'):
        if key in result:
            result[key] += win_box['y']
    result['ms'] = int((time.perf_counter()-t0)*1000)
    return result



def match_waystone_name(text: str):
    from scripts.reference_setup_store import connect
    with connect() as c:
        if c.execute("SELECT 1 FROM sqlite_master WHERE name='manual_map_aliases'").fetchone():
            alias=c.execute('SELECT ws FROM manual_map_aliases WHERE text_key=?',(' '.join(text.split()).casefold(),)).fetchone()
            if alias:return alias[0],WAYSTONE_NAMES[alias[0]],1.0
    from scripts.map_labels import corrected
    text=corrected(Path(__file__).resolve().parent,text)
    c = _clean(text)
    if not c:
        return -1, "", 0.0
    if "tower of trials" in c or "tower floor" in c:
        return -2, "Tower of Trials", 1.0

    best_idx, best_name, best_ratio = -1, "", 0.0
    for idx, name in WAYSTONE_NAMES.items():
        nc = _clean(name)
        if nc in c or all(word in c.split() for word in nc.split()):
            return idx, name, 1.0
        ratio = SequenceMatcher(None, nc, c).ratio()
        if ratio > best_ratio:
            best_idx, best_name, best_ratio = idx, name, ratio

    if best_ratio >= 0.72:
        return best_idx, best_name, round(best_ratio, 3)
    return -1, "", round(best_ratio, 3)


def configured_detection(name):
    row=resolve_region(name)
    if not row:return None
    if not row.get('enabled'):return {'ok':1,'found':0,'text':'Disabled'}
    return test_indicator(name)


def detect_live_waystone(preview=False, bounds=None, threshold=None, expected_scene=None, recovery=False, view_epoch=0):
    from scripts.waystone_detection import match_waystone, configuration, reference_signature
    from scripts.waystone_tracking import TRACKING
    from contextlib import nullcontext
    started = time.perf_counter()
    cfg = configuration()
    boxes = find_roblox_client_boxes()
    if not boxes:
        return dict(ok=0, found=0, accepted=0, status='uncertain', capture_tick=time.monotonic(), error='Roblox window not found')
    box = boxes[0]
    scene = tuple(box[name] for name in ('hwnd','x','y','w','h'))
    if expected_scene is not None and scene != expected_scene:
        return dict(ok=1, found=0, accepted=0, status='uncertain', capture_tick=time.monotonic(), reason='Client moved before capture')
    w, h = box['w'], box['h']
    base = bounds if bounds is not None else (box['x']+round(w*.08),box['y']+round(h*.12),box['x']+round(w*.92),box['y']+round(h*.82))
    base = (max(box['x'],base[0]),max(box['y'],base[1]),min(box['x']+w,base[2]),min(box['y']+h,base[3]))
    if base[2]-base[0] < 12 or base[3]-base[1] < 18:
        return dict(ok=0, found=0, accepted=0, status='uncertain', capture_tick=time.monotonic(), error='Waystone search region is too small')
    key = (reference_signature(cfg),scene,base,threshold,view_epoch)
    region, scale_hint, scope = TRACKING.region(key,base,cfg)
    if preview:
        from scripts.window_registry import hidden_macro_windows
    with hidden_macro_windows() if preview else nullcontext():
        capture_tick = time.monotonic()
        rectangle = {'left':box['x'],'top':box['y'],'width':w,'height':h} if preview else {'left':region[0],'top':region[1],'width':region[2]-region[0],'height':region[3]-region[1]}
        with mss.mss() as capture:
            pixels = np.asarray(capture.grab(rectangle))[:,:,:3].copy()
    capture_ms = round((time.perf_counter()-started)*1000)
    if preview:
        left, top = region[0]-box['x'],region[1]-box['y']
        query = pixels[top:region[3]-box['y'],left:region[2]-box['x']]
    else:
        query = pixels
    compute_start = time.perf_counter()
    # Recovery acquisition gets the already-approved preview search coverage;
    # local tracking keeps the existing shorter budget and all acceptance gates.
    budget = cfg['preview_budget_ms'] if preview or (recovery and scope == 'full') else cfg['search_budget_ms']
    result = match_waystone(query,threshold,budget,scale_hint=scale_hint,local=scope=='local')
    result.update(capture_tick=capture_tick,capture_ms=capture_ms,compute_ms=round((time.perf_counter()-compute_start)*1000),search_scope=scope)
    if 'x' in result:
        result['x'] += region[0]; result['y'] += region[1]
    TRACKING.observe(key,result,scope)
    if scope == 'local' and not result.get('found'):
        result['reacquire'] = 'Full search on next request'
    result['ms'] = round((time.perf_counter()-started)*1000)
    if preview:
        canvas = pixels.copy()
        if scope == 'local':
            cv2.rectangle(canvas,(region[0]-box['x'],region[1]-box['y']),(region[2]-box['x'],region[3]-box['y']),(200,140,60),1)
        if 'x' in result:
            x,y = result['x']-box['x'],result['y']-box['y']
            color = (50,220,50) if result['found'] else (0,190,255)
            cv2.rectangle(canvas,(x,y),(x+result['w'],y+result['h']),color,2)
            cv2.putText(canvas,'ACCEPTED' if result['found'] else 'BEST CANDIDATE - UNCERTAIN',(max(0,x),max(16,y-7)),cv2.FONT_HERSHEY_SIMPLEX,.45,color,1)
        lines = [f"Best candidate {result['score']:.3f} / {result['threshold']:.3f} | Accepted detection: {'YES' if result['found'] else 'NONE'}",
                 f"{result['reason']} | margin {result.get('candidate_margin',0):.3f} | objects {result['physical_object_count']}",
                 f"Capture {result['capture_ms']}ms | matching {result['compute_ms']}ms | total {result['ms']}ms | {scope} search",
                 f"Reference: {result.get('reference_name','none')} | live references {result['live_reference_count']} | complete candidate {result.get('candidate_complete',0)}"]
        cv2.rectangle(canvas,(0,0),(min(w,1300),110),(20,20,20),-1)
        for index,text in enumerate(lines):
            cv2.putText(canvas,text,(8,24+index*25),cv2.FONT_HERSHEY_SIMPLEX,.55,(240,240,240),1)
        path = Path(__file__).resolve().parent/'.task-output/waystone_preview.png'
        cv2.imwrite(str(path),canvas)
        result['crop_path'] = str(path)
    return result


def poll_live_waystone(bounds=None, threshold=None, recovery=False, tracking=False, view_epoch=0):
    from scripts.waystone_worker import WORKER
    from scripts.waystone_detection import configuration, reference_signature
    cfg = configuration()
    boxes = find_roblox_client_boxes()
    scene = tuple(boxes[0][name] for name in ('hwnd','x','y','w','h')) if boxes else None
    key = (bounds,threshold,reference_signature(cfg),scene,recovery,view_epoch)
    return WORKER.poll(key,lambda: detect_live_waystone(False,bounds,threshold,expected_scene=scene,recovery=recovery,view_epoch=view_epoch),cfg['max_result_age_ms'],tracking=tracking)


def check_waystone_fast():
    configured=configured_detection('waystone_prompt')
    if configured is not None:return {'ok':configured.get('ok',0),'on_waystone':configured.get('found',0),'text':configured.get('text',''),'ms':0}
    t0 = time.perf_counter()
    bgr, _ = grab_client_bgr(roi_name="center_prompt")
    if bgr is None:
        return {"ok": 0, "on_waystone": 0, "error": "Roblox window not found"}

    from scripts.waystone_detection import match_ward_prompt
    ward = match_ward_prompt(bgr)
    if ward['found']:
        return dict(ok=1, on_waystone=1, text='Configured ward prompt image',
                    prompt_score=ward['score'], evidence='ward_prompt',
                    ms=round((time.perf_counter()-t0)*1000))

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    blue = cv2.inRange(hsv, np.array([94, 90, 115]), np.array([122, 255, 255]))
    blue_dil = cv2.dilate(blue, np.ones((9, 9), np.uint8), iterations=1)
    white = cv2.inRange(hsv, np.array([0, 0, 185]), np.array([180, 85, 255]))
    hit = cv2.bitwise_and(white, blue_dil)

    if cv2.countNonZero(hit) < 25:
        ms = int(round((time.perf_counter() - t0) * 1000))
        return {"ok": 1, "on_waystone": 0, "fast_skip": 1, "ms": ms, "text": ""}

    pts = cv2.findNonZero(hit)
    x, y, w, h = cv2.boundingRect(pts)
    pad = 8
    sub = bgr[max(0, y - pad):min(bgr.shape[0], y + h + pad), max(0, x - pad):min(bgr.shape[1], x + w + pad)]
    mask, _ = build_ui_mask(sub, mode="white")
    bin_img = tight_crop_bin(mask, min_pixels=20)
    txt = " | ".join(it["text"] for it in run_rapidocr(bin_img)) if bin_img is not None else ""
    c = _clean(txt)
    on_ws = 1 if any(k in c for k in ("warp back", "return to town", "warpback")) else 0
    ms = int(round((time.perf_counter() - t0) * 1000))
    return {"ok": 1, "on_waystone": on_ws, "fast_skip": 0, "ms": ms, "text": txt}


def check_tower_fast():
    t0=time.perf_counter()
    inside=configured_detection('in_tower')
    cleared=configured_detection('floor_cleared')
    region=resolve_region('tower_progress')
    progress=configured_detection('tower_progress') if region and region['kind']=='image' else None
    res=progress if progress is not None else ocr_roi('tower_progress',preset='fast',save_debug=False)
    text=res.get('text','');cleaned=_clean(text)
    in_tower=inside.get('found',0) if inside is not None else (
        progress.get('found',0) if progress is not None else int('tower of trials' in cleaned or 'tower floor' in cleaned))
    floor_cleared=cleared.get('found',0) if cleared is not None else int(bool(in_tower) and any(
        word in cleaned for word in ('cleared','leared','walk through','walkthrough','roughthe')))
    return dict(ok=int(bool(res.get('ok') or (inside or {}).get('ok') or (cleared or {}).get('ok'))),
        in_tower=int(bool(in_tower or floor_cleared)),floor_cleared=floor_cleared,text=text,
        ms=round((time.perf_counter()-t0)*1000))


def check_boss_fast():
    from scripts.notification_formats import parse_notification
    region=resolve_region('boss_banner')
    if not region or not region['enabled']:
        return {'ok':1,**parse_notification(''),'reason':'Notification region/examples pending'}
    result=ocr_roi('boss_banner',preset='auto',save_debug=False)
    parsed=parse_notification(result.get('text',''))
    parsed.update(ok=int(bool(result.get('ok'))),ms=0)
    return parsed


def analyze_world_map(target_idx: int = -1, save_debug: bool = False, target_kind: str = 'waystone', quadrant: str = ''):
    from contextlib import nullcontext
    if save_debug:
        from scripts.window_registry import hidden_macro_windows
    capture_started = time.perf_counter()
    with hidden_macro_windows() if save_debug else nullcontext():
        full, box = grab_client_bgr(roi_name='full')
    capture_ms = round((time.perf_counter()-capture_started)*1000,2)
    if full is None:
        return {'ok':0,'open':0,'map_ws':-1,'map_name':'UNKNOWN','reason':'Roblox client not found'}
    started = time.perf_counter()
    result = registered_map_vector(full,target_idx,target_kind,quadrant,ocr=run_rapidocr)
    result['ms'] = round((time.perf_counter()-started)*1000)
    result['capture_ms'] = capture_ms
    if save_debug:
        from scripts.world_map_detection import save_preview
        path = Path(__file__).resolve().parent/'.task-output/world_map_preview.png'
        save_preview(full,result,path)
        result['crop_path'] = str(path)
        (path.with_suffix('.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


def world_map_state():
    """Reuse approved viewport/window anchors, without map identity/OCR work."""
    from scripts.world_map_detection import viewport, configuration
    started = time.perf_counter()
    full, _ = grab_client_bgr(roi_name='full')
    if full is None:
        return dict(ok=0,state='unknown',reason='Roblox client not found')
    cfg = configuration()
    bounds, header, reason = viewport(full, cfg)
    if bounds is not None:
        state = 'open'
    elif reason == 'World Map header not confirmed':
        state = 'closed'
    else:
        state = 'unknown'
    return dict(ok=int(state != 'unknown'),state=state,open=int(state=='open'),
                reason=reason,ms=round((time.perf_counter()-started)*1000))


def _legacy_analyze_world_map(target_idx: int = -1, save_debug: bool = False):
    bgr, _ = grab_client_bgr(roi_name="world_map")
    if bgr is None:
        return {"ok": 0, "open": 0, "error": "Roblox not found"}

    header = bgr[0:int(bgr.shape[0] * 0.14), 0:int(bgr.shape[1] * 0.45)]
    hdr_up = cv2.resize(header, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_NEAREST)
    hdr_txt = " ".join(it["text"] for it in run_rapidocr(hdr_up)).lower()
    is_open = ("world map" in hdr_txt) or ("world" in hdr_txt and "map" in hdr_txt)

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    r1 = cv2.inRange(hsv, np.array([0, 145, 140]), np.array([10, 255, 255]))
    r2 = cv2.inRange(hsv, np.array([168, 145, 140]), np.array([180, 255, 255]))
    red_mask = cv2.morphologyEx(cv2.bitwise_or(r1, r2), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

    arrow_found, acx, acy = 0, 0, 0
    num_l, _, stats, centroids = cv2.connectedComponentsWithStats(red_mask)
    best_area = 0
    for i in range(1, num_l):
        area = int(stats[i, cv2.CC_STAT_AREA])
        if 35 <= area <= 1600 and area > best_area:
            best_area = area
            acx, acy = int(round(centroids[i][0])), int(round(centroids[i][1]))
            arrow_found = 1

    cyan_mask = cv2.inRange(hsv, np.array([92, 70, 150]), np.array([122, 255, 255]))
    cyan_mask = cv2.morphologyEx(cyan_mask, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    num_w, _, w_stats, w_cent = cv2.connectedComponentsWithStats(cyan_mask)

    way_found, wcx, wcy = 0, 0, 0
    if arrow_found:
        best_dist = 1e9
        for i in range(1, num_w):
            area = int(w_stats[i, cv2.CC_STAT_AREA])
            if 20 <= area <= 1200:
                cx, cy = float(w_cent[i][0]), float(w_cent[i][1])
                d = ((cx - acx) ** 2 + (cy - acy) ** 2) ** 0.5
                if d < best_dist:
                    best_dist = d
                    wcx, wcy = int(round(cx)), int(round(cy))
                    way_found = 1

    return {
        "ok": 1 if (is_open and arrow_found and way_found) else 0,
        "open": 1 if is_open else 0,
        "arrow_found": arrow_found,
        "way_found": way_found,
        "acx": acx, "acy": acy, "wcx": wcx, "wcy": wcy,
        "dx": (wcx - acx) if (arrow_found and way_found) else 0,
        "dy": (wcy - acy) if (arrow_found and way_found) else 0,
    }


def to_ahk_kv(d: dict) -> str:
    return "\n".join(f"{k}={v}" for k, v in d.items())


def test_indicator(name,preview=False):
    if name == 'waystone':
        return detect_live_waystone(preview)
    region=resolve_region(name)
    if not region:return {'ok':0,'error':'Unknown indicator region'}
    if not region['enabled']:return {'ok':1,'enabled':0,'found':0,'name':name,'text':'Region disabled'}
    boxes=find_roblox_client_boxes()
    if not boxes:return {'ok':0,'error':'Roblox window not found'}
    box=boxes[0];client=[box['x'],box['y'],box['w'],box['h']]
    x,y,w,h=screen_bounds(region['normalized'],client)
    with mss.mss() as capture:
        bgr=np.asarray(capture.grab({'left':x,'top':y,'width':w,'height':h}))[:,:,:3].copy()
    result={'ok':1,'enabled':1,'name':name,'kind':region['kind'],'x':x,'y':y,'w':w,'h':h,
            'client_w':box['w'],'client_h':box['h'],'normalized':region['normalized']}
    if region['kind']=='ocr':
        detected=ocr_bgr(bgr,name,'auto',False,box)
        text=detected.get('text','');expected=region.get('expected_text',[])
        if name=='map_name' or region.get('builtin_alias')=='top_bar':
            from scripts.map_labels import record
            record(Path(__file__).resolve().parent,text,bgr,max((r['score'] for r in detected.get('items',[])),default=0))
        result.update(text=text,score=max((r['score'] for r in detected.get('items',[])),default=0),
            found=int(any(_clean(value) in _clean(text) for value in expected) if expected else bool(text.strip())))
    else:
        reference=region.get('reference')
        if not reference:raise ValueError('Detection reference is unavailable')
        project=Path(__file__).resolve().parent
        path=(project/reference['path']).resolve()
        if not (path.is_relative_to(project/'public') or path.is_relative_to(project/'references')):raise ValueError('Reference must be inside public or references')
        import hashlib
        if hashlib.sha256(path.read_bytes()).hexdigest()!=reference['derived_sha']:raise ValueError('Reference image changed; reconfirm it')
        with Image.open(path) as image:template=image.convert('RGBA')
        query=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB))
        score,matched,_,_=match_template(query,template,False)
        if matched:
            ratio=min(1.,192/max(query.size))
            mx,my,mw,mh=matched
            result.update(x=x+round((mx+mw/2)/ratio),y=y+round((my+mh/2)/ratio))
        result.update(reference_name=reference['name'],score=max(0,score),found=int(score>=region['threshold']))
    if preview:
        folder=Path(__file__).resolve().parent/'.task-output/indicator_tests';folder.mkdir(exist_ok=True)
        path=folder/(name+'.png');cv2.imwrite(str(path),bgr)
        result['crop_path']=str(path)
    return result


class OcrHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            if self.path!='/ocr_image':self._send({'ok':0,'error':'Unknown endpoint'},'json',404);return
            length=int(self.headers.get('Content-Length',0))
            if length>8192:raise ValueError('Request too large')
            data=json.loads(self.rfile.read(length));path=Path(data['path']).resolve();root=Path(__file__).resolve().parent
            if not any(path.is_relative_to(root/folder) for folder in ('public','references','map_labels')):
                raise ValueError('Choose an imported reference or public image')
            bgr=cv2.imread(str(path))
            if bgr is None:raise ValueError('Image unavailable')
            self._send(ocr_bgr(bgr,'manual_image','full',False), 'json')
        except Exception as exc:self._send({'ok':0,'error':str(exc)},'json',400)

    def log_message(self, format, *args):
        return

    def _send(self, payload, fmt: str = "json", code: int = 200):
        body = to_ahk_kv(payload) if fmt == "ahk" else json.dumps(payload, ensure_ascii=False)
        ctype = "text/plain; charset=utf-8" if fmt == "ahk" else "application/json; charset=utf-8"
        raw = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        fmt = "json"
        try:
            parsed = urlparse(self.path)
            q = parse_qs(parsed.query)
            fmt = q.get("format", ["json"])[0]
            save_dbg = q.get("debug", ["0"])[0] == "1"

            if parsed.path == "/ping":
                self._send({"ok": 1, "windows": len(find_roblox_client_boxes())}, fmt)
            elif parsed.path == "/waystone_fast":
                self._send(check_waystone_fast(), fmt)
            elif parsed.path == "/tower_fast":
                self._send(check_tower_fast(), fmt)
            elif parsed.path == "/boss_fast":
                self._send(check_boss_fast(), fmt)
            elif parsed.path == "/state":
                map_region=resolve_region('map_name')
                map_reference=configured_detection('map_name') if map_region and map_region['kind']=='image' else None
                if map_reference is not None and map_region['kind']=='image':
                    label=' | '.join(map_region.get('expected_text',[])) if map_reference.get('found') else ''
                    top={'text':label}
                    if label:
                        from scripts.map_labels import record
                        record(Path(__file__).resolve().parent,label,score=map_reference.get('score',0))
                else:top = ocr_roi('top_bar', preset='fast')
                idx, name, confidence = match_waystone_name(top.get('text',''))
                result = {'ok':1, 'ws_idx':idx, 'ws_name':name, 'confidence':confidence}
                if q.get('boss',['1'])[0] == '1':
                    result.update(check_boss_fast())
                if q.get('prompt',['1'])[0] == '1':
                    result['on_waystone'] = check_waystone_fast().get('on_waystone',0)
                self._send(result,fmt)
            elif parsed.path == "/boss_target":
                info = check_boss_fast()
                full, _ = grab_client_bgr(roi_name='full')
                target = boss_minimap_target(full) if full is not None else {'target_reliable':0}
                if not info.get('active') or not info.get('location_reliable'):
                    target['target_reliable'] = 0
                    target['reason'] = 'No active boss with a reliable current-map landmark; F8 fallback'
                info.update(target)
                self._send(info,fmt)
            elif parsed.path == '/configured_portal':
                from scripts.portal_matching import match_portal
                full,box=grab_client_bgr(roi_name='full')
                if full is None:self._send({'ok':0,'found':0,'reason':'Roblox unavailable'},fmt);return
                result=match_portal(full,int(q.get('source',['-1'])[0]),int(q.get('destination',['-1'])[0]))
                result.update(player_anchor(full))
                for key,offset in (('x',box['x']),('y',box['y']),('player_x',box['x']),('player_y',box['y'])):
                    if key in result:result[key]+=offset
                self._send(result,fmt)
            elif parsed.path == "/portal_fast":
                custom=configured_detection('portal')
                if custom is not None:
                    self._send(custom,fmt)
                    return
                self._send(detect_portal_swirl(save_dbg), fmt)
            elif parsed.path == "/ocr":
                roi = q.get("roi", ["top_bar"])[0]
                res = ocr_roi(roi, preset=q.get("preset", ["auto"])[0], save_debug=save_dbg)
                self._send({"ok": 1 if res.get("ok") else 0, "text": res.get("text", "")} if fmt == "ahk" else res, fmt)
            elif parsed.path == '/indicator':
                self._send(test_indicator(q.get('name',[''])[0],q.get('preview',['0'])[0]=='1'),fmt)
            elif parsed.path == '/waystone_sprite':
                bounds = tuple(int(q[key][0]) for key in ('x1','y1','x2','y2')) if all(key in q for key in ('x1','y1','x2','y2')) else None
                threshold = float(q['threshold'][0]) if 'threshold' in q else None
                asynchronous = q.get('async',['0'])[0]=='1' and q.get('preview',['0'])[0]!='1'
                recovery = q.get('recovery',['0'])[0]=='1'
                tracking = q.get('tracking',['0'])[0]=='1'
                view_epoch = int(q.get('view_epoch',['0'])[0])
                self._send(poll_live_waystone(bounds, threshold,recovery,tracking,view_epoch) if asynchronous else detect_live_waystone(q.get('preview',['0'])[0]=='1', bounds, threshold), fmt)
            elif parsed.path == '/indicator_regions':
                self._send({'ok':1,'regions':configured_regions()},fmt)
            elif parsed.path == '/worldmap_state':
                self._send(world_map_state(), fmt)
            elif parsed.path == "/worldmap_vector":
                self._send(analyze_world_map(int(q.get("target", ["-1"])[0]), save_dbg or q.get("preview",["0"])[0]=="1", q.get('kind',['waystone'])[0], q.get('quad',[''])[0]), fmt)
            else:
                self._send({"ok": 0, "error": "Unknown endpoint"}, fmt, 404)
        except Exception as e:
            traceback.print_exc()
            self._send({"ok": 0, "error": str(e)}, fmt, 500)


if __name__ == "__main__":
    try:
        run_rapidocr(np.full((48, 160, 3), 255, dtype=np.uint8))
    except Exception:
        pass
    host, port = "127.0.0.1", 8765
    print(f"OCR Vision Server listening on http://{host}:{port}")
    ThreadingHTTPServer((host, port), OcrHandler).serve_forever()
