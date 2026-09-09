#!/usr/bin/env bash
# Finish the L4D2 dedicated server (App 222860) base install as the game user.
# Idempotent: SteamCMD `validate` resumes/repairs, so re-runs are safe.
# Leads with the plain Linux pass (modern SteamCMD default); falls back to the
# historical windows-then-linux workaround only if Linux keeps failing.
set -uo pipefail
cd "$HOME/steamcmd"
log="$HOME/steamcmd/install.log"
: > "$log"
ok() { [ -f "$HOME/steamcmd/l4d2/srcds_run" ]; }

for i in $(seq 1 6); do
  echo "=== linux attempt $i $(date -u +%FT%TZ) ===" >> "$log"
  ./steamcmd.sh +force_install_dir "$HOME/steamcmd/l4d2" +login anonymous +app_update 222860 validate +quit >> "$log" 2>&1
  echo "rc=$? $(date -u +%FT%TZ)" >> "$log"
  if ok; then echo "INSTALL_OK_LINUX $(date -u +%FT%TZ)" >> "$log"; exit 0; fi
  sleep 8
done

echo "=== fallback: windows pass then linux $(date -u +%FT%TZ) ===" >> "$log"
for plat in windows linux; do
  for i in $(seq 1 4); do
    echo "=== $plat attempt $i $(date -u +%FT%TZ) ===" >> "$log"
    ./steamcmd.sh +@sSteamCmdForcePlatformType "$plat" +force_install_dir "$HOME/steamcmd/l4d2" +login anonymous +app_update 222860 validate +quit >> "$log" 2>&1
    rc=$?
    echo "rc=$rc $(date -u +%FT%TZ)" >> "$log"
    if [ "$plat" = linux ] && ok; then echo "INSTALL_OK_FALLBACK $(date -u +%FT%TZ)" >> "$log"; exit 0; fi
    [ $rc -eq 0 ] && break
    sleep 8
  done
done

if ok; then echo "INSTALL_OK_LATE $(date -u +%FT%TZ)" >> "$log"; exit 0; fi
echo "INSTALL_FAILED $(date -u +%FT%TZ)" >> "$log"
exit 1
