#!/usr/bin/env python3
"""Add one game-asset route to the existing nginx site; preserve other routes."""
from pathlib import Path
import subprocess

site = Path('/etc/nginx/sites-available/default')
original = site.read_text()
line = 'include /home/l4d2/deploy/nginx-l4d2-location.conf;'
if line not in original:
    assert original.count('server_name _;') == 1
    updated = original.replace('server_name _;', 'server_name _;\n\n\t' + line)
    site.write_text(updated)
    check = subprocess.run(['nginx', '-t'])
    if check.returncode:
        site.write_text(original)
        raise SystemExit(check.returncode)
else:
    subprocess.run(['nginx', '-t'], check=True)
subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
print('MOTD_ROUTE_ENABLED')
