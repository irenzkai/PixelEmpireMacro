"""Conservative stable-body evidence; no capture, input, or activation classes."""
from functools import lru_cache
import time
import cv2
import numpy as np


def body_features(bgr):
    # Fixed pixel kernels on both query and scaled template. An 8x8 CLAHE grid
    # on a 12x25 template does not mean the same thing as on a large screenshot.
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float32)/255.
    gray = cv2.GaussianBlur(gray, (0, 0), .6)
    mean = cv2.GaussianBlur(gray, (0, 0), 3.)
    centered = gray-mean
    deviation = np.sqrt(cv2.GaussianBlur(centered*centered, (0, 0), 3.)+.0025)
    local = np.clip(centered/deviation, -3., 3.)
    gx = np.abs(cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3))
    gy = np.abs(cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3))
    contrast = cv2.GaussianBlur(gx+gy, (0, 0), 3.)+.04
    gradients = np.dstack((np.clip(gx/contrast, 0., 3.), np.clip(gy/contrast, 0., 3.)))
    return np.ascontiguousarray(local), np.ascontiguousarray(gradients)


@lru_cache(maxsize=192)
def prepared(raw, bh, bw, w, h):
    rgba = np.frombuffer(raw, np.uint8).reshape(bh, bw, 4)
    alpha = rgba[:, :, 3].astype(np.float32)/255.
    # Premultiply before resizing: invisible RGB must not produce dark fringes.
    resized_alpha = cv2.resize(alpha, (w, h), interpolation=cv2.INTER_LINEAR)
    rgb = cv2.resize(rgba[:, :, :3].astype(np.float32)*alpha[:, :, None], (w, h))
    rgb = np.uint8(np.clip(rgb/np.maximum(resized_alpha[:, :, None], .001), 0, 255))
    opaque = np.uint8(resized_alpha > .85)*255
    if cv2.countNonZero(opaque) < 20:
        return None
    rgb = cv2.inpaint(rgb, np.uint8(opaque == 0)*255, 2, cv2.INPAINT_TELEA)
    # Keep transparent feather/glow boundaries out of verification gradients.
    mask = cv2.erode(opaque, np.ones((3, 3), np.uint8), borderType=cv2.BORDER_CONSTANT, borderValue=0) > 0
    gray, edge = body_features(rgb)
    return gray, edge, mask


def evidence(qgray, qedge, gray, edge, mask):
    if np.count_nonzero(mask) < 8:
        return 0., 0., 0.
    a, b = qgray[mask], gray[mask]
    a, b = a-a.mean(), b-b.mean()
    luminance = max(0., float(np.dot(a, b)/(np.linalg.norm(a)*np.linalg.norm(b)+1.e-6)))
    a, b = qedge[mask].ravel(), edge[mask].ravel()
    shape = max(0., min(1., float(np.dot(a, b)/(np.linalg.norm(a)*np.linalg.norm(b)+1.e-6))))
    return .7*shape+.3*luminance, shape, luminance


def same_object(a, b):
    overlap_w = max(0, min(a['x']+a['w'], b['x']+b['w'])-max(a['x'], b['x']))
    overlap_h = max(0, min(a['y']+a['h'], b['y']+b['h'])-max(a['y'], b['y']))
    close_x = abs(a['x']+a['w']/2-b['x']-b['w']/2) <= .6*max(a['w'],b['w'])
    close_y = abs(a['y']+a['h']/2-b['y']-b['h']/2) <= .6*max(a['h'],b['h'])
    comparable = max(a['h'],b['h']) <= 2.5*min(a['h'],b['h'])
    small_area = min(a['w']*a['h'],b['w']*b['h'])
    concentric = (abs(a['x']+a['w']/2-b['x']-b['w']/2) <= .35*min(a['w'],b['w']) and
                  abs(a['y']+a['h']/2-b['y']-b['h']/2) <= .35*min(a['h'],b['h']))
    return (close_x and close_y and comparable and overlap_w*overlap_h > .3*small_area) or (concentric and overlap_w*overlap_h > .8*small_area)


def physical_objects(candidates):
    # Highest-quality representative anchors each group; avoid a loose overlap
    # chain merging separate nearby objects. Frames/scales share one object vote.
    groups = []
    for candidate in sorted(candidates, key=lambda row: row['score'], reverse=True):
        group = next((g for g in groups if same_object(g[0], candidate)), None)
        if group is None:
            groups.append([candidate])
        else:
            group.append(candidate)
    return groups


def match_stable_body(bgr, cfg, variants, threshold, budget_ms, scale_hint=None, local=False):
    started = time.perf_counter()
    ratio = min(1., int(cfg['max_query_width'])/bgr.shape[1])
    query = cv2.resize(bgr, None, fx=ratio, fy=ratio, interpolation=cv2.INTER_AREA) if ratio < 1. else bgr
    qgray, qedge = body_features(query)
    candidates = []
    completed = True
    target_scale = scale_hint if scale_hint is not None else cfg['initial_scale']
    scales = sorted(cfg['scales'], key=lambda value: abs(np.log(value/target_scale)))
    if local:
        scales = scales[:3]
    maps_evaluated = 0
    for scale in scales:
        for index, body in variants:
            if (time.perf_counter()-started)*1000 > budget_ms:
                completed = False
                break
            w, h = round(body.shape[1]*scale*ratio), round(body.shape[0]*scale*ratio)
            if w < 8 or h < 15 or w > query.shape[1] or h > query.shape[0]:
                continue
            template = prepared(body.tobytes(), *body.shape[:2], w, h)
            if template is None:
                continue
            gray, edge, mask = template
            # Fast unmasked coarse correlation. Alpha-aware verification is local,
            # avoiding masked FFT maps and dozens of tiny matchTemplate calls.
            lum = cv2.matchTemplate(qgray, gray, cv2.TM_CCOEFF_NORMED)
            shape = cv2.matchTemplate(qedge, edge, cv2.TM_CCORR_NORMED)
            coarse = np.nan_to_num(.7*shape+.3*lum, nan=0., posinf=0., neginf=0.)
            maps_evaluated += 1
            for _ in range(4):
                _, peak, _, (x, y) = cv2.minMaxLoc(coarse)
                if peak < .25:
                    break
                coarse[max(0,y-h//3):y+h//3+1, max(0,x-w//2):x+w//2+1] = 0
                patch_gray, patch_edge = qgray[y:y+h,x:x+w], qedge[y:y+h,x:x+w]
                full, shape_score, luminance = evidence(patch_gray, patch_edge, gray, edge, mask)
                bands = []
                for start, end in zip((0,h//3,2*h//3), (h//3,2*h//3,h)):
                    score, _, _ = evidence(patch_gray[start:end], patch_edge[start:end],
                                          gray[start:end], edge[start:end], mask[start:end])
                    bands.append(score)
                # Dropping an occluded/weak band must never improve candidate rank.
                rank = min(full, sum(bands)/3+.03)
                candidates.append(dict(score=rank, full_body_score=full, edge_score=shape_score,
                    luminance_score=luminance, weakest_band=min(bands), frame_index=index,
                    candidate_complete=1,
                    scale=float(scale), x=round(x/ratio), y=round(y/ratio),
                    w=round(w/ratio), h=round(h/ratio)))
        if not completed:
            break
    groups = physical_objects(candidates)
    result = dict(ok=1, found=0, accepted=0, candidate=0, status='uncertain', score=0.,
                  threshold=threshold, search_complete=int(completed),
                  maps_evaluated=maps_evaluated, physical_object_count=len(groups),
                  live_reference_count=cfg['live_reference_count'],
                  reference_count=len(variants),
                  frame_count=int(cfg['columns'])*int(cfg['rows']), reference=str(cfg['sheet_path']),
                  reason='No usable stable-body candidate',
                  method='Shared local contrast + gradient orientation; full-body and all-band verification')
    if groups:
        best = groups[0][0]
        runner = groups[1][0]['score'] if len(groups) > 1 else 0.
        margin = best['score']-runner
        result.update(best, candidate=1, runner_up_score=runner, candidate_margin=margin,
                      grouped_hypotheses=len(groups[0]),
                      reference_name=cfg['reference_labels'][best['frame_index']])
        result['reference_index'] = best['frame_index']
        if best['frame_index'] >= result['frame_count']:
            result['frame_index'] = -1
        if not best.get('candidate_complete') or not maps_evaluated:
            reason = 'Candidate verification is incomplete'
        elif best['score'] < threshold:
            reason = 'Best candidate below acceptance threshold'
        elif best['edge_score'] < cfg['min_edge_score'] or best['luminance_score'] < cfg['min_luminance_score'] or best['weakest_band'] < cfg['min_band_score']:
            reason = 'Weak/obstructed full-body evidence'
        elif margin < cfg['min_candidate_margin']:
            reason = 'Ambiguous spatially distinct candidates'
        else:
            reason = 'Fully verified object accepted' + ('; optional search budget reached' if not completed else '')
            result.update(found=1, accepted=1, status='accepted')
        result['reason'] = reason
    elif not completed:
        result['reason'] = 'Search budget reached; no accepted detection'
    for key, value in list(result.items()):
        if isinstance(value, float):
            result[key] = round(value, 6)
    return result
