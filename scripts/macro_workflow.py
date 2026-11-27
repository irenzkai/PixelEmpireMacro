"""Compatibility launcher for the local overlay. No repair or live-test execution."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from ahk_agent import main
if __name__=='__main__':
    sys.argv=sys.argv[:1]
    main()
