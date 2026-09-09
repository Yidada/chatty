#!/usr/bin/env python3
"""iOS V1 integration fixture. Independent accounts/workspaces; loopback only.
Inherits the existing Android protocol fixture without changing its behavior.
Control and audit routes are synthetic test interfaces, never a production API.
"""
import base64, hashlib, struct, socket
import importlib.util
import json
import re
import threading
import time
from email import policy
from email.parser import BytesParser
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs

SOURCE = Path(__file__).with_name('chat-fixture.py')
TOKENS = {'u1': 'synthetic-device-fixture-token', 'u2': 'synthetic-ios-other-token'}
WORKSPACES = [{'id':'w1','slug':'fixture','name':'Loop Test Workspace'}, {'id':'w2','slug':'fixture-two','name':'Second Test Workspace'}]
MODULES = {}
for user in TOKENS:
    for workspace in WORKSPACES:
        spec = importlib.util.spec_from_file_location('ios_' + user + workspace['id'], SOURCE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.TOKEN = TOKENS[user]
        module.AGENT['owner_id'] = user
        module.UPLOADS = {}
        module.OPTIONS = {}
        if workspace['id'] == 'w2':
            for row in module.MESSAGES: row['content'] = '第二工作区 · ' + row['content']
        MODULES[(user, workspace['slug'])] = module
BASE = MODULES[('u1','fixture')]
AUTH_CALLS = []
WS_EVENTS = []

class API(BASE.API):
    def owner(self):
        token = self.headers.get('Authorization','').removeprefix('Bearer ')
        return next((user for user, value in TOKENS.items() if value == token), 'u1')
    def module(self):
        query = parse_qs(urlsplit(self.path).query)
        slug = self.headers.get('X-Workspace-Slug') or query.get('workspace_slug',['fixture'])[0]
        return MODULES.get((self.owner(), slug), BASE)
    def auth(self):
        return self.module().API.auth(self)
    def raw(self):
        if hasattr(self, '_cached_raw'):
            value = self._cached_raw; del self._cached_raw; return value
        return BASE.API.raw(self)
    def reply(self, code, value, ctype='application/json'):
        path = urlsplit(self.path).path
        module = self.module()
        if self.command == 'POST' and re.fullmatch('/api/chat/sessions/[^/]+/messages',path) and code == 200:
            mode = module.OPTIONS.get('send_mode','normal')
            attachment_ids = getattr(self,'_attachment_ids',[])
            value = dict(value, attachment_ids=attachment_ids)
            for row in reversed(module.MESSAGES):
                if row['id'] == value.get('message_id'):
                    row['_upload_ids'] = attachment_ids
                    row['attachments'] = [module.UPLOADS[i][0] if i in module.UPLOADS else module.A for i in attachment_ids]
                    break
            if mode == 'malformed': value['task_id'] = ''
            elif mode == 'drop_attachments': value['attachment_ids'] = []
            elif mode == 'omit_attachment_receipt': value.pop('attachment_ids',None)
            elif mode == 'accepted_then_503': module.STATUS = 503
            elif mode == 'timeout': time.sleep(28)
        try: return BASE.API.reply(self,code,value,ctype)
        except (BrokenPipeError,ConnectionResetError): return
    def do_POST(self):
        raw = self.raw()
        path = urlsplit(self.path).path
        module = self.module()
        if path == '/api/upload-file':
            if not self.auth(): return
            document = BytesParser(policy=policy.default).parsebytes(('Content-Type: ' + self.headers.get('Content-Type','') + '\r\nMIME-Version: 1.0\r\n\r\n').encode() + raw)
            parts = list(document.iter_parts())
            part = next((p for p in parts if p.get_param('name',header='content-disposition') == 'file'),None)
            if part is None: return self.reply(400,{'error':'missing file'})
            data = part.get_payload(decode=True)
            if len(data) > 20*1024*1024: return self.reply(413,{'error':'too large'})
            key = 'upload-' + str(len(module.UPLOADS)+1)
            metadata = {'id':key,'filename':Path(part.get_filename() or 'upload.bin').name,'content_type':part.get_content_type(),'size_bytes':len(data),'download_url':'http://127.0.0.1:8765/api/attachments/'+key+'/download'}
            module.UPLOADS[key] = (metadata,data)
            return self.reply(200,metadata)
        body = json.loads(raw or '{}')
        if path.startswith('/auth/'):
            AUTH_CALLS.append({'path':path,'authorization_header_present':bool(self.headers.get('Authorization'))})
            if path == '/auth/send-code': return self.reply(200,{'ok':True})
            if path == '/auth/verify-code':
                if body.get('code') != '123456': return self.reply(400,{'error':'invalid code'})
                user = 'u2' if 'other' in body.get('email','') else 'u1'
                return self.reply(200,{'token':TOKENS[user]})
        if path == '/__control':
            module.OPTIONS.update({key:body[key] for key in ('send_mode','catalog_status','issue_conflict','deny_mika') if key in body})
            if 'deny_mika' in body: module.AGENT['owner_id'] = 'unrelated-user' if body['deny_mika'] else self.owner()
        self._attachment_ids = body.get('attachment_ids',[])
        self._cached_raw = raw
        return module.API.do_POST(self)
    def do_GET(self):
        path = urlsplit(self.path).path
        module = self.module()
        if path == '/__calls':
            scopes = {user + ':' + slug: {'calls':m.CALLS,'send_count':m.SEND_COUNT,'issue_writes':m.WRITES,'active_sockets':len(m.CLIENTS),'uploads':[a[0] for a in m.UPLOADS.values()]} for (user,slug),m in MODULES.items()}
            return self.reply(200,{'scopes':scopes,'auth_calls':AUTH_CALLS,'ws_events':WS_EVENTS})
        if path in ('/api/workspaces','/api/me') or path in ('/api/workspaces/w1/members','/api/workspaces/w2/members'):
            if not self.auth(): return
            if module.STATUS != 200: return self.reply(module.STATUS,{'error':'synthetic failure'})
            if path == '/api/workspaces': return self.reply(200,WORKSPACES)
            if path == '/api/me': return self.reply(200,{'id':self.owner(),'email':self.owner()+'@example.test','name':'Synthetic User'})
            return self.reply(200,[{'user_id':self.owner(),'role':'member'}])
        if path == '/api/issue-statuses' and module.OPTIONS.get('catalog_status',200) != 200:
            if not self.auth(): return
            return self.reply(module.OPTIONS['catalog_status'],{'error':'status catalog unavailable'})
        match = re.fullmatch('/api/attachments/(upload-\d+)(/download|/content)?',path)
        if match:
            if not self.auth(): return
            value = module.UPLOADS.get(match[1])
            if not value: return self.reply(404,{'error':'missing upload'})
            return self.reply(200,value[1],value[0]['content_type']) if match[2] else self.reply(200,value[0])
        # Include actual uploaded metadata in authoritative message responses.
        if path.endswith('/messages/page'):
            for row in module.MESSAGES:
                if row.get('_upload_ids'):
                    row['attachments'] = [module.UPLOADS[i][0] for i in row['_upload_ids'] if i in module.UPLOADS]
        return module.API.do_GET(self)
    def do_PUT(self):
        module = self.module()
        if module.OPTIONS.get('issue_conflict'):
            self.raw()
            if not self.auth(): return
            row = next((r for r in module.ISSUES if r['id'] == self.path.rsplit('/',1)[-1]),None)
            if row: row['revision'] += 1
            return self.reply(409,{'error':'stale revision'})
        return module.API.do_PUT(self)
    def websocket(self):
        slug = parse_qs(urlsplit(self.path).query).get('workspace_slug',['fixture'])[0]
        key = self.headers.get('Sec-WebSocket-Key','')
        accept = base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        self.send_response(101); self.send_header('Upgrade','websocket'); self.send_header('Connection','Upgrade'); self.send_header('Sec-WebSocket-Accept',accept); self.end_headers()
        module = None
        WS_EVENTS.append({'event':'open','workspace':slug,'token_in_url':'token=' in self.path})
        try:
            while True:
                head = self.rfile.read(2)
                if len(head) != 2: return
                opcode, length = head[0]&15, head[1]&127
                if length == 126: length = struct.unpack('!H',self.rfile.read(2))[0]
                elif length == 127: length = struct.unpack('!Q',self.rfile.read(8))[0]
                if length > 1024*1024: return
                mask = self.rfile.read(4) if head[1]&128 else b''
                data = self.rfile.read(length)
                if mask: data = bytes(b^mask[i%4] for i,b in enumerate(data))
                if opcode == 8: return
                if opcode == 9: self.connection.sendall(bytes([0x8a,len(data)])+data); continue
                if opcode == 1 and module is None:
                    auth = json.loads(data)
                    user = next((u for u,t in TOKENS.items() if auth.get('payload',{}).get('token') == t), None)
                    if auth.get('type') != 'auth' or user is None: return
                    module = MODULES.get((user,slug))
                    if module is None: return
                    with module.LOCK: module.CLIENTS.append(self.connection)
                    WS_EVENTS.append({'event':'authenticated','workspace':slug,'user':user,'active_in_scope':len(module.CLIENTS),'active_total':sum(len(m.CLIENTS) for m in MODULES.values())})
                    module.broadcast('auth_ack',{})
        except (OSError,ValueError,AssertionError): pass
        finally:
            if module:
                with module.LOCK:
                    if self.connection in module.CLIENTS: module.CLIENTS.remove(self.connection)
            WS_EVENTS.append({'event':'close','workspace':slug})

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1',8765), API).serve_forever()
