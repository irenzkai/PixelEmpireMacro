"""Reuse registration only after current-frame geometry evidence revalidates it."""
import copy
import hashlib
import threading
import numpy as np


class MapGeometryCache:
    def __init__(self):
        self.lock = threading.Lock()
        self.entry = None
        self.identities = {}
        self.icons = {}

    @staticmethod
    def _covered(x, y, size, arrow, occluded):
        ax, ay = arrow['ax'], arrow['ay']
        if x-24 <= ax <= x+size+24 and y-24 <= ay <= y+size+24:
            return True
        return occluded is not None and np.any(occluded[y:y+size, x:x+size])

    def get(self, gray, arrow, occluded, signature):
        with self.lock:
            entry = self.entry
        if entry is None:
            return None, 'cold'
        if entry['signature'] != signature or entry['shape'] != gray.shape:
            self.clear()
            return None, 'viewport/scale/reference changed'
        matched = []
        for x, y, patch in entry['patches']:
            if self._covered(x, y, 16, arrow, occluded):
                continue
            if np.array_equal(gray[y:y+16, x:x+16], patch):
                matched.append((x, y))
        # Distributed exact texture evidence guards against pan/zoom changes;
        # ignored arrow/tooltip patches cannot alone validate old geometry.
        quadrants = {(int(x >= gray.shape[1]/2), int(y >= gray.shape[0]/2)) for x, y in matched}
        if len(matched) < 6 or len(quadrants) < 3:
            self.clear()
            return None, 'pan/zoom/layout texture changed or obscured'
        areas = copy.deepcopy(entry['areas'])
        import cv2
        for area in areas:
            area['contains'] = cv2.pointPolygonTest(area['quad'], (arrow['ax'], arrow['ay']), False) >= 0
        if not any(area['contains'] for area in areas):
            self.clear()
            return None, 'arrow entered an uncached map area'
        if tuple(sorted(area['ws'] for area in areas if area['contains'])) != entry['containing']:
            self.clear()
            return None, 'current-map containment changed'
        return areas, 'validated hit'

    def put(self, gray, arrow, occluded, signature, areas):
        import cv2
        patches = []
        h, w = gray.shape
        for y in np.linspace(12, max(12, h-28), 6).astype(int):
            for x in np.linspace(12, max(12, w-28), 7).astype(int):
                if self._covered(x, y, 16, arrow, occluded):
                    continue
                if not any(cv2.pointPolygonTest(area['quad'], (float(x+8),float(y+8)), True) > 20 for area in areas):
                    continue
                patch = gray[y:y+16, x:x+16]
                if patch.shape == (16, 16) and patch.std() >= 8:
                    patches.append((int(x), int(y), patch.copy()))
        if len(patches) < 8 or not areas:
            return
        with self.lock:
            self.entry = dict(signature=signature, shape=gray.shape, patches=patches,
                              areas=copy.deepcopy(areas),
                              containing=tuple(sorted(a['ws'] for a in areas if a['contains'])))

    def clear(self):
        with self.lock:
            self.entry = None
            self.identities.clear()
            self.icons.clear()

    def icon(self, area, value=None):
        key = (area['ws'], tuple(np.round(area['matrix'], 2).ravel()))
        with self.lock:
            if self.entry is None:
                return None
            if value is not None:
                self.icons[key] = dict(value)
                while len(self.icons) > 4:
                    self.icons.pop(next(iter(self.icons)))
            return self.icons.get(key)

    def identity(self, area, crop, obscured, value=None):
        if obscured or not crop.size:
            return None
        key = (area['ws'], tuple(np.round(area['matrix'], 2).ravel()), crop.shape,
               hashlib.sha256(crop.tobytes()).digest())
        with self.lock:
            if value is not None:
                self.identities[key] = value
                while len(self.identities) > 32:
                    self.identities.pop(next(iter(self.identities)))
            return self.identities.get(key)


GEOMETRY = MapGeometryCache()
