#!/usr/bin/env python3
"""Create a private portable overlay backup, excluding base game and SSH keys."""
from pathlib import Path
import datetime, hashlib, json, tarfile
base=Path('/home/l4d2')
game=base/'steamcmd/l4d2/left4dead2'
stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
directory=base/'restore-bundles'
directory.mkdir(mode=0o700,exist_ok=True)
archive=directory/f'jiaojiedi-restore-{stamp}.tar.gz'
paths=[game/x for x in ('addons','cfg','scripts','mymotd.txt','myhost.txt','banned_user.cfg','banned_ip.cfg')]
paths += [base/'custom',base/'deploy']
paths += list((base/'.config/systemd/user').glob('l4d2*'))
def included(info):
    pieces=Path(info.name).parts
    if any(p in ('logs','__pycache__','.git','.ssh') for p in pieces): return None
    if '.reference.' in info.name or 'test-jjd-' in info.name: return None
    return info
with tarfile.open(archive,'w:gz') as bundle:
    for path in paths:
        if path.exists():bundle.add(path,arcname=str(path.relative_to(base)),filter=included)
archive.chmod(0o600)
with tarfile.open(archive) as bundle:
    names=bundle.getnames()
    assert 'steamcmd/l4d2/left4dead2/cfg/private_server.cfg' in names
    assert 'custom/scripting/jjd_tank_tools.sp' in names
    assert not any('.ssh' in Path(n).parts for n in names)
record={'path':str(archive),'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'members':len(names),'contains_secrets':True,'base_game_included':False}
(directory/'latest.json').write_text(json.dumps(record,indent=2)+'\n')
(directory/'latest.json').chmod(0o600)
print(json.dumps(record))
