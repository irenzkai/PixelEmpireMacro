"""Use official rbxcache exports; index images locally without cache parsing."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT/'public/cache_assets'
TOOL = ROOT/'.tools/rbxcache/rbxcache.exe'
CACHE = Path(os.environ['LOCALAPPDATA'])/'Roblox'
COMMANDS = []


def run(args):
    command = [str(TOOL), '--dir', str(CACHE), *map(str, args)]
    COMMANDS.append(command)
    result = subprocess.run(command, capture_output=True, text=True, timeout=300)
    return result


def index():
    records = {}
    invalid = 0
    hardlinked_duplicates = 0
    source_paths = {}
    for folder, _, files in os.walk(CACHE/'rbx-storage'):
        for filename in files:
            if len(filename)==32 and all(c in '0123456789abcdef' for c in filename):
                source_paths[filename] = str(Path(folder)/filename)
    for folder in [OUT, OUT/'rbxcache/png', OUT/'rbxcache/webp', OUT/'rbxcache/converted', OUT/'live_exports']:
        if not folder.exists():
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in ('.png','.jpg','.jpeg','.webp','.gif','.bmp') or path.name.startswith('contact_sheet_'):
                continue
            try:
                with Image.open(path) as im:
                    fmt, dimensions = im.format, list(im.size)
                    im.verify()
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                rel = path.relative_to(OUT).as_posix()
                source = source_paths.get(path.stem) if folder != OUT else None
                rec = records.setdefault(digest, dict(filename=rel, sha256=digest,
                    format=fmt, dimensions=dimensions, source_path=source,
                    attribution='unconfirmed', review_status='unreviewed', exported_files=[]))
                rec['exported_files'].append(rel)
                canonical = OUT/rec['filename']
                if canonical != path and folder != OUT and not os.path.samefile(canonical,path):
                    # Keep provenance filenames while sharing identical file data.
                    # Only tool-generated exports are replaced, never cache files.
                    staging = path.with_suffix(path.suffix+'.dedup-link')
                    try:
                        os.link(canonical,staging)
                        os.replace(staging,path)
                        hardlinked_duplicates += 1
                    except OSError:
                        if staging.exists():
                            staging.unlink()
                if source and not rec['source_path']:
                    rec['source_path'] = source
                if source:
                    rec.setdefault('cache_entries', []).append(dict(id=path.stem, source_path=source,
                        source_exists=True, converted=folder.name == 'converted'))
            except (OSError, ValueError, Image.DecompressionBombError):
                invalid += 1
    assets = sorted(records.values(), key=lambda r:r['sha256'])
    for i,asset in enumerate(assets,1):
        asset['review_id'] = i
    sheets = []
    previous_path = OUT/'manifest.json'
    if previous_path.exists():
        previous = json.loads(previous_path.read_text(encoding='utf-8'))
        candidates = previous.get('contact_sheets',[])
        if (candidates and [a['sha256'] for a in previous.get('assets',[])] == [a['sha256'] for a in assets]
            and all((OUT/name).is_file() for name in candidates)):
            sheets = candidates
    for start in range(0,0 if sheets else len(assets),100):
        batch = assets[start:start+100]
        sheet = Image.new('RGB',(1200,((len(batch)+7)//8)*118),'#dddddd')
        draw = ImageDraw.Draw(sheet)
        for i,rec in enumerate(batch):
            x,y = i%8*150,i//8*118
            try:
                with Image.open(OUT/rec['filename']) as im:
                    thumb = ImageOps.contain(im.convert('RGBA'),(140,82))
                tile = Image.new('RGBA',(142,84),'#ffffff')
                td = ImageDraw.Draw(tile)
                for ty in range(0,84,8):
                    for tx in range(0,142,8):
                        if (tx//8+ty//8)%2:
                            td.rectangle((tx,ty,tx+7,ty+7),fill='#9da5af')
                tile.alpha_composite(thumb,((142-thumb.width)//2,(84-thumb.height)//2))
                sheet.paste(tile.convert('RGB'),(x+4,y+3))
            except (OSError,ValueError):
                draw.text((x+4,y+20),'Preview unavailable',fill='black')
            rec['review_id'] = start+i+1
            draw.text((x+4,y+89),f"{start+i+1:05} {rec['sha256'][:9]}",fill='black')
            draw.text((x+4,y+103),f"{rec['format']} {rec['dimensions'][0]}x{rec['dimensions'][1]}",fill='black')
        name = f'contact_sheet_{start//100+1:03}.jpg'
        sheet.save(OUT/name,quality=82)
        sheets.append(name)
    manifest = dict(tool='PirxcyFinal/rbxcache',version='1.2.0',
        cache_locations=[str(CACHE/'rbx-storage.db'),str(CACHE/'rbx-storage')],
        attribution='All assets unconfirmed; observation during play does not prove game ownership.',
        unique_images=len(assets), invalid_images=invalid,
        hardlinked_duplicates=hardlinked_duplicates,
        duplicate_export_files=sum(len(a['exported_files'])-1 for a in assets),
        contact_sheets=sheets,assets=assets)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    # Re-export must never erase renamed/deleted review states or source metadata.
    from image_review_store import ReviewStore
    ReviewStore(OUT,ROOT/'agent_memory.db').sync_manifest()
    print(f"INDEX: {len(assets)} unique images; {len(sheets)} contact sheets; {invalid} unreadable",flush=True)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    version = subprocess.check_output([str(TOOL),'--version'],text=True).strip()
    for kind in ('png','webp','ktx2'):
        folder = OUT/'rbxcache'/kind
        if folder.exists() and any(folder.iterdir()):
            print('Existing exports retained:',kind,flush=True)
            continue
        result = run(['export-all',folder,'--kind',kind])
        print(kind,result.returncode,result.stdout[-300:],flush=True)
        if result.returncode:
            print('Export warnings:',result.stderr[-500:],flush=True)
    converted = OUT/'rbxcache/converted'
    converted.mkdir(parents=True,exist_ok=True)
    textures = sorted((OUT/'rbxcache/ktx2').glob('*.ktx2'))
    failures = []
    def convert(path):
        target = converted/(path.stem+'.png')
        if target.exists():
            return None
        try:
            result = run(['export',path.stem,'--convert','-o',target])
        except subprocess.TimeoutExpired:
            return path.stem
        return path.stem if result.returncode else None
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for i,failed in enumerate(pool.map(convert,textures),1):
            if failed:
                failures.append(failed)
            if i%500 == 0:
                print(f'Textures {i}/{len(textures)}, failed {len(failures)}',flush=True)
    receipt = dict(tool=version,binary_sha256=hashlib.sha256(TOOL.read_bytes()).hexdigest(),
        repository='https://github.com/PirxcyFinal/rbxcache',commands=COMMANDS,
        failed_texture_ids=failures,texture_count=len(textures),
        repeat_command=r'.venv\Scripts\python.exe scripts/export_rbxcache_images.py',
        watch_command=[str(TOOL),'--dir',str(CACHE),'watch','--interval','2'])
    (OUT/'export_receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    index()


if __name__ == '__main__':
    from cache_image_import import CacheImport
    print(CacheImport().import_current())
