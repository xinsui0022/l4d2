#!/usr/bin/env python3
"""Serve only the three public game welcome assets on loopback."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path('/home/l4d2/custom/motd')
ASSETS = {'/welcome.html': 'text/html; charset=utf-8',
          '/banner.html': 'text/html; charset=utf-8', '/wallpaper.png': 'image/png'}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.serve(False)

    def do_HEAD(self):
        self.serve(True)

    def serve(self, head):
        path = urlsplit(self.path).path
        if path not in ASSETS:
            self.send_error(404)
            return
        data = (ROOT / path[1:]).read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', ASSETS[path])
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'public, max-age=3600' if path.endswith('.png') else 'no-cache')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        if not head:
            self.wfile.write(data)

    def log_message(self, fmt, *args):
        pass

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 18080), Handler).serve_forever()
