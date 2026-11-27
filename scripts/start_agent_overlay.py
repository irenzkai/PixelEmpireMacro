"""Small bootstrap so import/startup failures are visible in the AHK GUI."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
if __name__=='__main__':
    import sys
    sys.path.insert(0,str(ROOT))
    from scripts.tk_runtime import configure_tk
    configure_tk()
    try:runpy.run_path(str(ROOT/'ahk_agent.py'),run_name='__main__')
    except Exception as exc:
        error=ROOT/'.task-output/agent_startup_error.txt';error.parent.mkdir(exist_ok=True)
        error.write_text(type(exc).__name__+': '+str(exc),encoding='utf-8')
        raise
