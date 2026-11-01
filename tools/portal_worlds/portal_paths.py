"""Keep generated maps, downloads and diagnostics outside the game archive."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
DEFAULT_GAME = ROOT.parent.parent
CACHE = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache'))
WORKSPACE = Path(os.environ.get('BAR_PORTAL_WORKSPACE', CACHE / 'bar/portal-worlds')).expanduser().resolve()

