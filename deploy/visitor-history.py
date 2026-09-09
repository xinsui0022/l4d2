#!/usr/bin/env python3
"""Private join history, including full IP; read through SSH only."""
import argparse
from contextlib import closing
from datetime import datetime
from pathlib import Path
import sqlite3
import time

def clean(value):
    return ''.join(c if c.isprintable() else ' ' for c in str(value))

def read_rows(path, days, limit):
    if not path.exists():
        return []
    since = int(time.time()) - days * 86400 if days else 0
    with closing(sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=5)) as db:
        return db.execute('SELECT id,timestamp,name,steam,ip,location,map FROM visits WHERE timestamp>=? ORDER BY id DESC LIMIT ?', (since, limit)).fetchall()[::-1]

def show(row):
    _, stamp, name, steam, ip, location, map_name = row
    print(f'{datetime.fromtimestamp(stamp):%Y-%m-%d %H:%M:%S} | {clean(name)} | {clean(steam)} | {clean(ip)} | {clean(location)} | {clean(map_name)}', flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--days', type=int, default=7)
    parser.add_argument('--limit', type=int, default=200)
    parser.add_argument('--watch', action='store_true')
    args = parser.parse_args()
    if not 0 <= args.days <= 3650 or not 1 <= args.limit <= 100000:
        parser.error('days must be 0..3650 and limit 1..100000')
    path = Path.home() / 'steamcmd/l4d2/left4dead2/addons/sourcemod/data/sqlite/jjd_visitors.sq3'
    print('加入历史（服务器当地时间；完整 IP 仅供管理员查询）', flush=True)
    rows = read_rows(path, args.days, args.limit)
    for row in rows: show(row)
    if not rows: print('此时间范围暂无记录；仅记录插件启用后的真人加入。', flush=True)
    last = rows[-1][0] if rows else 0
    while args.watch:
        time.sleep(5)
        for row in read_rows(path, args.days, args.limit):
            if row[0] > last: show(row); last = row[0]

if __name__ == '__main__':
    try: main()
    except KeyboardInterrupt: pass
