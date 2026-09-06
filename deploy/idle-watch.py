#!/usr/bin/env python3
"""Wall-clock maintenance independent of ZoneMod's plugin unload/hibernation."""
import json
import os
from pathlib import Path
import re
import subprocess
import time
from rcon import run

STATE = Path('/home/l4d2/deploy/idle-state.json')
THRESHOLD = 1800

def invocation():
    return subprocess.check_output(['systemctl', '--user', 'show', 'l4d2.service',
                                    '-p', 'InvocationID', '--value'], text=True).strip()

def humans():
    status = run('status')
    match = re.search(r'^players\s*:\s*(\d+) humans', status, re.M)
    if not match:
        raise RuntimeError('Cannot confirm player count; no restart attempted')
    return int(match.group(1))

def number(cvar):
    # Engine ConVars survive plugin unloading, and do not need sm_cvar.
    match = re.search(r'^"' + re.escape(cvar) + r'" = "(\d+)"', run(cvar), re.M)
    return int(match.group(1)) if match else 0

def check():
    now = int(time.time())
    instance = invocation()
    if not instance:
        raise RuntimeError('No active service instance; no restart attempted')
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    if state.get('instance') != instance:
        state = {'instance': instance, 'seen': False, 'last_active': 0}
    count = humans()
    if count:
        state.update(seen=True, last_active=now)
    else:
        seen, last = number('jjd_idle_seen_human'), number('jjd_idle_last_active')
        if seen and 0 < last <= now:
            state['seen'] = True
            state['last_active'] = max(state['last_active'], last)
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(state) + '\n')
    temporary.chmod(0o600)
    os.replace(temporary, STATE)
    idle = now - state['last_active'] if state['seen'] else 0
    result = {'humans': count, 'seen': state['seen'], 'idle': idle,
              'threshold': THRESHOLD, 'action': 'wait'}
    if count == 0 and state['seen'] and idle >= THRESHOLD:
        # Fail closed if players or the service instance changed during checks.
        if humans() == 0 and invocation() == instance:
            subprocess.run(['systemctl', '--user', 'restart', '--no-block', 'l4d2.service'], check=True)
            result['action'] = 'restart'
    return result

if __name__ == '__main__':
    print(json.dumps(check(), ensure_ascii=False))
