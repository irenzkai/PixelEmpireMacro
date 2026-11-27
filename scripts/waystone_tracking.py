"""Recent detections are search hints only; every returned target is re-evaluated."""
import threading
import time


class WaystoneTracking:
    def __init__(self):
        self.lock = threading.Lock()
        self.recent = {}

    def region(self, key, base, cfg):
        now = time.monotonic()
        with self.lock:
            previous = self.recent.get(key)
            if previous is None:
                return base, None, 'full'
            if (now-previous['capture_tick'])*1000 > cfg['track_max_age_ms'] or (now-previous['full_tick'])*1000 > cfg['track_full_refresh_ms']:
                self.recent.pop(key, None)
                return base, None, 'full'
            pad = cfg['track_padding_bodies']
            xpad, ypad = max(48, round(previous['w']*pad)), max(60, round(previous['h']*pad))
            region = (max(base[0], previous['x']-xpad), max(base[1], previous['y']-ypad),
                      min(base[2], previous['x']+previous['w']+xpad),
                      min(base[3], previous['y']+previous['h']+ypad))
            if region[2]-region[0] < 12 or region[3]-region[1] < 18:
                return base, None, 'full'
            return region, previous['scale'], 'local'

    def observe(self, key, result, scope):
        with self.lock:
            if not result.get('found'):
                self.recent.pop(key, None)
                return
            # Hints may help reacquisition after the steering cache expires, but
            # the hint is never returned as detection evidence to a caller.
            previous = self.recent.get(key)
            full_tick = previous['full_tick'] if scope == 'local' and previous else result['capture_tick']
            self.recent[key] = {name: result[name] for name in ('x','y','w','h','scale','capture_tick')}
            self.recent[key]['full_tick'] = full_tick
            while len(self.recent) > 4:
                self.recent.pop(next(iter(self.recent)))


TRACKING = WaystoneTracking()
