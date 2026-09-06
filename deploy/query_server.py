#!/usr/bin/env python3
"""Read a Source server's public A2S_INFO response with challenge support."""
import argparse
import json
import socket
import struct

def query(host, port):
    request = b'\xff\xff\xff\xffTSource Engine Query\x00'
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(5)
        sock.connect((host, port))
        sock.send(request)
        data = sock.recv(65535)
        if data[:5] == b'\xff\xff\xff\xffA':
            sock.send(request + data[5:9])
            data = sock.recv(65535)
    if data[:5] != b'\xff\xff\xff\xffI':
        raise ValueError('Unexpected Source server response')
    offset = 6
    def string():
        nonlocal offset
        end = data.index(b'\0', offset)
        value = data[offset:end].decode('utf-8', 'replace')
        offset = end + 1
        return value
    result = {'host': host, 'port': port, 'name': string(), 'map': string(),
              'folder': string(), 'game': string()}
    result['appid'] = struct.unpack_from('<H', data, offset)[0]
    offset += 2
    result.update(zip(('players', 'max_players', 'bots'), data[offset:offset+3]))
    offset += 3
    result['server_type'] = chr(data[offset])
    result['os'] = chr(data[offset + 1])
    result['password_required'] = bool(data[offset + 2])
    result['vac'] = bool(data[offset + 3])
    offset += 4
    result['version'] = string()
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('host')
    parser.add_argument('port', nargs='?', type=int, default=27015)
    args = parser.parse_args()
    print(json.dumps(query(args.host, args.port), ensure_ascii=False, indent=2))
