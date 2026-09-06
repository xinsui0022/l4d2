#!/usr/bin/env python3
"""Empty-server integration test using synthetic activity timestamps (not a 30m wait)."""
import json
import subprocess
import time
from rcon import run
from importlib.machinery import SourceFileLoader
watch = SourceFileLoader('idle_watch', '/home/l4d2/deploy/idle-watch.py').load_module()

def pid():
    return subprocess.check_output(['systemctl', '--user', 'show', 'l4d2', '-p', 'MainPID', '--value'], text=True).strip()

def empty():
    state = run('status')
    assert '0 humans' in state, 'A player joined; aborting maintenance test'

empty()
old = pid()
out = {'old_pid': old, 'method': 'synthetic last-activity timestamps; real process restart'}
assert watch.number('jjd_idle_seen_human') == 0, 'Start this test on a fresh, unused process'
out['initial_empty'] = watch.check()
assert out['initial_empty']['action'] == 'wait' and pid() == old
empty()
run('jjd_idle_seen_human 1')
run(f'jjd_idle_last_active {int(time.time()) - 1790}')
out['before_threshold'] = watch.check()
assert out['before_threshold']['action'] == 'wait' and pid() == old
empty()
# The watcher retains the newest activity, so wait across the remaining boundary.
time.sleep(12)
empty()
out['threshold_reached'] = watch.check()
assert out['threshold_reached']['action'] == 'restart'
deadline = time.monotonic() + 100
while time.monotonic() < deadline:
    time.sleep(2)
    try:
        current = pid()
        if current != '0' and current != old:
            state = run('sm_jjd_status')
            if 'idle_seconds=1800' in state:
                out['new_pid'] = current
                out['after_restart'] = state.strip()
                break
    except OSError:
        pass
else:
    raise AssertionError('Server did not become ready after idle restart')
assert 'seen=0' in out['after_restart'] and 'map=c2m1_highway' in out['after_restart']
out['still_empty'] = watch.check()
assert out['still_empty']['action'] == 'wait' and not out['still_empty']['seen'] and pid() == out['new_pid']
print(json.dumps(out, ensure_ascii=False, indent=2))
