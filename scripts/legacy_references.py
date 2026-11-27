"""Read the retained AHK image settings without changing unrelated options."""
from pathlib import Path
import configparser
ROOT=Path(__file__).resolve().parents[1]
_cache={}
def configured_image(section,key,default):
    path=ROOT/'waystone_config.ini'
    try:
        stamp=path.stat().st_mtime_ns
        if _cache.get('stamp')!=stamp:
            raw=path.read_bytes();text=raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8-sig')
            cfg=configparser.ConfigParser(interpolation=None);cfg.read_string(text);_cache.update(stamp=stamp,cfg=cfg)
        value=_cache['cfg'].get(section,key,fallback=default)
    except (OSError,configparser.Error):value=default
    return ROOT/value
