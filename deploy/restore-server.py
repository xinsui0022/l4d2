#!/usr/bin/env python3
"""Verify in isolation, or restore an overlay onto a freshly installed game."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,os,re,sqlite3,subprocess,tarfile,tempfile
p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);p.add_argument('--manifest',type=Path,required=True);p.add_argument('--verify-only',action='store_true');p.add_argument('--new-ip');args=p.parse_args()
record=json.loads(args.manifest.read_text());assert args.archive.stat().st_size==record['bytes'];assert hashlib.sha256(args.archive.read_bytes()).hexdigest()==record['sha256']
base=Path.home();os.umask(0o077)
with tempfile.TemporaryDirectory(prefix='jjd-restore-') as tmp:
    stage=Path(tmp)
    with tarfile.open(args.archive) as bundle:
        for m in bundle.getmembers():
            name=PurePosixPath(m.name);assert not name.is_absolute() and '..' not in name.parts
            assert not m.isdev() and not m.isfifo()
            target=stage/m.name;assert target.resolve().is_relative_to(stage)
            if m.issym():assert (target.parent/m.linkname).resolve().is_relative_to(stage)
            if m.islnk():assert (stage/m.linkname).resolve().is_relative_to(stage)
        bundle.extractall(stage)
    database=stage/'steamcmd/l4d2/left4dead2/addons/sourcemod/data/sqlite/jjd_stats.sq3'
    with sqlite3.connect(database) as db:
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
        assert db.execute('SELECT version FROM schema_version').fetchone()[0]==1
        summary={'players':db.execute('SELECT COUNT(*) FROM players').fetchone()[0],'halves':db.execute('SELECT COUNT(*) FROM halves').fetchone()[0]}
    assert (stage/'custom/jjd_stats.smx').is_file()
    assert (stage/'steamcmd/l4d2/left4dead2/cfg/private_server.cfg').is_file()
    if args.verify_only:
        print(json.dumps({'isolated_restore_verified':True,**summary}));raise SystemExit
    assert os.geteuid()!=0,'Run restore as the game user'
    assert args.new_ip and re.fullmatch(r'[0-9a-fA-F:.]+',args.new_ip),'Provide --new-ip'
    assert (base/'steamcmd/l4d2/srcds_run').is_file(),'Install base game first with bootstrap-server.sh'
    assert not (base/'steamcmd/l4d2/left4dead2/addons/sourcemod').exists(),'Refusing to overwrite an existing mod installation'
    old_home=record.get('source_home','/home/l4d2')
    host=(stage/'steamcmd/l4d2/left4dead2/myhost.txt').read_text()
    old_ip=re.search(r'https?://([^/:]+)',host).group(1)
    for f in stage.rglob('*'):
        if f.is_file() and not f.is_symlink() and f.suffix in ('.py','.sh','.cfg','.conf','.service','.timer','.sp','.txt','.json','.html'):
            try:text=f.read_text()
            except UnicodeDecodeError:continue
            f.write_text(text.replace(old_home,str(base)).replace(old_ip,args.new_ip))
    import shutil
    shutil.copytree(stage,base,dirs_exist_ok=True,symlinks=True)
    (base/'steamcmd/l4d2/left4dead2/cfg/private_server.cfg').chmod(0o600)
    subprocess.run(['bash',str(base/'deploy/build-plugins.sh')],check=True)
    subprocess.run(['python3',str(base/'deploy/apply-customization.py')],check=True)
    units=base/'.config/systemd/user';units.mkdir(parents=True,exist_ok=True)
    for f in (base/'deploy').glob('l4d2-backup.*'):shutil.copy2(f,units/f.name)
    subprocess.run(['systemctl','--user','daemon-reload'],check=True)
    subprocess.run(['systemctl','--user','enable','--now','l4d2.service','l4d2-motd.service','l4d2-idle-check.timer','l4d2-backup.timer'],check=True)
    subprocess.run(['python3',str(base/'deploy/rcon.py'),'sm_jjd_stats_status'],check=True)
    print('RESTORED: verify public UDP 27015, HTTP 80, SSH and real multiplayer before opening.')
