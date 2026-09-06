#!/usr/bin/env bash
set -euo pipefail
test "$(id -un)" = l4d2
base=/home/l4d2
game="$base/steamcmd/l4d2"
mkdir -p "$base/deploy" "$base/downloads" "$base/logs"
test "$(readlink -f "$game")" = /home/l4d2/steamcmd/l4d2
# Initial base installation only. Legacy migration/backup code was retired
# after the user confirmed that old server files are reference-only.
if test -d "$game/left4dead2/addons/sourcemod"; then
  echo 'An active mod installation exists. Follow the documented update procedure instead of rerunning initial setup.' >&2
  exit 1
fi
chmod u+x "$base/steamcmd/steamcmd.sh" "$base/steamcmd/linux32/steamcmd"
cd "$base/steamcmd"
# The upstream Competitive Rework install guide uses a Windows pass before
# Linux to handle Valve's "Invalid platform" dedicated-server metadata.
./steamcmd.sh +force_install_dir "$game" +login anonymous +@sSteamCmdForcePlatformType windows +app_update 222860 validate +quit
./steamcmd.sh +force_install_dir "$game" +login anonymous +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit
echo 'BASE_INSTALL_COMPLETE'
