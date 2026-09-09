#!/usr/bin/env bash
set -euo pipefail
base=/home/l4d2
sdk="$base/l4d2-mod/addons/sourcemod/scripting"
for plugin in jjd_join_info jjd_server jjd_tank_tools jjd_stats jjd_visuals jjd_fun l4d2_tankrage jjd_friendly_fire jjd_player_info l4d2_playstats l4d2_unsilent_jockey; do
  "$sdk/sourcemod/spcomp" "$base/custom/scripting/$plugin.sp" "-i$sdk/sourcemod/include" "-i$sdk/include" "-o$base/custom/$plugin.smx"
done
