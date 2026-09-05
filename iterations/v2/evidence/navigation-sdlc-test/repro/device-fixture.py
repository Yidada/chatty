"""Local-only extension of the existing fixture; no Multica requests."""
import importlib.util
from http.server import ThreadingHTTPServer
from pathlib import Path
root = Path(__file__).resolve().parents[5]
spec = importlib.util.spec_from_file_location('fixture', root/'scripts/chat-fixture.py')
f = importlib.util.module_from_spec(spec); spec.loader.exec_module(f)
f.AGENT.update(runtime_id='', runtime_bound=False)
class API(f.API):
    def do_POST(self):
        if self.path == '/__audit/bind-runtime':
            self.raw()
            f.AGENT.update(runtime_id='r1', runtime_bound=True)
            return self.reply(200, {'runtime_id':'r1','runtime_bound':True})
        return super().do_POST()
ThreadingHTTPServer(('127.0.0.1', 8875), API).serve_forever()
