#!/usr/bin/env python3
"""Idempotent public discovery settings shared by installation and updates."""
import re
from pathlib import Path

SETTINGS = {
    'hostname': '"[CN] 纯净药抗"',
    'sv_lan': '0',
    'sv_password': '""',
    'sv_allow_lobby_connect_only': '0',
    'sv_steamgroup_exclusive': '0',
    'sv_region': '4',
    'sv_tags': '"jiaojiedi,zonemod,versus"',
    'sv_search_key': '""',
}


def configure_public(text):
    lines = []
    seen = set()
    for line in text.splitlines():
        match = re.match(r'^\s*(\w+)\s+', line)
        key = match.group(1) if match else None
        if key in SETTINGS:
            if key not in seen:
                lines.append(key + ' ' + SETTINGS[key])
                seen.add(key)
        else:
            lines.append(line)
    lines.extend(key + ' ' + value for key, value in SETTINGS.items() if key not in seen)
    return '\n'.join(lines) + '\n'


def apply_public_settings(path):
    path = Path(path)
    original = path.read_text(encoding='utf-8')
    updated = configure_public(original)
    if original != updated:
        path.write_text(updated, encoding='utf-8')


if __name__ == '__main__':
    apply_public_settings(Path.home() / 'steamcmd/l4d2/left4dead2/cfg/server.cfg')
