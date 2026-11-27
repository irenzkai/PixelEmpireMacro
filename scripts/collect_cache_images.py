r"""Read only Roblox asset caches; extract signature-verified images for review.

Run: .venv\Scripts\python.exe scripts/collect_cache_images.py
No account stores, logs, cookies, or network endpoints are accessed.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import warnings

from PIL import Image, ImageDraw, ImageOps, UnidentifiedImageError

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'public' / 'cache_assets'
LOCAL = Path(os.environ['LOCALAPPDATA'])
CANDIDATES = [LOCAL/'Roblox/rbx-storage', LOCAL/'Roblox/rbx-storage-sc',
              LOCAL/'Temp/Roblox/http', LOCAL/'Roblox/http']
SIGNATURES = [(b'\x89PNG\r\n\x1a\n', 'PNG'), (b'\xff\xd8\xff', 'JPEG'),
              (b'GIF87a', 'GIF'), (b'GIF89a', 'GIF'), (b'RIFF', 'WEBP'), (b'BM', 'BMP')]
EXT = {'PNG':'png', 'JPEG':'jpg', 'GIF':'gif', 'WEBP':'webp', 'BMP':'bmp'}


def payload_end(data, fmt):
    if fmt == 'PNG':
        pos = 8
        while pos + 12 <= len(data):
            length = struct.unpack('>I', data[pos:pos+4])[0]
            kind = data[pos+4:pos+8]
            pos += 12 + length
            if pos > len(data):
                raise ValueError('truncated PNG')
            if kind == b'IEND':
                return pos
        raise ValueError('missing IEND')
    if fmt == 'JPEG':
        end = data.find(b'\xff\xd9', 3)
        if end < 0:
            raise ValueError('missing JPEG end')
        return end + 2
    if fmt == 'WEBP':
        if data[8:12] != b'WEBP':
            raise ValueError('not WEBP')
        return struct.unpack('<I', data[4:8])[0] + 8
    if fmt == 'BMP':
        return struct.unpack('<I', data[2:6])[0]
    pos = 13
    if data[10] & 128:
        pos += 3 * (2 ** ((data[10] & 7) + 1))
    while pos < len(data):
        marker = data[pos]
        pos += 1
        if marker == 0x3b:
            return pos
        if marker == 0x21:
            pos += 1  # Extension label, then sub-blocks.
        elif marker == 0x2c:
            packed = data[pos+8]
            pos += 9
            if packed & 128:
                pos += 3 * (2 ** ((packed & 7) + 1))
            pos += 1  # LZW code size.
        else:
            raise ValueError('invalid GIF block')
        while pos < len(data):
            size = data[pos]
            pos += 1
            if not size:
                break
            pos += size
    raise ValueError('truncated GIF')


def collect():
    DEST.mkdir(parents=True, exist_ok=True)
    records = {}
    counts = dict(scanned=0, unreadable=0, unsupported_or_nonimage=0,
                  invalid_images=0, oversized=0, duplicate_sources=0)
    inspected = []
    with warnings.catch_warnings():
        warnings.simplefilter('error', Image.DecompressionBombWarning)
        for cache in CANDIDATES:
            info = {'path': str(cache), 'exists': cache.is_dir(), 'files_scanned': 0}
            inspected.append(info)
            if not cache.is_dir():
                continue
            for folder, dirs, files in os.walk(cache, followlinks=False):
                dirs[:] = sorted(d for d in dirs if not (Path(folder)/d).is_symlink())
                for name in sorted(files):
                    source = Path(folder)/name
                    if source.is_symlink():
                        continue
                    counts['scanned'] += 1
                    info['files_scanned'] += 1
                    try:
                        with source.open('rb') as stream:
                            head = stream.read(65536)
                            hits = sorted((head.find(sig), fmt) for sig, fmt in SIGNATURES if sig in head)
                            if not hits:
                                counts['unsupported_or_nonimage'] += 1
                                continue
                            if source.stat().st_size > 64*1024*1024:
                                counts['oversized'] += 1
                                continue
                            raw = head + stream.read()
                        found = False
                        for offset, fmt in hits:
                            try:
                                data = raw[offset:]
                                data = data[:payload_end(data, fmt)]
                                with Image.open(io.BytesIO(data)) as im:
                                    if im.format != fmt:
                                        continue
                                    dimensions = list(im.size)
                                    im.verify()
                                digest = hashlib.sha256(data).hexdigest()
                                filename = digest + '.' + EXT[fmt]
                                location = {'source_path': str(source), 'image_offset': offset}
                                if digest in records:
                                    records[digest]['sources'].append(location)
                                    counts['duplicate_sources'] += 1
                                else:
                                    target = DEST/filename
                                    if not target.exists():
                                        target.write_bytes(data)
                                    elif hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                                        raise OSError('existing output hash mismatch')
                                    records[digest] = dict(filename=filename, source_path=str(source),
                                        format=fmt, dimensions=dimensions, sha256=digest,
                                        sources=[location], attribution='unconfirmed', review_status='unreviewed')
                                found = True
                                break
                            except (ValueError, OSError, SyntaxError, IndexError, struct.error, Image.DecompressionBombError, Image.DecompressionBombWarning):
                                continue
                        if not found:
                            counts['invalid_images'] += 1
                    except OSError:
                        counts['unreadable'] += 1
    assets = sorted(records.values(), key=lambda x: x['filename'])
    sheets = []
    for page in range(0, len(assets), 100):
        batch = assets[page:page+100]
        sheet = Image.new('RGB', (1200, ((len(batch)+7)//8)*118), '#e2e8f0')
        draw = ImageDraw.Draw(sheet)
        for i, asset in enumerate(batch):
            x, y = (i % 8)*150, (i//8)*118
            # Checkerboard makes transparent sprites visible.
            tile = Image.new('RGBA', (142, 84), '#ffffff')
            td = ImageDraw.Draw(tile)
            for ty in range(0,84,8):
                for tx in range(0,142,8):
                    if (tx//8 + ty//8) % 2:
                        td.rectangle((tx,ty,tx+7,ty+7), fill='#b8bec8')
            try:
                with Image.open(DEST/asset['filename']) as im:
                    thumb = ImageOps.contain(im.convert('RGBA'), (138,80))
                    tile.alpha_composite(thumb, ((142-thumb.width)//2, (84-thumb.height)//2))
                sheet.paste(tile.convert('RGB'), (x+4,y+3))
                draw.text((x+4,y+89), f"{page+i+1:04} {asset['sha256'][:10]}", fill='black')
                draw.text((x+4,y+103), f"{asset['format']} {asset['dimensions'][0]}x{asset['dimensions'][1]}", fill='black')
            except (OSError, ValueError):
                draw.text((x+4,y+20), 'Preview unavailable', fill='black')
            asset['review_id'] = page+i+1
        filename = f'contact_sheet_{page//100+1:03}.jpg'
        sheet.save(DEST/filename, quality=85)
        sheets.append(filename)
    manifest = dict(version=1, cache_locations=inspected, counts=counts,
                    recovered_images=len(assets), contact_sheets=sheets, assets=assets)
    (DEST/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (DEST/'README.txt').write_text('Unreviewed Roblox cache images. Experience attribution is unconfirmed.\n'
        'Do not use as detection references until reviewed. Contact sheets use manifest review_id.\n'
        'SHA-256 names refer to extracted image bytes; cache wrappers are excluded.\n', encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ('cache_locations','counts','recovered_images','contact_sheets')}, indent=2))


if __name__ == '__main__':
    from cache_image_import import CacheImport
    print(CacheImport().import_current())
