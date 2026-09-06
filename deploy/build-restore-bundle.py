#!/usr/bin/env python3
"""Compatibility entry point: all new backups use consistent database snapshots."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('backup-server.py')),run_name='__main__')
