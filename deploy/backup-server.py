#!/usr/bin/env python3
"""Private full overlay + consistent SQLite snapshots; no base game or SSH keys."""
from pathlib import Path
import datetime,fcntl,hashlib,json,os,sqlite3,tarfile,tempfile
os.umask(0o077)
base=Path.home(); game=base/'steamcmd/l4d2/left4dead2'; directory=base/'restore-bundles'
directory.mkdir(mode=0o700,exist_ok=True)
lock=open(directory/'.backup.lock','w');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
archive=directory/f'jiaojiedi-full-{stamp}.tar.gz';partial=archive.with_suffix('.partial')
dbdir=game/'addons/sourcemod/data/sqlite'
paths=[game/x for x in ('addons','cfg','scripts','mymotd.txt','myhost.txt','banned_user.cfg','banned_ip.cfg')]
paths += [base/'custom',base/'deploy']
paths += [base/'l4d2-mod/addons/sourcemod/scripting'/x for x in ('sourcemod','include')]
paths += list((base/'.config/systemd/user').glob('l4d2*'))
def include(info):
    parts=Path(info.name).parts
    if any(p in ('logs','__pycache__','.git','.ssh','test-results') for p in parts):return None
    if '.reference.' in info.name or 'test-jjd-' in info.name:return None
    if '/data/sqlite/' in info.name:return None
    return info
with tempfile.TemporaryDirectory(dir=directory) as tmp:
    snapshots=[]
    for source in dbdir.glob('*.sq3'):
        target=Path(tmp)/source.name
        with sqlite3.connect(f'file:{source}?mode=ro',uri=True,timeout=30) as src,sqlite3.connect(target) as dst:
            src.backup(dst)
            assert dst.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
        snapshots.append((target,str(source.relative_to(base))))
    assert any(p.name=='jjd_stats.sq3' for p,_ in snapshots),'Stats database missing'
    with tarfile.open(partial,'w:gz') as bundle:
        for p in paths:
            if p.exists():bundle.add(p,arcname=str(p.relative_to(base)),filter=include)
        for p,name in snapshots:bundle.add(p,arcname=name)
    with tarfile.open(partial) as bundle:
        names=bundle.getnames()
        assert 'steamcmd/l4d2/left4dead2/addons/sourcemod/data/sqlite/jjd_stats.sq3' in names
    partial.replace(archive)
record={'format':2,'source_home':str(base),'path':str(archive),'filename':archive.name,'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'created_utc':stamp,'contains_secrets':True,'base_game_included':False,'sqlite_consistent':True,'members':len(names)}
(directory/(archive.name+'.json')).write_text(json.dumps(record,indent=2)+'\n')
temp=directory/'latest.json.tmp';temp.write_text(json.dumps(record,indent=2)+'\n');temp.replace(directory/'latest.json')
# One complete bundle per daily run; retain the newest 30 successful bundles.
for old in sorted(directory.glob('jiaojiedi-full-*.tar.gz'),reverse=True)[30:]:
    old.unlink();old.with_name(old.name+'.json').unlink(missing_ok=True)
print(json.dumps(record))
