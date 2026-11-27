"""Resolve Tcl/Tk from this interpreter; never change user/global environment."""
from pathlib import Path
import os
import sys

def configure_tk():
    base=Path(sys.base_prefix)/'tcl'
    for variable,folder,marker in [('TCL_LIBRARY','tcl8.6','init.tcl'),('TK_LIBRARY','tk8.6','tk.tcl')]:
        path=base/folder
        if (path/marker).is_file():os.environ[variable]=path.as_posix()
