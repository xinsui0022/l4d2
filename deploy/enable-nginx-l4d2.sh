#!/usr/bin/env bash
# Add the /l4d2/ reverse-proxy route to the default nginx site. Run as root. Idempotent.
# Mirrors the nginx step from bootstrap-server.sh (which stopped early on this host).
set -euo pipefail
test "$(id -u)" = 0
site_avail=/etc/nginx/sites-available/default
test -f "$site_avail"
if grep -q 'location /l4d2/' /etc/nginx/sites-enabled/default 2>/dev/null; then
  echo "Route already present; leaving as-is."
else
  python3 - <<'PY'
from pathlib import Path
p = Path('/etc/nginx/sites-available/default')
s = p.read_text()
needle = 'server {'
assert s.count(needle) >= 1, 'no server block found in default site'
s = s.replace(needle, needle + '\n    location /l4d2/ { proxy_pass http://127.0.0.1:18080/; }', 1)
p.write_text(s)
print('Added /l4d2/ route to', p)
PY
fi
nginx -t
systemctl reload nginx
echo "nginx /l4d2/ route active; welcome page should serve at http://<public-ip>/l4d2/welcome.html"
