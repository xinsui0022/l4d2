#!/usr/bin/env python3
"""Run a local SRCDS console command without exposing the RCON password."""
import argparse
import re
import socket
import struct
import time
from pathlib import Path

SECRET = Path('/home/l4d2/steamcmd/l4d2/left4dead2/cfg/private_server.cfg')

def packet(request_id, kind, text):
    body = struct.pack('<ii', request_id, kind) + text.encode() + b'\0\0'
    return struct.pack('<i', len(body)) + body

def exact(sock, size):
    data = b''
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError('RCON connection closed')
        data += chunk
    return data

def receive(sock):
    length = struct.unpack('<i', exact(sock, 4))[0]
    if not 10 <= length <= 4_194_304:
        raise ValueError('Invalid RCON packet size')
    payload = exact(sock, length)
    request_id, kind = struct.unpack('<ii', payload[:8])
    return request_id, kind, payload[8:-2].decode('utf-8', 'replace')

def run(command):
    password = re.search(r'^rcon_password\s+"([^"]+)"', SECRET.read_text(), re.M).group(1)
    with socket.create_connection(('127.0.0.1', 27015), timeout=4) as sock:
        sock.settimeout(4)
        sock.sendall(packet(1, 3, password))
        while True:
            rid, kind, _ = receive(sock)
            if rid == -1:
                raise PermissionError('RCON authentication failed')
            if kind == 2 and rid == 1:
                break
        sock.sendall(packet(2, 2, command))
        # A distinct request marks the end of multi-packet command output.
        sock.sendall(packet(3, 0, ''))
        result = []
        while True:
            try:
                rid, _, text = receive(sock)
            except (ConnectionError, socket.timeout):
                if command.split()[0].lower() in {'changelevel', 'map', 'quit', '_restart', 'sm_jjd_idle_check', 'sm_jjd_idle_restart', 'sm_jjd_newcampaign'}:
                    return ''.join(result) + 'Command sent; server closed the connection. Check status after the map change or shutdown.\n'
                raise
            if rid == 3:
                break
            if rid == 2:
                result.append(text)
        return ''.join(result)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--wait', type=int, default=0)
    parser.add_argument('command', nargs='+')
    args = parser.parse_args()
    deadline = time.monotonic() + args.wait
    while True:
        try:
            print(run(' '.join(args.command)), end='')
            return
        except (OSError, ValueError) as exc:
            if time.monotonic() >= deadline:
                parser.exit(1, f'RCON unavailable: {exc}\n')
            time.sleep(2)

if __name__ == '__main__':
    main()
