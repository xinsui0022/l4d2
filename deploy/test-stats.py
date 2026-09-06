"""Engine settlement test with a temporary, isolated database; always restores production plugin."""
from pathlib import Path
import json,re,shutil,sqlite3,subprocess,time
base=Path.home();sm=base/'steamcmd/l4d2/left4dead2/addons/sourcemod'
def run(*args):return subprocess.check_output(args,text=True)
def rcon(cmd):return run('python3',str(base/'deploy/rcon.py'),cmd)
assert re.search(r'players\s*:\s*0 humans',rcon('status')),'Server must be empty'
cfg=sm/'configs/databases.cfg';original=cfg.read_text()
testdb=sm/'data/sqlite/jjd_stats_test.sq3';assert not testdb.exists(),'Unexpected old test database'
source=(base/'custom/scripting/jjd_stats.sp').read_text()
source=source.replace('Database.Connect(Connected,"jjd_stats")','Database.Connect(Connected,"jjd_stats_test")').replace('data/jjd-stats-pending','data/jjd-stats-test-pending')
source=source.replace('    practice=CreateConVar','    RegServerCmd("sm_jjd_stats_selftest",SelfTest);\n    practice=CreateConVar',1)
source=source.replace('    Guard(null);live=false;','    if(!settlementTest)Guard(null);live=false;')
source=source.replace('Database db;','Database db;\nbool settlementTest;')
source+='''
public Action SelfTest(int args){
 if(!ready){PrintToServer("TEST_NOT_READY");return Plugin_Handled;}
 settlementTest=true;slots=1;strcopy(ids[0],sizeof(ids[]),"test-only");strcopy(names[0],sizeof(names[]),"test player");
 counts[0][Common]=240;counts[0][SIDamage]=1234;counts[0][TankDamage]=1100;counts[0][Saves]=2;counts[0][Revives]=1;counts[0][InfectedDamage]=33;counts[0][TankAttack]=45;counts[0][Friendly]=29;counts[0][SIKills]=3;
 strcopy(halfId,sizeof(halfId),"selftest-valid");strcopy(mapName,sizeof(mapName),"test-map");strcopy(reason,sizeof(reason),"ranked");live=true;eligible=true;
 PrintToServer("TEST_POINTS=%d",Points(0));RoundEnd(null,"round_end",false);RoundEnd(null,"round_end",false);
 // Deliberately resubmit the same half. Composite keys must prevent double scoring.
 live=true;RoundEnd(null,"round_end",false);
 strcopy(halfId,sizeof(halfId),"selftest-practice");live=true;eligible=true;practice.SetInt(1);Guard(null);RoundEnd(null,"round_end",false);practice.SetInt(0);
 settlementTest=false;return Plugin_Handled;
}
'''
testsource=base/'custom/test-jjd-stats.sp';testbinary=base/'custom/test-jjd-stats.smx';testsource.write_text(source)
sdk=base/'l4d2-mod/addons/sourcemod/scripting'
run(str(sdk/'sourcemod/spcomp'),str(testsource),'-i'+str(sdk/'sourcemod/include'),'-o'+str(testbinary))
try:
    end=original.rfind('}');cfg.write_text(original[:end]+'\n "jjd_stats_test"\n {\n "driver" "sqlite"\n "database" "jjd_stats_test"\n }\n'+original[end:])
    shutil.copy2(testbinary,sm/'plugins/jjd_stats.smx');run('systemctl','--user','restart','l4d2')
    time.sleep(12)
    for _ in range(10):
        if 'ready=1' in rcon('sm_jjd_stats_status'):break
        time.sleep(1)
    output=rcon('sm_jjd_stats_selftest');assert 'TEST_POINTS=35' in output,output
    time.sleep(2)
    with sqlite3.connect(testdb) as db:
        assert db.execute('SELECT score,halves FROM ranking').fetchone()==(35,1)
        assert db.execute('SELECT count(*) FROM contributions').fetchone()[0]==1
        assert db.execute("SELECT eligible FROM halves WHERE id='selftest-practice'").fetchone()[0]==0
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    result={'engine_settlement':True,'score':35,'duplicate_award_prevented':True,'practice_excluded':True,'production_database_untouched':True}
    (base/'deploy/stats-test-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
finally:
    cfg.write_text(original);shutil.copy2(base/'custom/jjd_stats.smx',sm/'plugins/jjd_stats.smx');run('systemctl','--user','restart','l4d2')
    for path in (testdb,testsource,testbinary):path.unlink(missing_ok=True)
    testpending=sm/'data/jjd-stats-test-pending'
    if testpending.exists():
        for path in testpending.glob('*.sql'):path.unlink()
        testpending.rmdir()
