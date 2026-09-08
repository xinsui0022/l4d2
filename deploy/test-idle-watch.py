"""Regression checks for reconnect races, partial status and continuous idle time."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

sys.modules.setdefault('rcon', types.SimpleNamespace(run=lambda command: ''))
spec = importlib.util.spec_from_file_location('idle_watch', Path(__file__).with_name('idle-watch.py'))
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)
real_humans = watch.humans

class IdleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        watch.STATE = Path(self.temp.name)/'state.json'
        self.now = 10000.0
        self.data = dict(humans=0,seen=1,idle=2000,threshold=1800,epoch=5)
        self.count = 0
        self.instance = 'test-instance'
        self.restart_commands=[]
        self.patches=[patch.object(watch,'invocation',lambda:self.instance),
                      patch.object(watch,'snapshot',lambda:dict(self.data)),
                      patch.object(watch,'humans',lambda:self.count),
                      patch.object(watch.time,'monotonic',lambda:self.now),
                      patch.object(watch,'run',lambda command:self.restart_commands.append(command) or 'JJD_IDLE_RESTART accepted')]
        for item in self.patches:item.start()
        self.seed()
    def tearDown(self):
        for item in reversed(self.patches):item.stop()
        self.temp.cleanup()
    def seed(self, elapsed=1801):
        watch.save(dict(version=2,instance=self.instance,observed=self.now-60,empty_since=self.now-elapsed,epoch=5))
    def test_true_idle_requests_game_guard(self):
        self.assertEqual(watch.check()['action'],'restart_requested')
        self.assertEqual(self.restart_commands,['sm_jjd_idle_restart 5'])
    def test_three_four_minutes_never_restarts(self):
        self.seed(240);self.data['idle']=240
        self.assertEqual(watch.check()['action'],'wait');self.assertFalse(self.restart_commands)
    def test_human_rejoin_cancels(self):
        self.data['humans']=1
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_pending_connection_blocks(self):
        self.count=1
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_brief_visit_between_polls_restarts_clock(self):
        self.data['epoch']=7
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_join_during_final_recheck(self):
        with patch.object(watch,'snapshot',side_effect=[dict(self.data),dict(self.data,humans=1,epoch=6)]):
            self.assertEqual(watch.check()['action'],'cancelled')
        self.assertFalse(self.restart_commands)
    def test_instance_change_resets_clock(self):
        self.instance='new-instance'
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_fresh_empty_never_repeats(self):
        self.data['seen']=0
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_long_observation_gap_resets_clock(self):
        self.now+=300
        self.assertEqual(watch.check()['idle'],0);self.assertFalse(self.restart_commands)
    def test_unavailable_guard_clears_countdown(self):
        with patch.object(watch,'snapshot',side_effect=RuntimeError('unavailable')):
            with self.assertRaises(RuntimeError):watch.check()
        self.assertIsNone(__import__('json').loads(watch.STATE.read_text())['empty_since'])
    def test_game_rejects_stale_request(self):
        with patch.object(watch,'run',return_value='JJD_IDLE_RESTART cancelled'):
            self.assertEqual(watch.check()['action'],'cancelled')
    def test_truncated_status_is_not_empty(self):
        original_humans=real_humans
        with patch.object(watch,'run',return_value='players : 0 humans, 0 bots\n'):
            with self.assertRaises(RuntimeError):original_humans()
    def test_loading_row_overrides_zero_summary(self):
        original_humans=real_humans
        with patch.object(watch,'run',return_value='players : 0 humans, 0 bots\n# 2 "Loading player" STEAM_ID_PENDING connecting\n# 3 "Nick" BOT active\n#end\n'):
            self.assertEqual(original_humans(),1)

if __name__=='__main__':unittest.main(verbosity=2)
