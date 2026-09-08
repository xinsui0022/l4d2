#!/usr/bin/env python3
"""Read existing Source engine connection logs; never display player IP addresses."""
import argparse
from datetime import datetime, timedelta
import json
from pathlib import Path
import re
import sys
import time
from rcon import run

BASE=Path.home()
GAME=BASE/'steamcmd/l4d2/left4dead2'
LINE=re.compile(r'^L (\d{2}/\d{2}/\d{4} - \d{2}:\d{2}:\d{2}): "([^"\r\n]{0,128}?)<(\d+)><(STEAM_[01]:[01]:\d+)><[^>]*>" (.*)$')
def clean(text):return ''.join(c if ord(c)>=32 and not 127<=ord(c)<160 else ' ' for c in text)
def normalize(steam):return 'STEAM_1:'+steam.split(':',1)[1]
def admins():
    text=(GAME/'addons/sourcemod/configs/admins_simple.ini').read_text(errors='replace')
    return {normalize(x) for x in re.findall(r'^\s*"(STEAM_[01]:[01]:\d+)"\s+"(?:\d+:)?[^"\n]*z[^"\n]*"',text,re.M)}

class Reader:
    def __init__(self,days):
        self.since=datetime.now()-timedelta(days=days) if days else datetime.min
        self.files={};self.events={}
    def update(self):
        for path in (GAME/'logs').glob('*.log'):
            stat=path.stat()
            if datetime.fromtimestamp(stat.st_mtime)<self.since:continue
            state=self.files.get(path,(stat.st_ino,0,b''))
            inode,offset,pending=state
            if inode!=stat.st_ino or stat.st_size<offset:offset=0;pending=b''
            if stat.st_size==offset:continue
            with path.open('rb') as f:f.seek(offset);blob=f.read()
            lines=(pending+blob).split(b'\n')
            self.files[path]=(stat.st_ino,offset+len(blob),lines.pop())
            for raw in lines:
                match=LINE.match(raw.decode('utf-8','replace').rstrip('\r'))
                if not match:continue
                stamp,name,userid,steam,tail=match.groups()
                stamp=datetime.strptime(stamp,'%m/%d/%Y - %H:%M:%S')
                if stamp<self.since:continue
                if tail.startswith('entered the game'):event='entered'
                elif tail.startswith('connected,'):event='connected'
                elif tail.startswith('disconnected'):event='left'
                elif 'STEAM USERID validated' in tail:event='authenticated'
                else:continue
                item=dict(time=stamp.isoformat(sep=' '),name=clean(name),steam=normalize(steam),event=event)
                self.events[(stamp,steam,userid,event,name)]=item
        return sorted(self.events.values(),key=lambda x:x['time'])

def online():
    text=run('status');result=[]
    for line in text.splitlines():
        match=re.match(r'^#\s+\d+\s+"(.*)"\s+(\S+)',line)
        if match and match[2]!='BOT':result.append(dict(name=clean(match[1]),steam=match[2]))
    return result

def report(events):
    owners=admins();players={}
    for event in events:
        item=players.setdefault(event['steam'],dict(steam=event['steam'],names=[],first=event['time'],last=event['time'],entered_events=0,administrator=event['steam'] in owners))
        if event['name'] not in item['names']:item['names'].append(event['name'])
        item['last']=event['time']
        if event['event']=='entered':item['entered_events']+=1
    online_error=None
    try:current=online()
    except (OSError,ValueError) as error:current=[];online_error=str(error)
    return dict(checked_at=datetime.now().isoformat(sep=' ',timespec='seconds'),online=current,online_error=online_error,players=list(players.values()),recent=events[-20:],non_admin_unique=sum(not p['administrator'] for p in players.values()))

LABEL={'entered':'进入游戏','connected':'建立连接','authenticated':'身份认证','left':'离开'}
def event_line(item):return f"{item['time']}  {LABEL[item['event']]}  {item['name']}  [{item['steam']}]"
def show(data):
    print(f"\n交界地玩家记录 · {data['checked_at']}（服务器当地时间）")
    print('当前在线暂时无法查询：'+data['online_error'] if data['online_error'] else '当前真人：'+str(len(data['online'])))
    for player in data['online']:print(f"  {player['name']} [{player['steam']}]")
    print(f"日志内认证玩家：{len(data['players'])}；非管理员：{data['non_admin_unique']}")
    for player in data['players']:
        print(f"  {' / '.join(player['names'])} [{player['steam']}] {'管理员' if player['administrator'] else '玩家'}")
        print(f"    首次 {player['first']}；最近 {player['last']}；进入事件 {player['entered_events']}")
    print('最近事件（机器人不计入；换图可能产生新的进入事件，不等同于独立访问次数）：')
    for event in data['recent']:print('  '+event_line(event))
    print('只依据仍保留的日志；没有记录不能证明从未连接。玩家 IP 不显示。')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--days',type=int,default=7,help='0 reads all retained logs')
    parser.add_argument('--watch',action='store_true')
    parser.add_argument('--json',action='store_true')
    args=parser.parse_args()
    if not 0<=args.days<=3650:parser.error('--days must be 0..3650')
    sys.stdout.reconfigure(encoding='utf-8',errors='replace',line_buffering=True)
    reader=Reader(args.days);events=reader.update();data=report(events)
    if args.json:print(json.dumps(data,ensure_ascii=False,indent=2));return
    show(data)
    if not args.watch:return
    print('\n实时查看已启动：每 5 秒检查新增事件及在线变化；按 Ctrl+C 退出。')
    seen=set(reader.events);previous=data['online']
    while True:
        time.sleep(5)
        try:
            reader.update()
            for key,item in reader.events.items():
                if key not in seen:print(event_line(item));seen.add(key)
            current=online()
            if current!=previous:
                print(f"当前在线 {len(current)}："+'、'.join(p['name'] for p in current));previous=current
        except (OSError,ValueError) as error:print('暂时无法读取服务器，5 秒后重试：'+str(error))

if __name__=='__main__':
    try:main()
    except KeyboardInterrupt:print('\n已停止查看。')
