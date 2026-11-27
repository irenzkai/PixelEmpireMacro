"""Prepare exact UI templates from retained references; no capture or game input."""
from pathlib import Path
import configparser
import json
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.task-output/fast_map_assets'


def main():
    from scripts.legacy_references import configured_image
    from scripts.world_map_icon import aligned_icon
    OUT.mkdir(parents=True, exist_ok=True)
    ini = configparser.ConfigParser(interpolation=None)
    ini.optionxform = str
    entries = []

    def add(key, path, role='', **fields):
        entries.append(dict(key=key, path=str(path.resolve()), role=role, **fields))

    def save(key, image, role='', **fields):
        path = OUT / (key+'.png')
        if image is None or not cv2.imwrite(str(path), image):
            raise ValueError('Cannot prepare '+key)
        add(key, path, role, **fields)

    header = configured_image('WorldMap', 'OpenImg', 'public/map_open.png')
    arrow = configured_image('WorldMap', 'ArrowImg', 'public/map_arrow.png')
    icon = configured_image('WorldMap', 'WaystoneImg', 'public/map_waystone.png')
    for key, path in [('map_open_original', header), ('map_arrow_original', arrow),
                      ('map_waystone_original', icon)]:
        add(key, path)
    cfg = json.loads((ROOT/'config/world_map_detector.json').read_text(encoding='utf-8'))
    head = cv2.imread(str(header), cv2.IMREAD_UNCHANGED)
    for i, scale in enumerate(cfg['header_scales']):
        tile = head[:, :145]
        save('map_header_'+str(i), cv2.resize(tile, None, fx=scale, fy=scale), 'header')

    # Real arrow bodies plus their actual black outline; crop backgrounds ignored.
    for i, path in enumerate(sorted((ROOT/'public/world_map_arrow_live').glob('*.png'))):
        image = cv2.imread(str(path))
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        red = (((hsv[:, :, 0] <= 12) | (hsv[:, :, 0] >= 168))
               & (hsv[:, :, 1] >= 150) & (hsv[:, :, 2] >= 210))
        colors, counts = np.unique(image[red], axis=0, return_counts=True)
        fill = colors[counts.argmax()]
        body = np.uint8(red & (np.max(abs(image.astype(np.int16)-fill), axis=2) <= 12))*255
        n, labels, stats, centers = cv2.connectedComponentsWithStats(body)
        idx = 1+int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        x, y, w, h, _ = stats[idx]
        core = np.uint8(labels == idx)*255
        outline = cv2.dilate(core, np.ones((5, 5), np.uint8))
        opaque = (core > 0) | ((outline > 0) & (image.max(axis=2) < 60))
        x0, y0 = max(0, x-2), max(0, y-2)
        x1, y1 = min(image.shape[1], x+w+2), min(image.shape[0], y+h+2)
        rgba = np.dstack((image, np.uint8(opaque)*255))[y0:y1, x0:x1]
        save('map_arrow_'+str(i), rgba, 'arrow',
             cx=float(centers[idx, 0])-x0, cy=float(centers[idx, 1])-y0)

    for i, path in enumerate(sorted((ROOT/'public/world_map_waystone_live').glob('*.png'))):
        body = aligned_icon(str(path), path.stat().st_mtime_ns)
        if body is None:
            continue
        for j, scale in enumerate(cfg['waystone_scales']):
            w, h = round(body.shape[1]*scale), round(body.shape[0]*scale)
            if w < 8 or h < 15:
                continue
            rgb = cv2.resize(body[:, :, :3], (w, h), interpolation=cv2.INTER_LINEAR)
            alpha = cv2.resize(body[:, :, 3], (w, h), interpolation=cv2.INTER_NEAREST)
            save(f'map_waystone_{i}_{j}', np.dstack((rgb, alpha)), 'waystone', cx=w/2, cy=h/2)

    ini['meta'] = dict(images=str(len(entries)), areas='0')
    for i, row in enumerate(entries, 1):
        ini['image_'+str(i)] = {k:str(v) for k, v in row.items()}
    with (OUT/'manifest.ini').open('w', encoding='utf-16') as stream:
        ini.write(stream)
    print(f'Prepared {len(entries)} exact map UI templates; no capture or registration.')


if __name__ == '__main__':
    import sys
    sys.path.insert(0, str(ROOT))
    main()
