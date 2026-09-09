#!/usr/bin/env python3
"""Read-only remote checks, writing no secrets to output."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import urllib.request
from rcon import run

out = {}
for command in ('status', 'sm_jjd_status', 'sm_cvar l4d_ready_cfg_name', 'sm_jjd_idle_check'):
    out[command] = run(command).strip()
plugins = run('sm plugins list')
out['plugin_count'] = re.search(r'Listing (\d+) plugins', plugins).group(1)
out['custom_plugin'] = next(line.strip() for line in plugins.splitlines() if 'Jiaojiedi' in line)
assert '<Failed>' not in plugins and '<Error>' not in plugins
assert 'admin_root=1' in out['sm_jjd_status'] and 'idle_seconds=1800' in out['sm_jjd_status']
assert 'ZoneMod' in out['sm_cvar l4d_ready_cfg_name']
assert 'hostname: [CN] 交界地 | ZoneMod药抗4v4 | 测试服' in out['status']
for name in ('welcome.html', 'banner.html', 'wallpaper.png'):
    with urllib.request.urlopen('http://127.0.0.1/l4d2/' + name, timeout=5) as response:
        data = response.read()
    local = Path('/home/l4d2/custom/motd') / name
    assert data == local.read_bytes()
    out[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
for url in ('http://127.0.0.1:18080/', 'http://127.0.0.1:18080/deploy/rcon.py'):
    try:
        urllib.request.urlopen(url, timeout=5)
        raise AssertionError('Unexpected file exposure')
    except urllib.error.HTTPError as exc:
        assert exc.code == 404
out['units'] = subprocess.check_output(['systemctl', '--user', 'is-active', 'l4d2.service', 'l4d2-motd.service', 'l4d2-idle-check.timer'], text=True).strip()
print(json.dumps(out, ensure_ascii=False, indent=2))
