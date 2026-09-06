#!/usr/bin/env bash
set -euo pipefail
base=/home/l4d2
sdk="$base/l4d2-mod/addons/sourcemod/scripting"
for plugin in jjd_server jjd_tank_tools jjd_stats; do
  "$sdk/sourcemod/spcomp" "$base/custom/scripting/$plugin.sp" "-i$sdk/sourcemod/include" "-i$sdk/include" "-o$base/custom/$plugin.smx"
done
