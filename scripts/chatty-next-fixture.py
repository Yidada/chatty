#!/usr/bin/env python3
"""Offline dsh-shaped UI fixture for ChattyNextFixture; synthetic content, loopback only."""
import base64
import hashlib
import json
import socket
import struct
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

LOCK = threading.RLock()
MODEL = {'provider': 'fixture', 'model': 'demo'}
WORKSPACE = {'workspaceId': 'fixture', 'title': '演示目录', 'path': '/tmp/chatty-next-fixture', 'sessionIds': [], 'createdAt': '', 'updatedAt': ''}
SESSIONS, CLIENTS = {}, []

def session(sid):
    return SESSIONS.setdefault(sid, {'events': [], 'revision': 0, 'attempt': None, 'running': False, 'stream': [], 'nextIndex': 0, 'turn': 0, 'model': MODEL.copy(), 'title': '演示对话'})

def emit(endpoint, value, sid=None):
    for client in list(CLIENTS):
        for stream, (kind, target) in list(client.streams.items()):
            if kind == endpoint and (sid is None or target == sid):
                client.send_ws({'type': 'item', 'streamId': stream, 'value': value})

def event(sid, kind, data):
    s = session(sid)
    e = {'seq': len(s['events']), 'type': kind, 'time': int(time.time() * 1000), 'data': data}
    if kind in ('user/message', 'assistant/message'): e['surfaceOp'] = 'append'
    s['events'].append(e); emit('session/follow', {'type': 'event', 'event': e}, sid)
    return e['seq']

def answer(sid, request):
    with LOCK:
        s = session(sid); token = str(uuid.uuid4()); s['attempt'] = token; s['running'] = True
        event(sid, 'user/message', {'id': request['requestId'], 'role': 'user', 'source': {'kind': 'user', 'rpcId': request['requestId']}, 'content': request['content']})
        emit('$events', {'type': 'emit', 'event': 'api-session/status', 'args': [sid, True]})
        s['revision'] += 1
        emit('session/follow', {'type': 'assistant-stream', 'frame': {'type': 'start', 'attemptId': token, 'revision': s['revision'], 'turn': len(s['events']), 'step': 0, 'startedAfterSeq': len(s['events']) - 1}}, sid)
        turn = len(s['events']); s['turn'] = turn; s['stream'] = []; s['nextIndex'] = 0
    parts = ['这是本地演示回答。\n\n', '## 原生体验\n\n', '| 项目 | 状态 |\n|---|---|\n', '| 文字 | 可用 |\n', '| 流式 | 可用 |\n', '\n```swift\nlet chatty = "Next"\n```']
    received = []
    for index, text in enumerate(parts):
        time.sleep(0.3)
        with LOCK:
            if s['attempt'] != token: return
            s['revision'] += 1; received.append(text); s['nextIndex'] = index + 1
            s['stream'].append({'type': 'chunk', 'time': int(time.time() * 1000), 'chunk': {'type': 'text-delta', 'index': 0, 'text': text}})
            emit('session/follow', {'type': 'assistant-stream', 'frame': {'type': 'chunk', 'attemptId': token, 'revision': s['revision'], 'index': index, 'chunk': {'type': 'text-delta', 'index': 0, 'text': text}}}, sid)
    with LOCK:
        seq = event(sid, 'assistant/message', {'turn': turn, 'step': 0, 'message': {'content': [{'type': 'text', 'text': ''.join(received)}]}})
        s['revision'] += 1; s['attempt'] = None; s['running'] = False
        emit('session/follow', {'type': 'assistant-stream', 'frame': {'type': 'end', 'attemptId': token, 'revision': s['revision'], 'index': len(parts), 'outcome': {'kind': 'committed', 'seq': seq}}}, sid)
        emit('$events', {'type': 'emit', 'event': 'api-session/status', 'args': [sid, False]})

class API(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *_): pass
    def reply(self, body, status=200):
        data = json.dumps(body, ensure_ascii=False).encode(); self.send_response(status); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data)
    def authorized(self): return self.headers.get('Cookie') == 'fixture=next'
    def do_POST(self):
        if not self.authorized(): return self.reply({}, 401)
        body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        method = urlsplit(self.path).path.removeprefix('/api/'); request = body.get('payload', {}).get('args', {}).get('request', {})
        with LOCK:
            sid = request.get('sessionId', ''); s = session(sid) if sid else None
            if method == 'session/modelCatalog': value = {'default': MODEL, 'groups': [{'id': 'fixture', 'name': '本地演示', 'models': [{'id': 'demo', 'name': '演示模型'}]}]}
            elif method == 'session/list': value = {'items': [{'sessionId': key, 'updatedAt': 1, 'running': item['running'], 'cwd': WORKSPACE['path'], 'projections': {'values': {'title': item['title']}}} for key, item in SESSIONS.items()]}
            elif method == 'session/create': value = {'sessionId': sid}
            elif method == 'session/selectModel': s['model'] = {k: request[k] for k in ('provider', 'model')}; value = {'selected': s['model']}
            elif method == 'session/prompt':
                if s['running']: return self.reply({'type': 'server-response', 'rpcId': body['rpcId'], 'result': {'ok': False, 'error': {'code': 'fixture/busy', 'message': '演示请等待当前回答结束'}}})
                threading.Thread(target=answer, args=(sid, request), daemon=True).start(); value = {'accepted': True}
            elif method == 'session/cancel':
                s['attempt'] = None; s['running'] = False
                # End existing streams; a fresh snapshot is the recovery authority.
                for client in list(CLIENTS):
                    for key, (kind, target) in list(client.streams.items()):
                        if kind == 'session/follow' and target == sid: client.send_ws({'type': 'end', 'streamId': key}); client.streams.pop(key, None)
                emit('$events', {'type': 'emit', 'event': 'api-session/status', 'args': [sid, False]}); value = {}
            elif method == 'session/search': value = {'items': [{'sessionId': k, 'snippet': v['title']} for k, v in SESSIONS.items() if request.get('query', '') in v['title']], 'hasMore': False}
            elif method == 'session/rename': s['title'] = request['title']; value = {}
            elif method == 'commands/execute':
                args = body['payload']['args']
                valid = args.get('line') == '/chatty-review' and args.get('agentId') in SESSIONS and args.get('submittedAttachments') == []
                value = {'commandId': 'fixture-review', 'result': {'kind': 'success' if valid else 'error', 'text': 'chatty-next:approve-for-me-v1' if valid else 'invalid command'}}
            else: return self.reply({'type': 'server-response', 'rpcId': body['rpcId'], 'result': {'ok': False, 'error': {'code': 'fixture/unsupported', 'message': '此本地演示未覆盖该方法'}}})
        self.reply({'type': 'server-response', 'rpcId': body['rpcId'], 'result': {'ok': True, 'value': value}})
    def send_ws(self, value):
        data = json.dumps(value, ensure_ascii=False).encode(); header = bytes([129])
        header += bytes([len(data)]) if len(data) < 126 else bytes([126]) + struct.pack('!H', len(data)) if len(data) < 65536 else bytes([127]) + struct.pack('!Q', len(data))
        try:
            with self.write_lock: self.wfile.write(header + data); self.wfile.flush()
        except (OSError, ValueError): pass
    def read_exact(self, count):
        data = self.rfile.read(count)
        if len(data) != count: raise EOFError()
        return data
    def do_GET(self):
        if not self.authorized(): return self.reply({}, 401)
        if self.path != '/api/remote.mux': return self.reply({}, 404)
        accept = base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        self.send_response(101); self.send_header('Upgrade', 'websocket'); self.send_header('Connection', 'Upgrade'); self.send_header('Sec-WebSocket-Accept', accept); self.end_headers()
        self.streams = {}; self.write_lock = threading.Lock()
        with LOCK: CLIENTS.append(self)
        try:
            while True:
                a, b = self.read_exact(2); length = b & 127
                if a & 15 == 8: break
                if length == 126: length = struct.unpack('!H', self.read_exact(2))[0]
                if length == 127: length = struct.unpack('!Q', self.read_exact(8))[0]
                if length > 1024 * 1024: break
                mask = self.read_exact(4) if b & 128 else None; data = self.read_exact(length)
                if mask: data = bytes(byte ^ mask[i % 4] for i, byte in enumerate(data))
                body = json.loads(data)
                with LOCK:
                    key = body['streamId']
                    if body['type'] == 'cancel': self.streams.pop(key, None); continue
                    kind = body['endpoint']; request = body.get('payload', {}).get('args', {}).get('request', {}); sid = request.get('address', {}).get('sessionId')
                    self.streams[key] = (kind, sid)
                    if kind == 'workspace/follow': value = {'type': 'baseline', 'value': {'items': [WORKSPACE], 'archivedSessionIds': []}}
                    elif kind == 'session/control': value = {'type': 'baseline', 'value': {'queues': {}, 'jobs': {}, 'projections': {}}}
                    elif kind == '$events': value = {'type': 'ready', 'clientId': str(uuid.uuid4()), 'host': {'home': '/tmp'}}
                    elif kind == 'session/follow':
                        s = session(sid); value = {'type': 'snapshot', 'header': {'id': sid, 'version': 3, 'cwd': WORKSPACE['path']}, 'cursor': len(s['events']) - 1, 'records': [{'type': 'event', 'event': e} for e in s['events']], 'hasMore': False, 'assistantStream': {'revision': s['revision']}, 'projections': {'values': {'modelSelection': {'next': s['model']}, 'title': s['title']}}}
                        if s['attempt']:
                            value['assistantStream']['activeAttempt'] = {'attemptId': s['attempt'], 'turn': s['turn'], 'step': 0, 'nextIndex': s['nextIndex'], 'stream': s['stream']}
                    else: self.send_ws({'type': 'error', 'streamId': key, 'error': {'code': 'unsupported', 'message': kind}}); continue
                    self.send_ws({'type': 'item', 'streamId': key, 'value': value})
        except (EOFError, OSError, ValueError, KeyError): pass
        finally:
            with LOCK: CLIENTS.remove(self)
            self.close_connection = True

if __name__ == '__main__':
    print('Chatty Next synthetic fixture: http://127.0.0.1:8876', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8876), API).serve_forever()
