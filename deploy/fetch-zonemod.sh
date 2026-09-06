#!/usr/bin/env bash
set -euo pipefail
test "$(id -un)" = l4d2
base=/home/l4d2
mkdir -p "$base/downloads" "$base/l4d2-mod"
curl -fLSs --retry 3 --connect-timeout 15 --max-time 90 https://api.github.com/repos/SirPlease/L4D2-Competitive-Rework/commits/master -o "$base/downloads/competitive-commit.json"
commit=$(python3 -c 'import json; print(json.load(open("/home/l4d2/downloads/competitive-commit.json"))["sha"])')
[[ "$commit" =~ ^[0-9a-f]{40}$ ]]
printf '%s\n' "$commit" > "$base/downloads/competitive-commit.txt"
archive="$base/downloads/competitive-$commit.tar.gz"
curl -fLSs --retry 3 --connect-timeout 15 --max-time 600 "https://codeload.github.com/SirPlease/L4D2-Competitive-Rework/tar.gz/$commit" -o "$archive"
sha256sum "$archive" > "$archive.sha256"
tar -xzf "$archive" -C "$base/l4d2-mod" --strip-components=1
grep -n 'Zonemod' "$base/l4d2-mod/README.md"
echo 'ZONEMOD_FETCH_COMPLETE'
