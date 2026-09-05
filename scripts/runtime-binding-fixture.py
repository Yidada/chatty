#!/usr/bin/env python3
"""Isolated synthetic Runtime binding transitions; never contacts Multica."""
import importlib.util, json
from http.server import ThreadingHTTPServer
from pathlib import Path
spec = importlib.util.spec_from_file_location('fixture', Path(__file__).with_name('chat-fixture.py'))
f = importlib.util.module_from_spec(spec); spec.loader.exec_module(f)
f.AGENT.update(runtime_id='', runtime_bound=False)
agent_failure = False
class API(f.API):
    def do_POST(self):
        global agent_failure
        if self.path == '/__runtime':
            body = json.loads(self.raw())
            if 'bound' in body:
                f.AGENT.update(runtime_id='r1' if body['bound'] else '', runtime_bound=body['bound'])
            agent_failure = body.get('failure', False)
            return self.reply(200, {'runtime_bound':f.AGENT['runtime_bound']})
        return super().do_POST()
    def do_GET(self):
        if self.path == '/api/agents' and agent_failure:
            return self.reply(503, {'error':'synthetic agent context failure'})
        return super().do_GET()
ThreadingHTTPServer(('127.0.0.1', 8875), API).serve_forever()
