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
from urllib.parse import parse_qs, urlparse

import cv2
import mss
import numpy as np

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

ROIS = {
    "top_bar":       (0.28, 0.008, 0.72, 0.095),
    "minimap_label": (0.83, 0.145, 0.996, 0.285),
    "center_prompt": (0.35, 0.140, 0.65, 0.560),
    "boss_banner":   (0.30, 0.065, 0.70, 0.270),
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
    rx1, ry1, rx2, ry2 = ROIS.get(roi_name, ROIS["full"])
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
    rx1, ry1, rx2, ry2 = ROIS.get(roi_name, ROIS["full"])
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
    bgr, win_box = grab_client_bgr(roi_name=roi_name)
    if bgr is None:
        return {"ok": False, "error": "Roblox window not found", "items": [], "text": ""}

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
    bgr, win_box = grab_client_bgr(roi_name="game_play")
    if bgr is None:
        return {"ok": 0, "found": 0}

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    # Glowing green/cyan inner portal vortex (swirling core from your uploaded image)
    swirl_mask = cv2.inRange(hsv, np.array([42, 60, 110]), np.array([88, 255, 255]))
    swirl_mask = cv2.morphologyEx(swirl_mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))

    num_l, _, stats, centroids = cv2.connectedComponentsWithStats(swirl_mask)
    best_area = 0
    pcx, pcy = 0, 0
    found = 0

    rx1, ry1, rx2, ry2 = ROIS["game_play"]
    screen_ox = win_box["x"] + int(round(win_box["w"] * rx1))
    screen_oy = win_box["y"] + int(round(win_box["h"] * ry1))

    for i in range(1, num_l):
        area = int(stats[i, cv2.CC_STAT_AREA])
        w = int(stats[i, cv2.CC_STAT_WIDTH])
        h = int(stats[i, cv2.CC_STAT_HEIGHT])
        # Portals have vertical oval proportion (h >= w * 1.1)
        if 250 <= area <= 6500 and h >= int(w * 1.05):
            if area > best_area:
                best_area = area
                pcx = screen_ox + int(round(centroids[i][0]))
                pcy = screen_oy + int(round(centroids[i][1]))
                found = 1

    ms = int(round((time.perf_counter() - t0) * 1000))
    if save_debug and found:
        os.makedirs("debug_ocr", exist_ok=True)
        cv2.imwrite("debug_ocr/portal_swirl_detected.png", swirl_mask)

    return {"ok": 1, "found": found, "x": pcx, "y": pcy, "area": best_area, "ms": ms}


def _classify_boss_banner(bos_txt: str):
    bc = _clean(bos_txt)
    if len(bc) < 3:
        return {"active": 0, "kind": "", "defeated": 0, "you_defeated": 0, "boss_state": "", "boss_text": ""}
    you_def = 1 if ("defeated by" in bc) else 0
    is_mini = ("miniboss" in bc) or ("mini boss" in bc)
    defeated = 1 if ("boss defeated" in bc or "miniboss defeated" in bc or you_def) else 0
    active, kind, boss_state = 0, "", ""

    if defeated:
        boss_state = "MINIBOSS_DEFEATED" if is_mini else "DEFEATED"
    elif is_mini and any(k in bc for k in ("coming", "appeared", "awakening", "lv", "%")):
        active, kind, boss_state = 1, "Miniboss", "MINIBOSS"
    elif any(k in bc for k in ("boss is coming", "boss has appeared", "has appeared", "awakening at")):
        active, kind = 1, "Boss"
        boss_state = "SPAWN" if "appeared" in bc else "COMING"
    elif "%" in bos_txt and "lv" in bc:
        active, kind, boss_state = 1, "Boss", "SPAWN"

    return {
        "active": active, "kind": kind, "defeated": defeated,
        "you_defeated": you_def, "boss_state": boss_state, "boss_text": bos_txt
    }


def match_waystone_name(text: str):
    c = _clean(text)
    if not c:
        return -1, "", 0.0
    if "tower of trials" in c or "tower floor" in c:
        return -2, "Tower of Trials", 1.0

    best_idx, best_name, best_ratio = -1, "", 0.0
    for idx, name in WAYSTONE_NAMES.items():
        nc = _clean(name)
        if nc in c:
            return idx, name, 1.0
        ratio = SequenceMatcher(None, nc, c).ratio()
        if ratio > best_ratio:
            best_idx, best_name, best_ratio = idx, name, ratio

    if best_ratio >= 0.72:
        return best_idx, best_name, round(best_ratio, 3)
    return -1, "", round(best_ratio, 3)


def check_waystone_fast():
    t0 = time.perf_counter()
    bgr, _ = grab_client_bgr(roi_name="center_prompt")
    if bgr is None:
        return {"ok": 0, "on_waystone": 0, "error": "Roblox window not found"}

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
    t0 = time.perf_counter()
    res = ocr_roi("top_bar", preset="fast", save_debug=False)
    if not res.get("ok"):
        return {"ok": 0, "in_tower": 0, "floor_cleared": 0}
    c = _clean(res.get("text", ""))
    in_tower = 1 if ("tower of trials" in c or "tower floor" in c) else 0
    cleared = 1 if (in_tower and any(k in c for k in ("cleared", "leared", "walk through", "walkthrough", "roughthe"))) else 0
    ms = int(round((time.perf_counter() - t0) * 1000))
    return {"ok": 1, "in_tower": in_tower, "floor_cleared": cleared, "ms": ms, "text": res.get("text", "")}


def check_boss_fast():
    t0 = time.perf_counter()
    res = ocr_roi("boss_banner", preset="fast", save_debug=False)
    if not res.get("ok"):
        return {"ok": 0, "active": 0, "kind": "", "defeated": 0, "you_defeated": 0, "boss_state": "", "boss_text": ""}
    info = _classify_boss_banner(res.get("text", ""))
    info["ok"] = 1
    info["ms"] = int(round((time.perf_counter() - t0) * 1000))
    return info


def analyze_world_map(target_idx: int = -1, save_debug: bool = False):
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


class OcrHandler(BaseHTTPRequestHandler):
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
            elif parsed.path == "/portal_fast":
                self._send(detect_portal_swirl(save_dbg), fmt)
            elif parsed.path == "/ocr":
                roi = q.get("roi", ["top_bar"])[0]
                res = ocr_roi(roi, preset=q.get("preset", ["auto"])[0], save_debug=save_dbg)
                self._send({"ok": 1 if res.get("ok") else 0, "text": res.get("text", "")} if fmt == "ahk" else res, fmt)
            elif parsed.path == "/worldmap_vector":
                self._send(analyze_world_map(int(q.get("target", ["-1"])[0]), save_dbg), fmt)
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