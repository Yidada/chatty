import importlib.util
import json
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

spec = importlib.util.spec_from_file_location('perf_fixture', Path(__file__).with_name('fixture.py'))
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)

class FixtureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = f.ThreadingHTTPServer(('127.0.0.1', 0), f.API)
        cls.thread = threading.Thread(target=cls.server.serve_forever)
        cls.thread.start()
        cls.base = 'http://127.0.0.1:' + str(cls.server.server_port)
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join()
    def setUp(self):
        f.seed('S2')
    def get(self, path):
        req = urllib.request.Request(self.base + path, headers={'Authorization': 'Bearer ' + f.f.TOKEN})
        with urllib.request.urlopen(req) as response:
            return json.load(response)
    def test_composite_cursor_no_duplicates_or_gaps(self):
        ids = []; query = ''
        while True:
            page = self.get('/api/chat/sessions/s1/messages/page' + query)
            ids += [m['id'] for m in page['messages']]
            if not page['has_more']: break
            c = page['next_cursor']
            query = '?' + urllib.parse.urlencode({'before_created_at': c['created_at'], 'before_id': c['id'], 'limit': 50})
        self.assertEqual(len(ids), 1000)
        self.assertEqual(len(set(ids)), 1000)
    def test_determinism_and_shape(self):
        a = f.seed('S2'); b = f.seed('S2')
        self.assertEqual(a, b)
        self.assertEqual((a['sessions'], a['markdown_messages'], a['image_metadata'], a['trace_count']), (20, 200, 10, 200))
        f.seed('S3')
        self.assertEqual(len(self.get('/api/projects')['projects']), 50)
        self.assertEqual(sum(len(self.get('/api/' + name)) for name in ['agents', 'runtimes', 'squads']), 100)
    def test_fault_status_retry_header_and_metric_redaction(self):
        f.CONFIG.update(status=429, delay_ms=15, retry_after=2)
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.get('/api/chat/sessions/private-id/messages/page?secret=hidden')
        self.assertEqual(caught.exception.headers['Retry-After'], '2')
        metrics = self.get('/__metrics')
        self.assertEqual(metrics['requests'][0]['status'], 429)
        self.assertGreaterEqual(metrics['requests'][0]['elapsed_ms'], 15)
        self.assertNotIn('private-id', json.dumps(metrics))
        self.assertNotIn('secret', json.dumps(metrics))
        self.assertNotIn(f.f.TOKEN, json.dumps(metrics))
    def test_append_message_is_newest_and_cleared_by_reseed(self):
        seeded = f.manifest()['target_messages']
        first = f.append_message({'content': 'Live event one'})
        second = f.append_message({'content': 'Live event two'})
        self.assertEqual(f.manifest()['target_messages'], seeded + 2)
        self.assertGreater(second['created_at'], first['created_at'])
        page = self.get('/api/chat/sessions/s1/messages/page?limit=2')
        self.assertEqual([m['id'] for m in page['messages']], [first['id'], second['id']])
        self.assertEqual(f.seed('S2')['target_messages'], seeded)
        self.assertEqual(f.CONFIG['appended'], 0)

if __name__ == '__main__': unittest.main()
