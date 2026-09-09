#!/usr/bin/env bash
# New Ubuntu 24.04 (Noble) x86_64 machine only. Run as root: bash bootstrap-server-ubuntu24.sh GAME_USER
# Adapted from deploy/bootstrap-server.sh. Only these changes vs. the 22.04 original:
#   - VERSION_ID check 22.04 -> 24.04
#   - added explicit x86_64 architecture check
#   - i386 dependency libcurl3-gnutls:i386 -> libcurl3t64-gnutls:i386 (Noble t64 transition)
# All other behavior (user creation guard, no-sudo, linger, SteamCMD windows+linux passes,
# App 222860 base game, nginx /l4d2/ location guard) is preserved from the original.
set -euo pipefail
test "$(id -u)" = 0
game_user=${1:?Specify game username}
[[ "$game_user" =~ ^[a-z][a-z0-9_-]{0,30}$ ]]
. /etc/os-release
test "$ID" = ubuntu
test "$VERSION_ID" = 24.04
test "$(uname -m)" = x86_64
dpkg --add-architecture i386
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates python3 sqlite3 nginx lib32gcc-s1 lib32stdc++6 libc6:i386 libstdc++6:i386 libcurl3t64-gnutls:i386
id "$game_user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$game_user"
game_home=$(getent passwd "$game_user" | cut -d: -f6)
test ! -d "$game_home/steamcmd/l4d2/left4dead2/addons/sourcemod"
loginctl enable-linger "$game_user"
runuser -u "$game_user" -- mkdir -p "$game_home/steamcmd" "$game_home/logs"
runuser -u "$game_user" -- curl -fL --retry 3 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -o "$game_home/steamcmd/steamcmd.tar.gz"
runuser -u "$game_user" -- tar -xzf "$game_home/steamcmd/steamcmd.tar.gz" -C "$game_home/steamcmd"
for platform in windows linux; do
  runuser -u "$game_user" -- "$game_home/steamcmd/steamcmd.sh" +force_install_dir "$game_home/steamcmd/l4d2" +login anonymous +@sSteamCmdForcePlatformType "$platform" +app_update 222860 validate +quit
done
# Dedicated location snippet; avoid replacing an existing site's configuration.
if test -f /etc/nginx/sites-enabled/default && ! grep -q 'location /l4d2/' /etc/nginx/sites-enabled/default; then
  python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-available/default');s=p.read_text();needle='server {'
assert s.count(needle)>=1
s=s.replace(needle,needle+'\n location /l4d2/ { proxy_pass http://127.0.0.1:18080/; }',1);p.write_text(s)
PY
fi
nginx -t
systemctl reload nginx
echo "Base installed. Install/confirm the SSH public key for $game_user, log in as that user and run restore-server.py. Allow cloud firewall UDP 27015, TCP 80 and your SSH port."
