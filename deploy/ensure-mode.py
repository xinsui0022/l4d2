#!/usr/bin/env python3
"""Ensure a fresh process loads ZoneMod without forcing an already loaded mode."""
import time
from rcon import run

deadline = time.monotonic() + 90
while True:
    try:
        run('status')
        break
    except (OSError, ValueError):
        if time.monotonic() >= deadline:
            raise
        time.sleep(2)
time.sleep(5)
state = run('sm_cvar l4d_ready_cfg_name')
if 'ZoneMod v2.9.1b' in state:
    print('ZoneMod already loaded by the autoloader.')
else:
    print(run('sm_forcematch zonemod'), end='')
