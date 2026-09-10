#!/usr/bin/env python3
"""Deterministic loopback S0-S4 API. No real service traffic or personal data."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import re
import socket
import threading
import time
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

spec = importlib.util.spec_from_file_location('chat_fixture', Path(__file__).parents[1] / 'chat-fixture.py')
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
LOCK = threading.Lock()
RECORDS = []
CONFIG = {'scenario': 'S1', 'delay_ms': 0, 'status': 200, 'retry_after': 1, 'disconnect': False, 'appended': 0}


def seed(scenario):
    if scenario not in ('S0', 'S1', 'S2', 'S3', 'S4'):
        raise ValueError('scenario must be S0-S4')
    CONFIG.update(scenario=scenario, delay_ms=0, status=200, disconnect=False, appended=0)
    large = scenario in ('S2', 'S4')
    count = 1000 if large else 50
    start = dt.datetime(2026, 9, 5, tzinfo=dt.timezone.utc)
    f.MESSAGES[:] = []
    for i in range(count):
        message = {'id': f'm{i:05}', 'chat_session_id': 's1', 'role': 'assistant' if i % 2 == 0 else 'user',
                   'content': f'Baseline message {i:04}', 'created_at': (start + dt.timedelta(seconds=i // 2)).isoformat().replace('+00:00', 'Z')}
        if large and i % 5 == 0:
            message['content'] = f'## Baseline {i:04}\n\n**Markdown**\n\n- deterministic\n- synthetic\n\n```kotlin\nval sample = {i}\n```'
        if large and i % 100 == 0:
            message['attachments'] = [dict(f.IMAGE_A)]
        f.MESSAGES.append(message)
    f.SESSIONS[:] = [dict(f.S, id=f's{i+1}', title=f'Baseline session {i+1}', has_unread=False, unread_count=0) for i in range(20 if large else 1)]
    f.PENDING.clear()
    f.TRACES.clear()
    if large:
        f.PENDING['s1'] = {'task_id': 'baseline-task', 'status': 'running', 'created_at': '2026-09-05T01:00:00Z'}
        f.TRACES['baseline-task'] = [{'task_id': 'baseline-task', 'seq': i, 'type': 'thinking', 'content': f'Synthetic activity {i}'} for i in range(200)]
    f.ISSUES[:] = [dict(id=f'i{i}', identifier=f'PERF-{i+1}', title=f'Baseline issue {i}', status='todo', project_id=f'p{i%50}', revision=1, priority='high') for i in range(2000)]
    f.STATUS = 200
    f.CALLS.clear()
    with LOCK:
        RECORDS.clear()
    return manifest()


def manifest():
    payload = json.dumps({'sessions': f.SESSIONS, 'messages': f.MESSAGES, 'issues': f.ISSUES,
                          'pending': f.PENDING, 'traces': f.TRACES}, sort_keys=True).encode()
    return {'schema': 1, 'scenario': CONFIG['scenario'], 'sha256': hashlib.sha256(payload).hexdigest(),
            'sessions': len(f.SESSIONS), 'target_messages': len(f.MESSAGES),
            'markdown_messages': sum(m['content'].startswith('##') for m in f.MESSAGES),
            'image_metadata': sum(len(m.get('attachments', [])) for m in f.MESSAGES),
            'trace_count': sum(map(len, f.TRACES.values())), 'projects': 50 if CONFIG['scenario'] == 'S3' else 2, 'issues': len(f.ISSUES),
            'agents': 34 if CONFIG['scenario'] == 'S3' else 2, 'runtimes': 33 if CONFIG['scenario'] == 'S3' else 1, 'squads': 33 if CONFIG['scenario'] == 'S3' else 1}


def route(path):
    return re.sub(r'(/(?:sessions|tasks|workspaces|issues|attachments)/)[^/]+', r'\1{id}', path)


def append_message(spec):
    """Append one synthetic message and announce it as a live ``chat:message`` frame.

    Used by the S2 live-event path: the client must learn about the new message
    from the WebSocket frame and render it without a manual refresh. Timestamps
    stay after the seeded maximum so the paging cursor order is unchanged.
    """
    content = str(spec.get('content', 'Synthetic live event'))
    session_id = str(spec.get('chat_session_id', 's1'))
    rows = [m for m in f.MESSAGES if m['chat_session_id'] == session_id]
    latest = max((m['created_at'] for m in rows), default='2026-09-05T00:00:00Z')
    stamp = dt.datetime.fromisoformat(latest.replace('Z', '+00:00')) + dt.timedelta(seconds=2)
    CONFIG['appended'] += 1
    message = {'id': f'live{CONFIG["appended"]:05d}', 'chat_session_id': session_id, 'role': 'assistant',
               'content': content, 'created_at': stamp.isoformat().replace('+00:00', 'Z')}
    f.MESSAGES.append(message)
    f.broadcast('chat:message', {'chat_session_id': session_id, 'id': message['id'], 'message': message})
    return message


class API(f.API):
    def reply(self, code, value, ctype='application/json'):
        raw = json.dumps(value, ensure_ascii=False).encode() if ctype == 'application/json' else value
        if not urlsplit(self.path).path.startswith('/__'):
            record = {'elapsed_ms': round((time.perf_counter() - getattr(self, 'started', time.perf_counter())) * 1000, 3),
                      'monotonic_ns': time.monotonic_ns(), 'method': self.command, 'endpoint': route(urlsplit(self.path).path),
                      'status': code, 'response_bytes': len(raw), 'scenario': CONFIG['scenario']}
            with LOCK:
                RECORDS.append(record)
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(raw)))
        if code == 429:
            self.send_header('Retry-After', str(CONFIG['retry_after']))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def fault(self):
        time.sleep(CONFIG['delay_ms'] / 1000)
        if CONFIG['disconnect']:
            self.close_connection = True
            self.connection.shutdown(socket.SHUT_RDWR)
            return True
        if CONFIG['status'] != 200:
            self.reply(CONFIG['status'], {'error': 'synthetic failure'})
            return True
        return False

    def do_POST(self):
        self.started = time.perf_counter()
        if self.path == '/__perf':
            body = json.loads(self.raw() or '{}')
            if 'scenario' in body:
                seed(body['scenario'])
            for key in ('delay_ms', 'status', 'retry_after', 'disconnect'):
                if key in body:
                    CONFIG[key] = body[key]
            if body.get('reset_metrics'):
                with LOCK:
                    RECORDS.clear()
            if body.get('drop_ws'):
                with f.LOCK:
                    for client in list(f.CLIENTS):
                        try:
                            client.shutdown(socket.SHUT_RDWR)
                        except OSError:
                            pass
            for event in body.get('events', []):
                f.broadcast(event['type'], event.get('payload', {}))
            if 'append_message' in body:
                append_message(body['append_message'] or {})
            return self.reply(200, manifest())
        if self.path.startswith('/api/') and self.fault():
            self.raw()
            return
        return super().do_POST()

    def do_GET(self):
        self.started = time.perf_counter()
        path = urlsplit(self.path).path
        q = parse_qs(urlsplit(self.path).query)
        if path == '/__manifest':
            return self.reply(200, manifest())
        if path == '/__metrics':
            with LOCK:
                records = list(RECORDS)
            return self.reply(200, {'requests': records, 'active_sockets': len(f.CLIENTS),
                'cache_hits': None, 'cache_status': 'UNMEASURED: no business cache in B0',
                'timing_scope': 'fixture handler only; excludes transport, DNS, TLS and client scheduling'})
        if path.startswith('/api/') and self.fault():
            return
        page = re.fullmatch('/api/chat/sessions/([^/]+)/messages/page', path)
        if page:
            if not self.auth():
                return
            rows = sorted((m for m in f.MESSAGES if m['chat_session_id'] == page[1]), key=lambda m: (m['created_at'], m['id']))
            if q.get('before_id') and q.get('before_created_at'):
                cursor = (q['before_created_at'][0], q['before_id'][0])
                rows = [m for m in rows if (m['created_at'], m['id']) < cursor]
            limit = max(1, min(100, int(q.get('limit', ['50'])[0])))
            batch = rows[-limit:]
            more = len(rows) > limit
            return self.reply(200, {'messages': batch, 'has_more': more,
                'next_cursor': {'id': batch[0]['id'], 'created_at': batch[0]['created_at']} if more else None})
        if CONFIG['scenario'] == 'S3' and path in ('/api/projects', '/api/agents', '/api/runtimes', '/api/squads'):
            if not self.auth():
                return
            if path == '/api/projects':
                rows = [dict(id=f'p{i}', title=f'Baseline project {i}', issue_count=40, done_count=0) for i in range(50)]
                return self.reply(200, {'projects': rows, 'total': len(rows)})
            if path == '/api/agents':
                return self.reply(200, [f.AGENT] + [dict(f.AGENT, id=f'a{i}', system_key=None) for i in range(33)])
            if path == '/api/runtimes':
                return self.reply(200, [dict(id=f'r{i}', name=f'Runtime {i}', status='online') for i in range(33)])
            return self.reply(200, [dict(id=f'sq{i}', name=f'Squad {i}', member_count=1) for i in range(33)])
        return super().do_GET()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--scenario', choices=['S0', 'S1', 'S2', 'S3', 'S4'], default='S1')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    print(json.dumps(seed(args.scenario)), flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), API).serve_forever()


if __name__ == '__main__':
    main()
