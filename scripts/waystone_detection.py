"""Local frame-based waystone evidence. No capture, game input or network here."""
from functools import lru_cache
from pathlib import Path
import json
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def configuration():
    cfg = json.loads((ROOT/'config/waystone_detector.json').read_text(encoding='utf-8'))
    from scripts.legacy_references import configured_image
    path = configured_image('General', 'RecoveryImg', cfg['sheet']).resolve()
    if not path.is_relative_to(ROOT/'public'):
        raise ValueError('Waystone reference must remain in public')
    cfg['sheet_path'] = path
    return cfg


def live_reference_paths(cfg):
    folder = (ROOT/cfg.get('live_reference_dir', 'public/waystone_live')).resolve()
    if not folder.is_relative_to(ROOT/'public'):
        raise ValueError('Live waystone references must stay inside public')
    if not folder.exists():
        return []
    return sorted(p for p in folder.iterdir() if p.is_file() and not p.is_symlink()
                  and p.suffix.lower() in ('.png','.jpg','.jpeg','.webp','.bmp'))[:32]


def reference_signature(cfg):
    paths = [cfg['sheet_path'], ROOT/'config/waystone_detector.json', ROOT/'waystone_config.ini', *live_reference_paths(cfg)]
    return tuple((str(p), p.stat().st_size, p.stat().st_mtime_ns) for p in paths)


@lru_cache(maxsize=40)
def live_body(path, stamp, normalized_box):
    image = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if image is None:
        raise ValueError('Live waystone reference cannot be opened: '+path)
    if image.ndim == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGRA)
    elif image.shape[2] == 3:
        image = cv2.cvtColor(image, cv2.COLOR_BGR2BGRA)
    h, w = image.shape[:2]
    x, y, bw, bh = normalized_box
    left, top, right, bottom = round(x*w), round(y*h), round((x+bw)*w), round((y+bh)*h)
    if min(left, top) < 0 or right > w or bottom > h or right-left < 8 or bottom-top < 20:
        raise ValueError('Live body box must contain a complete pillar body: '+path)
    body = image[top:bottom,left:right].copy()
    # Canonical body height shares the asset scale system; no activation labels.
    return cv2.resize(body, (max(8, round(body.shape[1]*25/body.shape[0])), 25), interpolation=cv2.INTER_AREA)


def features(bgr):
    # Same local contrast / edge evidence used by portal_matching, without hue gating.
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    normalized = cv2.createCLAHE(clipLimit=2., tileGridSize=(8, 8)).apply(gray)
    return normalized, cv2.Canny(normalized, 45, 120)


@lru_cache(maxsize=3)
def frames(path, stamp, columns, rows, body_box):
    sheet = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if sheet is None:
        raise ValueError('Waystone sheet is unavailable')
    h, w = sheet.shape[:2]
    if min(columns, rows) < 1 or w % columns or h % rows:
        raise ValueError('Animation grid does not divide the sheet evenly')
    cw, ch = w//columns, h//rows
    # A replacement single image is allowed only with explicit 1x1 grid configuration.
    x, y, bw, bh = body_box
    if min(x, y) < 0 or min(bw, bh) < 3 or x+bw > cw or y+bh > ch:
        raise ValueError('Stable body box must stay inside each animation frame')
    output = []
    seen = set()
    for row in range(rows):
        for column in range(columns):
            body = sheet[row*ch+y:row*ch+y+bh, column*cw+x:column*cw+x+bw].copy()
            if body.ndim == 2:
                body = cv2.cvtColor(body, cv2.COLOR_GRAY2BGRA)
            if body.shape[2] == 3:
                body = cv2.cvtColor(body, cv2.COLOR_BGR2BGRA)
            # Identical stable bodies need not be searched repeatedly.
            key = body.tobytes()
            if key not in seen:
                output.append((row*columns+column, body))
                seen.add(key)
    return output


def correlation(qgray, qedge, gray, edge, mask):
    lum = cv2.matchTemplate(qgray, gray, cv2.TM_CCOEFF_NORMED, mask=mask)
    shape = cv2.matchTemplate(qedge, edge, cv2.TM_CCORR_NORMED, mask=mask)
    lum = np.clip(np.nan_to_num(lum, nan=0., posinf=0., neginf=0.), 0., 1.)
    shape = np.clip(np.nan_to_num(shape, nan=0., posinf=0., neginf=0.), 0., 1.)
    return lum, shape


def match_waystone(bgr, threshold=None, budget_ms=None, scale_hint=None, local=False):
    from scripts.waystone_body_matching import match_stable_body
    cfg = configuration()
    threshold = float(cfg['threshold'] if threshold is None else threshold)
    if not .05 <= threshold <= 1.:
        raise ValueError('Waystone threshold must be between 0.05 and 1')
    path = cfg['sheet_path']
    asset_variants = frames(str(path), path.stat().st_mtime_ns, int(cfg['columns']), int(cfg['rows']), tuple(cfg['body_box']))
    labels = {index: 'Asset frame '+str(index+1) for index, _ in asset_variants}
    variants = []
    offset = int(cfg['columns'])*int(cfg['rows'])
    paths = live_reference_paths(cfg)
    for i, live in enumerate(paths):
        box = cfg.get('live_body_boxes', {}).get(live.name, cfg['live_body_box'])
        variants.append((offset+i, live_body(str(live), live.stat().st_mtime_ns, tuple(box))))
        labels[offset+i] = live.name
    variants.extend(asset_variants)
    cfg.update(reference_labels=labels, live_reference_count=len(paths))
    return match_stable_body(bgr, cfg, variants, threshold,
                             cfg['search_budget_ms'] if budget_ms is None else budget_ms,
                             scale_hint=scale_hint, local=local)


def match_ward_prompt(bgr):
    """Use the existing configured ward prompt before the semantic OCR fallback."""
    from scripts.legacy_references import configured_image
    path = configured_image('General', 'PromptImg', 'public/ward_prompt.png')
    rgba = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if rgba is None:
        return dict(found=0, score=0.)
    if rgba.ndim == 2:
        rgba = cv2.cvtColor(rgba, cv2.COLOR_GRAY2BGRA)
    if rgba.shape[2] == 3:
        rgba = cv2.cvtColor(rgba, cv2.COLOR_BGR2BGRA)
    qgray, qedge = features(bgr)
    best = 0.
    for scale in (.65, .8, 1., 1.2, 1.5, 2.):
        w, h = round(rgba.shape[1]*scale), round(rgba.shape[0]*scale)
        if w > bgr.shape[1] or h > bgr.shape[0] or min(w, h) < 6:
            continue
        t = cv2.resize(rgba, (w, h))
        gray, edge = features(t[:, :, :3])
        mask = np.uint8(t[:, :, 3] > 160)*255
        lum, shape = correlation(qgray, qedge, gray, edge, mask)
        scores = .65*shape+.35*lum
        scores[(shape < .6) | (lum < .5)] = 0
        best = max(best, float(cv2.minMaxLoc(scores)[1]))
    return dict(found=int(best >= .80), score=round(best, 4), reference=str(path))
