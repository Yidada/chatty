import importlib.util
import sys
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('perf_cache_policy', Path(__file__).with_name('cache_policy.py'))
c = importlib.util.module_from_spec(spec)
sys.modules['perf_cache_policy'] = c
spec.loader.exec_module(c)


def access(key, session, day, size=1024):
    return c.Access(key=key, session=session, day=day, size_bytes=size)


class CachePolicyTest(unittest.TestCase):
    def test_repeated_access_within_the_window_is_a_hit(self):
        policy = c.CachePolicy(max_sessions=5, max_messages=10, max_bytes=10 * 1024, idle_days=7)
        report = policy.simulate([access('s1:m1', 's1', 0.1), access('s1:m1', 's1', 0.2), access('s1:m1', 's1', 0.3)])
        self.assertEqual((report['hits'], report['misses']), (2, 1))
        self.assertAlmostEqual(report['hit_rate'], 2 / 3)

    def test_message_and_byte_ceilings_are_never_exceeded(self):
        policy = c.CachePolicy(max_sessions=5, max_messages=4, max_bytes=3 * 1024, idle_days=7)
        report = policy.simulate([access(f's1:m{i}', 's1', 0.1 + i * 0.001) for i in range(20)])
        self.assertLessEqual(report['retained_messages'], 4)
        self.assertLessEqual(report['retained_bytes'], 3 * 1024)
        self.assertGreater(report['evicted_messages'], 0)

    def test_session_ceiling_evicts_least_recently_used_session(self):
        policy = c.CachePolicy(max_sessions=2, max_messages=100, max_bytes=10 ** 6, idle_days=7)
        report = policy.simulate([access('s1:m1', 's1', 0.1), access('s2:m1', 's2', 0.2), access('s3:m1', 's3', 0.3)])
        self.assertLessEqual(report['retained_sessions'], 2)
        self.assertEqual(report['evicted_sessions'], 1)

    def test_idle_session_is_evicted_and_reread_misses(self):
        policy = c.CachePolicy(max_sessions=5, max_messages=100, max_bytes=10 ** 6, idle_days=7)
        report = policy.simulate([access('s1:m1', 's1', 0.1), access('s1:m1', 's1', 8.0)])
        self.assertEqual(report['idle_session_evictions'], 1)
        self.assertEqual((report['hits'], report['misses']), (0, 2))

    def test_zero_capacity_is_rejected(self):
        for kwargs in ({'max_sessions': 0}, {'max_messages': 0}, {'max_bytes': 0}, {'idle_days': 0}):
            with self.assertRaises(ValueError):
                c.CachePolicy(**kwargs)

    def test_synthetic_trace_is_deterministic_and_bounded_by_the_approved_policy(self):
        trace = c.synthetic_trace(sessions=40, messages_per_session=400)
        self.assertEqual(trace, c.synthetic_trace(sessions=40, messages_per_session=400))
        self.assertEqual(len(trace), 40 * 400 + 400 * 2)
        report = c.CachePolicy().simulate(trace)
        self.assertLessEqual(report['retained_sessions'], c.DEFAULT_MAX_SESSIONS)
        self.assertLessEqual(report['retained_messages'], c.DEFAULT_MAX_MESSAGES)
        self.assertLessEqual(report['retained_bytes'], c.DEFAULT_MAX_BYTES)
        self.assertEqual(report['scope'].split(';')[0], 'policy model only')


if __name__ == '__main__':
    unittest.main()
