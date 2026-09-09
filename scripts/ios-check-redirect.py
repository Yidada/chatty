#!/usr/bin/env python3
"""Exercise the default FixtureClient and production APIClient against a real loopback redirect.
Requires port 8765 to be free. Never stops an existing service.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import subprocess
import threading

root = Path(__file__).resolve().parents[1]
calls = []

class RedirectHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        calls.append(self.path)
        self.send_response(302 if self.path == '/api/projects' else 200)
        if self.path == '/api/projects':
            self.send_header('Location', 'http://127.0.0.1:8765/redirect-sink')
        self.end_headers()
        self.wfile.write(b'{"projects":[],"total":0}')

    def log_message(self, *_args):
        pass

try:
    server = ThreadingHTTPServer(('127.0.0.1', 8765), RedirectHandler)
except OSError as error:
    raise SystemExit('Port 8765 must be free. Stop only your own chat-fixture process before this check.') from error

thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    subprocess.run([
        'swift', 'run', '--package-path', str(root / 'ios/Verification/RedirectProbe'),
        '--scratch-path', str(root / '.tools/ios-redirect-build'), 'RedirectProbe'
    ], cwd=root, check=True)
    assert calls == ['/api/projects', '/api/projects'], f'Redirect was followed or request changed: {calls}'
    print(json.dumps({'outcome': 'pass', 'status': 302, 'requests': calls, 'redirect_sink_requests': 0}))
finally:
    server.shutdown()
    server.server_close()
    thread.join()
