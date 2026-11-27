"""Local, hash-based review storage. Only exported copies may be changed."""
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import time
import uuid
from contextlib import contextmanager
from PIL import Image

EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.tif', '.tiff'}


class ReviewStore:
    def __init__(self, root, db):
        self.root = Path(root).resolve()
        self.db = Path(db)
        self.root.mkdir(parents=True, exist_ok=True)
        self.db.parent.mkdir(parents=True, exist_ok=True)
        self.observed = {}
        for folder in ('review_incoming', 'reviewed'):
            (self.root/folder).mkdir(exist_ok=True)
        with self.connect() as conn:
            conn.executescript('''
                CREATE TABLE IF NOT EXISTS image_reviews (
                    sha256 TEXT PRIMARY KEY, status TEXT NOT NULL DEFAULT 'pending',
                    original_filename TEXT NOT NULL, metadata_json TEXT NOT NULL DEFAULT '{}',
                    first_seen REAL NOT NULL, updated_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS image_review_files (
                    path TEXT PRIMARY KEY, sha256 TEXT NOT NULL, size INTEGER NOT NULL,
                    mtime_ns INTEGER NOT NULL);
                CREATE INDEX IF NOT EXISTS image_review_files_hash ON image_review_files(sha256);
                CREATE INDEX IF NOT EXISTS image_reviews_queue ON image_reviews(status,first_seen,sha256);
                CREATE TABLE IF NOT EXISTS image_review_manifest_dirty (sha256 TEXT PRIMARY KEY, version INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS asset_user_labels (sha256 TEXT PRIMARY KEY,label TEXT NOT NULL,updated_at REAL NOT NULL);
            ''')
            for row in conn.execute("SELECT r.sha256,MIN(f.path),r.updated_at FROM image_reviews r JOIN image_review_files f USING(sha256) WHERE r.status='renamed' AND NOT EXISTS(SELECT 1 FROM asset_user_labels l WHERE l.sha256=r.sha256) GROUP BY r.sha256").fetchall():
                conn.execute('INSERT OR IGNORE INTO asset_user_labels VALUES (?,?,?)',(row[0],Path(row[1]).stem,row[2]))
            if 'version' not in [row[1] for row in conn.execute('PRAGMA table_info(image_review_manifest_dirty)')]:
                conn.execute('ALTER TABLE image_review_manifest_dirty ADD COLUMN version INTEGER NOT NULL DEFAULT 0')

    @contextmanager
    def connect(self):
        conn = sqlite3.connect(self.db, timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            with conn:
                yield conn
        finally:
            conn.close()

    def safe_path(self, relative):
        path = (self.root/relative).resolve()
        if not path.is_relative_to(self.root) or path == self.root:
            raise ValueError('Path must remain inside exported assets')
        if any(part.startswith('.review_') for part in path.relative_to(self.root).parts):
            raise ValueError('Internal review files cannot be reviewed')
        return path

    def read_manifest(self, apply_pending=True):
        path = self.root/'manifest.json'
        manifest = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'assets': []}
        if apply_pending:
            with self.connect() as conn:
                dirty = [r[0] for r in conn.execute('SELECT sha256 FROM image_review_manifest_dirty')]
            if dirty:
                entries = {r['sha256']:r for r in manifest.get('assets',[])}
                self._merge_reviews(entries,dirty)
                manifest['assets'] = sorted(entries.values(),key=lambda r:r['sha256'])
        return manifest

    def scan(self, settle_seconds=2, cancel_event=None):
        """Two observations plus a stable stat/valid image guard in-progress writes."""
        manifest = self.read_manifest()
        metadata = {r.get('sha256'):r for r in manifest.get('assets', [])}
        queued = 0
        batch = 0
        seen = set()
        with self.connect() as conn:
            known = {r['path']:r for r in conn.execute('SELECT * FROM image_review_files')}
            for folder, dirs, filenames in os.walk(self.root, followlinks=False):
                dirs[:] = [d for d in dirs if not d.startswith('.review_') and not (Path(folder)/d).is_symlink()]
                for name in filenames:
                    if cancel_event is not None and cancel_event.is_set():
                        return queued
                    path = Path(folder)/name
                    if path.suffix.lower() not in EXTENSIONS or name.startswith('contact_sheet_') or path.is_symlink():
                        continue
                    relative = path.relative_to(self.root).as_posix()
                    try:
                        stat = path.stat()
                        stamp = (stat.st_size, stat.st_mtime_ns)
                        seen.add(relative)
                        old = known.get(relative)
                        if old and (old['size'],old['mtime_ns']) == stamp:
                            continue
                        previous = self.observed.get(relative)
                        self.observed[relative] = stamp
                        if previous != stamp or time.time()-stat.st_mtime < settle_seconds:
                            continue
                        data = path.read_bytes()
                        with Image.open(path) as image:
                            details = {'dimensions':list(image.size), 'format':image.format}
                            image.verify()
                        after = path.stat()
                        if (after.st_size,after.st_mtime_ns) != stamp:
                            continue
                        digest = hashlib.sha256(data).hexdigest()
                        info = dict(metadata.get(digest, {}))
                        info.update(details)
                        info.setdefault('attribution','unconfirmed')
                        cursor = conn.execute('INSERT OR IGNORE INTO image_reviews '
                            '(sha256,status,original_filename,metadata_json,first_seen,updated_at) VALUES (?,?,?,?,?,?)',
                            (digest, {'renamed':'reviewed','reviewed':'reviewed','deleted':'deleted'}.get(info.get('review_status'),'pending'),info.get('original_filename',name),json.dumps(info),time.time(),time.time()))
                        queued += cursor.rowcount
                        final_stat=path.stat()
                        if (final_stat.st_size,final_stat.st_mtime_ns)!=stamp:
                            continue
                        conn.execute('INSERT OR REPLACE INTO image_review_files VALUES (?,?,?,?)',
                                     (relative,digest,*stamp))
                        self.mark_dirty(conn,digest)
                        batch += 1
                        if batch >= 50:
                            conn.commit()
                            batch = 0
                    except (OSError, ValueError, Image.DecompressionBombError):
                        # Retry on the next scan; do not queue partial/unsupported files.
                        continue
            # Absent exports are historical records, not evidence of deletion.
            # Keep paths and tombstones; the importer can restore missing content.
        return queued

    @staticmethod
    def mark_dirty(conn,digest):
        conn.execute('INSERT INTO image_review_manifest_dirty (sha256,version) VALUES (?,1) '
                     'ON CONFLICT(sha256) DO UPDATE SET version=version+1',(digest,))

    @contextmanager
    def compensate(self,old,target):
        try:
            yield
        except Exception:
            if not old.exists():
                if target is not None and target.exists():
                    target.rename(old)
            raise

    def pending(self, reviewed=False):
        with self.connect() as conn:
            rows=conn.execute("SELECT r.sha256,r.status,r.original_filename,f.path FROM image_reviews r "
                "JOIN image_review_files f USING(sha256) WHERE r.status=? ORDER BY r.first_seen,r.sha256,f.path",
                ('reviewed' if reviewed else 'pending',)).fetchall()
        result=[];seen=set()
        for row in rows:
            if row['sha256'] not in seen and self.safe_path(row['path']).is_file():
                result.append(dict(row));seen.add(row['sha256'])
        return result

    def act(self, digest, relative, name=None, allow_reviewed=False, review_metadata=None, label=None):
        old = self.safe_path(relative)
        stat = old.stat()
        with self.connect() as conn:
            indexed = conn.execute('SELECT * FROM image_review_files WHERE path=? AND sha256=?',
                                   (relative,digest)).fetchone()
        if not indexed:
            raise ValueError('Stale selection; refresh before reviewing')
        if ((stat.st_size,stat.st_mtime_ns)!=(indexed['size'],indexed['mtime_ns'])
            and hashlib.sha256(old.read_bytes()).hexdigest()!=digest):
            raise ValueError('Image changed; refresh before reviewing')
        kind = 'rename' if name is not None else 'delete'
        if kind=='delete':
            from scripts.reference_setup_store import active_image_uses
            uses=active_image_uses(digest,self.db.resolve().parent)
            if uses:
                raise ValueError('Delete blocked. Replace or clear these associations in Reference Setup > References first: '+', '.join(r['name'] for r in uses))
        target = None
        if kind == 'rename':
            name = name.strip()
            if (not name or len(name)>180 or re.search(r'[<>:"/\\|?*\x00-\x1f]',name)
                or name.endswith(('.', ' ')) or name in ('.','..')
                or name.split('.')[0].upper() in {'CON','PRN','AUX','NUL',*[f'COM{i}' for i in range(1,10)],*[f'LPT{i}' for i in range(1,10)]}):
                raise ValueError('Choose a valid Windows filename (no paths or reserved names)')
            if Path(name).suffix.lower() != old.suffix.lower():
                if Path(name).suffix:
                    raise ValueError('Keep the original image extension')
                name += old.suffix
            target = self.root/'reviewed'/name
            if target == old and not allow_reviewed:
                raise ValueError('Enter a different filename; this image has not been marked reviewed')
            if target != old and target.exists():
                raise ValueError('Filename already exists; nothing was overwritten')
        with self.compensate(old,target), self.connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            status = conn.execute('SELECT status FROM image_reviews WHERE sha256=?',(digest,)).fetchone()
            if not status or (status[0] != 'pending' and not (allow_reviewed and status[0] in ('reviewed','renamed','skipped'))):
                raise ValueError('Image already reviewed; refresh the queue')
            previous_metadata=conn.execute('SELECT metadata_json FROM image_reviews WHERE sha256=?',(digest,)).fetchone()[0]
            if kind == 'rename':
                if target != old:
                    old.rename(target)  # Windows refuses an existing destination.
                if not target.is_file() or (target!=old and old.exists()):
                    raise OSError('Rename did not produce the requested filename')
                moved=target.stat()
                if (moved.st_size,moved.st_mtime_ns)!=(stat.st_size,stat.st_mtime_ns):
                    raise ValueError('Image changed during rename; Refresh and retry')
                updated=conn.execute('UPDATE image_review_files SET path=?,size=?,mtime_ns=? WHERE path=? AND sha256=?',
                             (target.relative_to(self.root).as_posix(),moved.st_size,moved.st_mtime_ns,relative,digest))
                if updated.rowcount!=1:
                    raise ValueError('Index changed; rename rolled back. Refresh and retry')
                conn.execute('INSERT OR REPLACE INTO asset_user_labels VALUES (?,?,?)',(digest,target.stem if label is None else label,time.time()))
                if review_metadata is not None:
                    meta=json.loads(previous_metadata);meta.update(review_metadata)
                    conn.execute('UPDATE image_reviews SET metadata_json=? WHERE sha256=?',(json.dumps(meta),digest))
            else:
                # Delete every exported copy for this content hash; keep a tombstone
                # so a running collector cannot silently re-export deleted content.
                try:
                    for row in conn.execute('SELECT path FROM image_review_files WHERE sha256=?',(digest,)).fetchall():
                        path=self.safe_path(row[0])
                        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
                            raise ValueError('An exported copy changed; Refresh before deleting')
                        path.unlink(missing_ok=True)
                        conn.execute('DELETE FROM image_review_files WHERE path=?',(row[0],))
                        self.mark_dirty(conn,digest)
                except Exception:
                    # Preserve records of already removed files even if another copy fails.
                    conn.commit()
                    raise
                conn.execute('DELETE FROM asset_user_labels WHERE sha256=?',(digest,))
            conn.execute('UPDATE image_reviews SET status=?,updated_at=? WHERE sha256=?',
                         ('reviewed' if target else 'deleted',time.time(),digest))
            self.mark_dirty(conn,digest)
        return {'sha256':digest,'kind':kind,'path':target.relative_to(self.root).as_posix() if target else None}

    def migrate(self):
        """Move retained exports without overwriting; each move and index update agree.

        Safe to repeat after interruption. Tombstones and absent files remain records.
        """
        self.scan(settle_seconds=0)
        self.scan(settle_seconds=0)
        with self.connect() as conn:
            rows=conn.execute("SELECT f.*,r.status FROM image_review_files f JOIN image_reviews r USING(sha256)").fetchall()
        for row in rows:
            if row['status']=='deleted':
                continue
            old=self.safe_path(row['path'])
            if not old.is_file():
                continue
            folder='reviewed' if row['status'] in ('renamed','reviewed') else 'review_incoming'
            if old.parent==self.root/folder:
                continue
            target=self.root/folder/old.name
            number=1
            while target.exists():
                target=self.root/folder/(old.stem+'_'+str(number)+old.suffix)
                number+=1
            with self.compensate(old,target), self.connect() as conn:
                conn.execute('BEGIN IMMEDIATE')
                current=conn.execute('SELECT sha256 FROM image_review_files WHERE path=?',(row['path'],)).fetchone()
                if not current or current[0]!=row['sha256']:
                    continue
                old.rename(target)
                stat=target.stat()
                conn.execute('UPDATE image_review_files SET path=?,size=?,mtime_ns=? WHERE path=?',
                    (target.relative_to(self.root).as_posix(),stat.st_size,stat.st_mtime_ns,row['path']))
                self.mark_dirty(conn,row['sha256'])
        with self.connect() as conn:
            conn.execute("UPDATE image_reviews SET status='reviewed' WHERE status='renamed'")
            conn.execute("UPDATE image_reviews SET status='pending' WHERE status='skipped'")
        self.sync_manifest()

    def skip(self,digest,relative):
        with self.connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            row=conn.execute('SELECT status FROM image_reviews WHERE sha256=?',(digest,)).fetchone()
            if not row or row[0]!='pending':raise ValueError('Selection is no longer pending')
            conn.execute("UPDATE image_reviews SET status='skipped',updated_at=? WHERE sha256=?",(time.time(),digest))
            self.mark_dirty(conn,digest)
        return {'sha256':digest,'kind':'skip','path':relative}

    def sync_manifest(self):
        # Serialize checkpoints across windows/exporter processes. Never on Tk.
        import msvcrt
        with (self.root/'.review_manifest.lock').open('a+b') as lock:
            if not lock.seek(0,2):
                lock.write(b'0');lock.flush()
            locked=False
            try:
                for _ in range(100):
                    lock.seek(0)
                    try:
                        msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
                        locked=True;break
                    except OSError:time.sleep(.1)
                if not locked:raise OSError('Manifest checkpoint busy; retry later')
                self._checkpoint_manifest()
            finally:
                if locked:
                    lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)

    def _checkpoint_manifest(self):
        with self.connect() as conn:
            versions=[tuple(row) for row in conn.execute('SELECT sha256,version FROM image_review_manifest_dirty')]
        manifest = self.read_manifest(apply_pending=False)
        entries = {r.get('sha256'):r for r in manifest.get('assets',[])}
        self._merge_reviews(entries)
        manifest['assets'] = sorted(entries.values(),key=lambda r:r['sha256'])
        manifest['unique_images'] = len(entries)
        with self.connect() as conn:
            if conn.execute("SELECT 1 FROM sqlite_master WHERE name='image_collection_sessions'").fetchone():
                session=conn.execute('SELECT id,started_at,status FROM image_collection_sessions WHERE active=1').fetchone()
                if session:manifest['collection_session']=dict(session)
        manifest['review_storage'] = 'agent_memory.db:image_reviews,image_review_files'
        manifest['pending_changes'] = 'SQLite image_review_manifest_dirty; use ReviewStore.read_manifest() for the current view'
        temporary = self.root/('.review_manifest_'+uuid.uuid4().hex+'.tmp')
        temporary.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        temporary.replace(self.root/'manifest.json')
        with self.connect() as conn:
            conn.executemany('DELETE FROM image_review_manifest_dirty WHERE sha256=? AND version=?',versions)

    def _merge_reviews(self,entries,digests=None):
        with self.connect() as conn:
            paths = {}
            for row in conn.execute('SELECT sha256,path FROM image_review_files ORDER BY path'):
                paths.setdefault(row['sha256'],[]).append(row['path'])
            rows = (conn.execute('SELECT * FROM image_reviews').fetchall() if digests is None else
                    [conn.execute('SELECT * FROM image_reviews WHERE sha256=?',(d,)).fetchone() for d in digests])
            for row in rows:
                if row is None:
                    continue
                stored_metadata=json.loads(row['metadata_json'])
                rec = dict(stored_metadata)
                incoming = entries.get(row['sha256'],{})
                previous_sources = {key:rec.get(key) for key in ('source_path','sources','cache_entries')}
                rec.update(incoming)
                label=conn.execute('SELECT label FROM asset_user_labels WHERE sha256=?',(row['sha256'],)).fetchone()
                if label:rec['label']=label[0]
                else:rec.pop('label',None)
                for key,value in previous_sources.items():
                    if value and not rec.get(key):
                        rec[key] = value
                files = paths.get(row['sha256'],[])
                rec.update(sha256=row['sha256'],review_status=row['status'],
                    original_filename=row['original_filename'],exported_files=files,
                    filename=files[0] if files else None)
                entries[row['sha256']] = rec
