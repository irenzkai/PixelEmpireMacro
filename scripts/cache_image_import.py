"""One-shot local rbxcache import. Retains collection provenance and tombstones."""
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import time
import uuid
from contextlib import closing
from PIL import Image
from image_review_store import ReviewStore

ROOT=Path(__file__).resolve().parent.parent
IMAGE_KINDS={'png','webp','jpeg','jpg','gif','ktx2'}
NO_CONSOLE=getattr(subprocess,'CREATE_NO_WINDOW',0)
TABLES=('image_reviews','image_review_files','image_review_manifest_dirty')


class CacheImport:
    def __init__(self,root=ROOT,assets=None,db=None):
        self.root=Path(root).resolve()
        self.assets=Path(assets) if assets else self.root/'public/cache_assets'
        self.store=ReviewStore(self.assets,db or self.root/'agent_memory.db')
        self.tool=self.root/'.tools/rbxcache/rbxcache.exe'
        self.cache=Path(os.environ['LOCALAPPDATA'])/'Roblox'
        with self.store.connect() as conn:
            have_content=conn.execute("SELECT 1 FROM sqlite_master WHERE name='image_collection_content'").fetchone()
            conn.executescript('''
                CREATE TABLE IF NOT EXISTS image_collection_sessions (
                    id TEXT PRIMARY KEY,started_at REAL NOT NULL,active INTEGER NOT NULL,
                    status TEXT NOT NULL,stop_requested INTEGER NOT NULL DEFAULT 0,
                    pid INTEGER,heartbeat REAL NOT NULL DEFAULT 0,error TEXT NOT NULL DEFAULT '');
                CREATE TABLE IF NOT EXISTS image_collection_entries (
                    session_id TEXT NOT NULL,entry_id TEXT NOT NULL,kind TEXT NOT NULL,
                    stamp TEXT NOT NULL,sha256 TEXT,state TEXT NOT NULL,error TEXT NOT NULL DEFAULT '',
                    PRIMARY KEY(session_id,entry_id));
                CREATE TABLE IF NOT EXISTS image_collection_content (
                    session_id TEXT NOT NULL,sha256 TEXT NOT NULL,first_seen REAL NOT NULL,
                    PRIMARY KEY(session_id,sha256));
            ''')
            if not have_content:
                conn.execute("INSERT OR IGNORE INTO image_collection_content SELECT session_id,sha256,? FROM image_collection_entries WHERE state='done'",(time.time(),))

    def session(self):
        with self.store.connect() as conn:
            row=conn.execute('SELECT * FROM image_collection_sessions WHERE active=1 ORDER BY started_at DESC LIMIT 1').fetchone()
            result=dict(row) if row else {'id':None,'status':'not started','stop_requested':0,'heartbeat':0}
            result['count']=conn.execute("SELECT count(*) FROM image_collection_content c JOIN image_reviews r USING(sha256) WHERE c.session_id=? AND r.status!='deleted' AND EXISTS(SELECT 1 FROM image_review_files f WHERE f.sha256=c.sha256)",(result['id'],)).fetchone()[0]
            if result['status'] in ('running','starting','armed') and time.time()-result['heartbeat']>15:
                result['status']='interrupted — Start to resume'
            return result

    def new_session(self):
        """Call only after workers stop. Files are reset separately with user authority."""
        sid='collection_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
        with self.store.connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            conn.execute("UPDATE image_collection_sessions SET active=0,status='archived',stop_requested=1 WHERE active=1")
            conn.execute('INSERT INTO image_collection_sessions (id,started_at,active,status) VALUES (?,?,1,?)',
                         (sid,time.time(),'stopped'))
        return sid

    def stop(self):
        with self.store.connect() as conn:
            conn.execute("UPDATE image_collection_sessions SET stop_requested=1,status=CASE WHEN status IN ('running','starting','armed','stopping') AND heartbeat>? THEN 'stopping' ELSE 'stopped' END WHERE active=1",(time.time()-15,))

    def update(self,sid,status,error=None):
        with self.store.connect() as conn:
            conn.execute('UPDATE image_collection_sessions SET status=?,error=COALESCE(?,error),heartbeat=? WHERE id=?',
                         (status,error[:300] if error is not None else None,time.time(),sid))

    def stopped(self,sid):
        with self.store.connect() as conn:
            row=conn.execute('SELECT active,stop_requested FROM image_collection_sessions WHERE id=?',(sid,)).fetchone()
        return not row or not row['active'] or row['stop_requested']

    def stamp(self,entry):
        path=self.cache/'rbx-storage'/entry[:2]/entry
        try:
            stat=path.stat()
            return f'{stat.st_size}:{stat.st_mtime_ns}'
        except OSError:
            with closing(sqlite3.connect(self.cache.joinpath('rbx-storage.db').as_uri()+'?mode=ro',uri=True,timeout=2)) as conn:
                row=conn.execute('SELECT size,content FROM files WHERE id=? AND category=10',(bytes.fromhex(entry),)).fetchone()
                if not row or row[1] is None:raise OSError('Asset blob is not ready')
                return str(row[0])+':'+hashlib.sha256(row[1]).hexdigest()

    def already_done(self,sid,entry,stamp):
        with self.store.connect() as conn:
            row=conn.execute("SELECT * FROM image_collection_entries WHERE entry_id=? AND stamp=? AND state='done' ORDER BY rowid DESC LIMIT 1",
                (entry,stamp)).fetchone()
            if not row:return False
            state=conn.execute('SELECT status FROM image_reviews WHERE sha256=?',(row['sha256'],)).fetchone()
            paths=conn.execute('SELECT path FROM image_review_files WHERE sha256=?',(row['sha256'],)).fetchall()
            if not state or (state[0]!='deleted' and not any(self.store.safe_path(p[0]).is_file() for p in paths)):
                return False
            conn.execute('INSERT OR REPLACE INTO image_collection_entries VALUES (?,?,?,?,?,?,?)',
                (sid,entry,row['kind'],stamp,row['sha256'],'done',''))
            conn.execute('INSERT OR IGNORE INTO image_collection_content VALUES (?,?,?)',(sid,row['sha256'],time.time()))
            return True

    def ingest(self,sid,entry,kind,temporary,stamp):
        """Validate and ingest one exported image."""
        with Image.open(temporary) as image:
            fmt=image.format;dimensions=list(image.size);image.verify()
        extensions={'PNG':'png','JPEG':'jpg','WEBP':'webp','GIF':'gif'}
        if fmt not in extensions:raise ValueError('Unsupported exported image')
        digest=hashlib.sha256(temporary.read_bytes()).hexdigest()
        folder=self.assets/'review_incoming';folder.mkdir(exist_ok=True)
        target=folder/(digest+'.'+extensions[fmt])
        with self.store.connect() as conn:
            state=conn.execute('SELECT status FROM image_reviews WHERE sha256=?',(digest,)).fetchone()
        if state and state[0] in ('reviewed','renamed'):
            target=self.assets/'reviewed'/target.name
        metadata=dict(format=fmt,dimensions=dimensions,attribution='unconfirmed',
            collection_session=sid,cache_entries=[{'id':entry,'kind':kind,'cache_root':str(self.cache)}])
        with self.store.connect() as conn:
            conn.execute('BEGIN IMMEDIATE')
            active=conn.execute('SELECT active FROM image_collection_sessions WHERE id=?',(sid,)).fetchone()
            if not active or not active[0]:raise ValueError('Collection session changed')
            existing=conn.execute('SELECT status,metadata_json FROM image_reviews WHERE sha256=?',(digest,)).fetchone()
            old_paths=conn.execute('SELECT path FROM image_review_files WHERE sha256=?',(digest,)).fetchall()
            if existing and existing['status'] in ('reviewed','renamed') and old_paths:
                target=self.assets/'reviewed'/Path(old_paths[0][0]).name
            present=any(self.store.safe_path(row[0]).is_file() for row in old_paths)
            if existing and existing['status']!='deleted' and not present:
                if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
                    raise ValueError('Destination contains different content; refusing to overwrite')
                if not target.exists():temporary.rename(target)
                stat=target.stat()
                conn.execute('INSERT OR REPLACE INTO image_review_files VALUES (?,?,?,?)',(target.relative_to(self.assets).as_posix(),digest,stat.st_size,stat.st_mtime_ns))
                self.store.mark_dirty(conn,digest)
            if not existing:
                if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
                    raise ValueError('Hash destination contains different content; refusing to overwrite')
                if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
                    raise ValueError('Destination contains different content; refusing to overwrite')
                if not target.exists():temporary.rename(target)
                stat=target.stat()
                conn.execute('INSERT INTO image_reviews VALUES (?,?,?,?,?,?)',
                    (digest,'pending',entry+'.'+extensions[fmt],json.dumps(metadata),time.time(),time.time()))
                conn.execute('INSERT OR REPLACE INTO image_review_files VALUES (?,?,?,?)',
                    (target.relative_to(self.assets).as_posix(),digest,stat.st_size,stat.st_mtime_ns))
                self.store.mark_dirty(conn,digest)
            else:
                saved=json.loads(existing['metadata_json'])
                refs=saved.setdefault('cache_entries',[])
                if not any(r.get('id')==entry for r in refs):
                    refs.extend(metadata['cache_entries'])
                    conn.execute('UPDATE image_reviews SET metadata_json=? WHERE sha256=?',(json.dumps(saved),digest))
                    self.store.mark_dirty(conn,digest)
            conn.execute('INSERT OR REPLACE INTO image_collection_entries VALUES (?,?,?,?,?,?,?)',
                         (sid,entry,kind,stamp,digest,'done',''))
            conn.execute('INSERT OR IGNORE INTO image_collection_content VALUES (?,?,?)',(sid,digest,time.time()))
        temporary.unlink(missing_ok=True)
        return digest,not bool(existing)

    def export(self,sid,entry,kind):
        stamp=self.stamp(entry)
        if self.already_done(sid,entry,stamp):return
        incoming=self.assets/'.review_incoming';incoming.mkdir(exist_ok=True)
        temporary=incoming/(entry+'.'+uuid.uuid4().hex+'.png')
        command=[str(self.tool),'--dir',str(self.cache),'export',entry,'-o',str(temporary)]
        if kind=='ktx2':command.append('--convert')
        try:
            process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=NO_CONSOLE)
            deadline=time.monotonic()+30
            try:
                while process.poll() is None:
                    if self.stopped(sid) or time.monotonic()>deadline:
                        process.terminate();process.wait(timeout=5)
                        raise OSError('Export stopped or timed out')
                    self.update(sid,'running');time.sleep(.15)
                if process.returncode:raise OSError('rbxcache export failed; will retry')
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=5)
                process.stdout.close();process.stderr.close()
            if self.stamp(entry)!=stamp:raise OSError('Cache entry changed during export; retrying')
            self.ingest(sid,entry,kind,temporary,stamp)
        finally:temporary.unlink(missing_ok=True)

    def import_current(self, cancel_event=None, progress=None):
        self.stop()
        deadline=time.monotonic()+40
        while self.session()['status']=='stopping':
            if time.monotonic()>deadline:
                raise RuntimeError('Old collector did not stop; import cancelled')
            time.sleep(.2)
        self.store.migrate()
        sid=self.new_session()
        failures=[]
        try:
            self.update(sid,'running')
            result=subprocess.run([str(self.tool),'--dir',str(self.cache),'list','--category','10',
                '--limit','0','--sort','id'],capture_output=True,text=True,timeout=120,creationflags=NO_CONSOLE)
            if result.returncode:
                raise RuntimeError(result.stderr or result.stdout or 'Cache listing failed')
            entries=[]
            for line in result.stdout.splitlines():
                match=re.match(r'^([0-9a-f]{32})\s+(png|webp|jpeg|jpg|gif|ktx2)\s+',line)
                if match:entries.append((match[1],match[2]))
            for index,(entry,kind) in enumerate(entries,1):
                if cancel_event is not None and cancel_event.is_set():
                    break
                try:self.export(sid,entry,kind)
                except Exception as exc:
                    failures.append((entry,str(exc)))
                    with self.store.connect() as conn:
                        conn.execute('INSERT OR REPLACE INTO image_collection_entries VALUES (?,?,?,?,?,?,?)',
                            (sid,entry,kind,'retry-on-import',None,'error',str(exc)[:300]))
                if progress:progress(index,len(entries))
            self.store.sync_manifest()
            return len(entries),len(failures)
        finally:
            self.update(sid,'stopped',str(failures[:3]) if failures else '')


if __name__=='__main__':
    print(CacheImport().import_current())
