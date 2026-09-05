#!/usr/bin/env python3
"""Local synthetic API for M2 device tests. No live credentials or Multica traffic."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class API(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    status = 200
    calls = []
    def log_message(self, *args): pass
    def reply(self, code, value):
        body=json.dumps(value).encode()
        self.send_response(code);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def do_POST(self):
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            chunks=[]
            while True:
                length=int(self.rfile.readline().split(b';')[0],16)
                if not length:
                    while self.rfile.readline().strip(): pass
                    break
                chunks.append(self.rfile.read(length)); self.rfile.read(2)
            raw=b''.join(chunks)
        else:
            raw=self.rfile.read(int(self.headers.get('Content-Length','0')))
        body=json.loads(raw or '{}')
        if self.path=='/__control':
            API.status=body['status'];return self.reply(200,{'ok':True})
        if self.path=='/auth/send-code':
            return self.reply(200,{'ok':True})
        if self.path=='/auth/verify-code':
            if body.get('code')!='123456':return self.reply(400,{'error':'invalid code'})
            return self.reply(200,{'token':'synthetic-device-fixture-token'})
        self.reply(404,{'error':'unknown fixture route'})
    def do_GET(self):
        if self.path=='/__calls':return self.reply(200,API.calls)
        if self.path=='/api/workspaces':
            valid=self.headers.get('Authorization')=='Bearer synthetic-device-fixture-token'
            API.calls.append({'route':self.path,'authenticated':valid,'workspace':self.headers.get('X-Workspace-Slug'),'status':API.status})
            if not valid:return self.reply(401,{'error':'invalid synthetic token'})
            if API.status!=200:return self.reply(API.status,{'error':'simulated failure'})
            return self.reply(200,[{'id':'w1','slug':'fixture','name':'Loop Test Workspace'}])
        self.reply(404,{'error':'unknown fixture route'})

ThreadingHTTPServer(('127.0.0.1',8765),API).serve_forever()
