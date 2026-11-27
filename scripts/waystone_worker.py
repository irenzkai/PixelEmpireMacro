"""One bounded background search; polling never runs vision on the HTTP thread."""
from concurrent.futures import ThreadPoolExecutor
import threading
import time


class WaystoneWorker:
    def __init__(self):
        self.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix='waystone-vision')
        self.lock = threading.Lock()
        self.running = False
        self.key = None
        self.result = None
        self.last_launch = 0.
        self.accepted_key = None
        self.accepted = None

    def poll(self, key, detect, max_age_ms, tracking=False):
        now = time.monotonic()
        with self.lock:
            cached = self.result if self.key == key else None
            if not self.running and now-self.last_launch >= .12:
                self.running = True
                self.last_launch = now
                self.executor.submit(self._run, key, detect)
            age = (now-cached['capture_tick'])*1000 if cached else None
            if cached is not None and age <= max_age_ms:
                result = dict(cached)
                result.update(age_ms=round(age), pending=int(self.running),
                              result_id=str(cached['capture_tick']), completed=1)
                return self._tracking(result, key, now) if tracking else result
            accepted = dict(self.accepted) if tracking and self.accepted_key == key and self.accepted else None
        # Never expose stale coordinates as an accepted target.
        result = dict(ok=1, found=0, accepted=0, candidate=0, pending=1, status='uncertain',
                    score=0., reason='Vision pending' if cached is None else 'Cached evidence expired',
                    age_ms=-1 if age is None else round(age))
        # Diagnostic/reacquisition hints only: never expose expired coordinates.
        result.update(completed=int(cached is not None),
                      result_id=str(cached['capture_tick']) if cached else '',
                      snapshot_ok=cached.get('ok', 0) if cached else 0,
                      snapshot_found=int(bool(cached and cached.get('found'))),
                      snapshot_reason=cached.get('reason', '') if cached else '',
                      compute_ms=cached.get('compute_ms', -1) if cached else -1)
        return self._attach_tracking(result, accepted, now) if tracking else result

    def _tracking(self, result, key, now):
        # Called under lock. Retained sightings are separate from fresh `found`.
        accepted = self.accepted if self.accepted_key == key else None
        return self._attach_tracking(result, accepted, now)

    @staticmethod
    def _attach_tracking(result, accepted, now):
        age = (now-accepted['capture_tick'])*1000 if accepted else -1
        result.update(track_found=0, track_age_ms=round(age), track_id='')
        if accepted and 0 <= age < 1500:
            result.update(track_found=1, track_id=str(accepted['capture_tick']),
                          track_score=accepted.get('score', 0))
            for name in ('x', 'y', 'w', 'h'):
                result['track_'+name] = accepted[name]
        return result

    def _run(self, key, detect):
        try:
            result = detect()
        except Exception as exc:
            result = dict(ok=0, found=0, accepted=0, candidate=0, status='uncertain',
                          reason=str(exc), capture_tick=time.monotonic())
        with self.lock:
            self.key, self.result = key, result
            if result.get('found'):
                self.accepted_key, self.accepted = key, dict(result)
            self.running = False


WORKER = WaystoneWorker()
