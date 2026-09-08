#!/usr/bin/env python3
"""Conservative empty-server observation; only the game thread may authorize quit."""
import json
import os
from pathlib import Path
import re
import subprocess
import time
from rcon import run

STATE = Path.home() / 'deploy/idle-state.json'
THRESHOLD = 1800
MAX_GAP = 180

def invocation():
    return subprocess.check_output(['systemctl', '--user', 'show', 'l4d2.service',
                                    '-p', 'InvocationID', '--value'], text=True).strip()

def humans():
    status = run('status')
    match = re.search(r'^players\s*:\s*(\d+) humans', status, re.M)
    if not match or not re.search(r'^#end\s*$', status, re.M):
        raise RuntimeError('Incomplete player status; no restart')
    # The summary can lag behind connecting clients. Unknown/PENDING rows
    # count as occupied; only explicit BOT rows may be excluded.
    rows = re.findall(r'^#\s+\d+\s+.*$', status, re.M)
    pending_or_human = sum(not re.match(r'^#\s+\d+\s+".*"\s+BOT(?:\s|$)', row) for row in rows)
    return max(int(match.group(1)), pending_or_human)

def snapshot():
    text = run('sm_jjd_idle_check')
    match = re.search(r'JJD_IDLE humans=(\d+) seen=([01]) idle=(-?\d+) threshold=(\d+) epoch=(\d+)', text)
    if not match:
        raise RuntimeError('Game maintenance guard unavailable; no restart')
    data = dict(zip(('humans', 'seen', 'idle', 'threshold', 'epoch'), map(int, match.groups())))
    if data['threshold'] != THRESHOLD:
        raise RuntimeError('Maintenance thresholds disagree; no restart')
    return data

def save(state):
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(state) + '\n')
    temporary.chmod(0o600)
    os.replace(temporary, STATE)

def check():
    now = time.monotonic()
    instance = invocation()
    if not instance:
        raise RuntimeError('No active service instance; no restart')
    try:
        state = json.loads(STATE.read_text())
    except (FileNotFoundError, ValueError):
        state = {}
    if (state.get('version') != 2 or state.get('instance') != instance
            or not 0 <= now - state.get('observed', 0) <= MAX_GAP):
        state = {'version': 2, 'instance': instance, 'empty_since': None, 'epoch': None}
    try:
        game = snapshot()
        count = max(humans(), game['humans'])
    except Exception:
        state.update(empty_since=None, observed=now)
        save(state)
        raise
    if count or not game['seen']:
        state['empty_since'] = None
    elif state['empty_since'] is None or state['epoch'] != game['epoch']:
        state['empty_since'] = now
    state.update(epoch=game['epoch'], observed=now)
    save(state)
    elapsed = 0 if state['empty_since'] is None else max(0, now - state['empty_since'])
    result = {'humans': count, 'seen': bool(game['seen']), 'idle': int(elapsed),
              'threshold': THRESHOLD, 'action': 'wait'}
    if count == 0 and elapsed >= THRESHOLD and game['idle'] >= THRESHOLD:
        latest = snapshot()
        if (latest['humans'] == 0 and latest['seen'] and latest['idle'] >= THRESHOLD
                and latest['epoch'] == game['epoch'] and humans() == 0 and invocation() == instance):
            response = run(f"sm_jjd_idle_restart {game['epoch']}")
            result['action'] = 'restart_requested' if ('accepted' in response or 'Command sent;' in response) else 'cancelled'
        else:
            state['empty_since'] = None
            save(state)
            result['action'] = 'cancelled'
    return result

if __name__ == '__main__':
    print(json.dumps(check(), ensure_ascii=False))
