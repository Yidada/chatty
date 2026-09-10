import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('perf_measure', Path(__file__).with_name('measure.py'))
m = importlib.util.module_from_spec(spec)
# The module must be registered before execution: dataclasses on Python 3.9
# resolves postponed annotations through sys.modules[cls.__module__].
sys.modules['perf_measure'] = m
spec.loader.exec_module(m)


class BenchmarkRecordsTest(unittest.TestCase):
    def write(self, directory, name, benchmarks):
        (Path(directory) / name).write_text(json.dumps({'context': {'build': 'test'}, 'benchmarks': benchmarks}))

    def test_summarizes_scalar_metrics_and_keeps_unmeasured_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.write(tmp, 'cold-benchmarkData.json', [
                {'name': 'cold', 'metrics': {'timeToInitialDisplayMs': {'runs': [300, 310, 320]},
                                             'broken': {'runs': ['n/a']}},
                 'sampledMetrics': {'frameDurationCpuMs': {'P50': 7.5, 'P95': 9.0}}},
            ])
            records = m.summarize_benchmark_dir(tmp)
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]['metrics']['timeToInitialDisplayMs']['median'], 310)
            self.assertEqual(records[0]['metrics']['broken']['status'], 'UNMEASURED')
            metrics = m.round_metrics(records, prefix='round-1:')
            self.assertEqual(metrics['round-1:cold:timeToInitialDisplayMs'], 310)
            self.assertEqual(metrics['round-1:cold:frameDurationCpuMs:P50'], 7.5)

    def test_identical_records_from_an_earlier_pull_are_counted_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            benchmark = {'name': 'hot', 'metrics': {'timeToInitialDisplayMs': {'runs': [40, 42]}}, 'sampledMetrics': {}}
            self.write(tmp, 'a-benchmarkData.json', [benchmark])
            self.write(tmp, 'b-benchmarkData.json', [benchmark])
            self.assertEqual(len(m.summarize_benchmark_dir(tmp)), 1)

    def test_missing_directory_yields_no_records(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(m.summarize_benchmark_dir(Path(tmp) / 'absent'), [])


class SoakReportTest(unittest.TestCase):
    def test_reports_observed_peak_and_leak_trend_over_the_series(self):
        samples = [{'at_s': hour * 3600, 'pss_kib': 100000 + hour * 500} for hour in range(5)]
        report = m.soak_report(samples, crashes=1, anrs=0, energy_start_mah=10.0, energy_end_mah=42.0,
                               battery_start_pct=70, battery_end_pct=55)
        self.assertEqual(report['peak_pss_kib'], 102000)
        self.assertAlmostEqual(report['leak_slope_kib_per_hour'], 500.0)
        self.assertEqual(report['duration_hours'], 4.0)
        self.assertEqual(report['crashes'], 1)
        self.assertAlmostEqual(report['device_energy_mah'], 32.0)
        self.assertEqual(report['battery_pct_drop'], 15)
        self.assertEqual(report['verdict'], 'MEASURED_CANDIDATE')

    def test_two_samples_are_not_a_trend(self):
        report = m.soak_report([{'at_s': 0, 'pss_kib': 1}, {'at_s': 60, 'pss_kib': 2}])
        self.assertEqual(report['verdict'], 'UNMEASURED')
        self.assertIsNone(report['leak_slope_kib_per_hour'])

    def test_missing_energy_dump_stays_none(self):
        report = m.soak_report([{'at_s': s, 'pss_kib': 1000} for s in (0, 60, 120)])
        self.assertIsNone(report['device_energy_mah'])
        self.assertIsNone(report['battery_pct_drop'])


class UiDumpTest(unittest.TestCase):
    XML = ('<?xml version="1.0" encoding="UTF-8"?><hierarchy><node text="和 Mika 聊聊…" '
           'content-desc="刷新对话" bounds="[0,0][1,1]"/><node text="暂时无法连接，请重试。草稿已保留。"/></hierarchy>')

    def test_extracts_text_and_content_description(self):
        self.assertEqual(m.ui_texts(self.XML), ['和 Mika 聊聊…', '刷新对话', '暂时无法连接，请重试。草稿已保留。'])

    def test_matches_notice_copy(self):
        self.assertTrue(m.ui_contains(self.XML, '暂时无法连接'))
        self.assertFalse(m.ui_contains(self.XML, '离线'))
        self.assertEqual(m.ui_texts(''), [])


class PercentileTest(unittest.TestCase):
    def test_linear_interpolation_matches_report_convention(self):
        self.assertEqual(m.percentile([10, 20, 30, 40], 0.0), 10)
        self.assertAlmostEqual(m.percentile([10, 20, 30, 40], 0.25), 17.5)
        self.assertEqual(m.percentile([10, 20, 30, 40], 1.0), 40)
        self.assertEqual(m.percentile([7], 0.95), 7)

    def test_summarize_withholds_p99_below_twenty_samples(self):
        small = m.summarize(list(range(10)))
        self.assertIsNone(small['p99'])
        self.assertEqual(small['n'], 10)
        large = m.summarize(list(range(20)))
        self.assertEqual(large['p99'], m.percentile(list(range(20)), 0.99))

    def test_summarize_of_empty_series_is_count_only(self):
        self.assertEqual(m.summarize([None]), {'n': 0})

    def test_percentile_rejects_out_of_range_fraction(self):
        with self.assertRaises(ValueError):
            m.percentile([1], 1.5)


class StartupProbeTest(unittest.TestCase):
    LINE = ('09-10 20:00:01.000  1234  1234 I ChattyStartupProbe: composer-interactive '
            'elapsed_ms={elapsed} start_uptime_ms=1000 now_uptime_ms=1000 pid={pid} fully_drawn={drawn}')

    def line(self, elapsed, pid, drawn='true'):
        return self.LINE.format(elapsed=elapsed, pid=pid, drawn=drawn)

    def test_parses_records_and_flags(self):
        samples = m.parse_startup_probe(self.line(305, 111) + '\n' + self.line(690, 222, 'false'))
        self.assertEqual([s.elapsed_ms for s in samples], [305, 690])
        self.assertEqual(samples[0].start_uptime_ms, 1000)
        self.assertTrue(samples[0].fully_drawn)
        self.assertFalse(samples[1].fully_drawn)

    def test_collapses_repeated_records_for_one_process_to_the_earliest(self):
        text = '\n'.join([self.line(500, 111), self.line(305, 111), self.line(420, 111)])
        samples = m.parse_startup_probe(text)
        self.assertEqual(len(samples), 1)
        self.assertEqual(samples[0].elapsed_ms, 305)

    def test_ignores_negative_elapsed_and_unrelated_lines(self):
        text = self.line(-5, 111) + '\nI ChattyStartupProbe: unrelated\n'
        self.assertEqual(m.parse_startup_probe(text), [])

    def test_summary_reports_median_and_fully_drawn_count(self):
        text = '\n'.join(self.line(value, pid) for pid, value in enumerate([300, 400, 500], start=1))
        summary = m.summarize_startup(text)
        self.assertEqual(summary['samples'], 3)
        self.assertEqual(summary['elapsed_ms']['median'], 400)
        self.assertEqual(summary['elapsed_ms']['p95'], 490)
        self.assertEqual(summary['fully_drawn_observed'], 3)


class NetworkProbeTest(unittest.TestCase):
    def call(self, **overrides):
        payload = {'id': 'c1', 'method': 'GET', 'host': '127.0.0.1', 'port': 8765,
                   'path': '/api/chat/sessions/s1/messages/page', 'dns_ms': 0.4, 'tcp_ms': 1.2,
                   'tls_ms': None, 'ttfb_ms': 12.0, 'body_ms': 3.0, 'e2e_ms': 16.4,
                   'status': 200, 'protocol': 'http/1.1', 'outcome': 'success', 'error': ''}
        payload.update(overrides)
        return 'I ChattyNetProbe: netcall ' + json.dumps(payload)

    def test_parses_valid_records_only(self):
        text = '\n'.join([self.call(), self.call(id='c2', outcome='failure', error='java.net.SocketTimeoutException', status=None),
                          'I ChattyNetProbe: netcall {broken', 'I ChattyNetProbe: netcall [1,2]'])
        calls = m.parse_netcalls(text)
        self.assertEqual([c.call_id for c in calls], ['c1', 'c2'])

    def test_summary_separates_failures_and_measures_only_successes(self):
        text = '\n'.join([self.call(), self.call(id='c2', e2e_ms=40.0), self.call(id='c3', outcome='failure', error='java.io.IOException')])
        summary = m.summarize_netcalls(text)
        self.assertEqual(summary['calls'], 3)
        self.assertEqual(summary['failed_calls'], 1)
        self.assertEqual(summary['failure_classes'], ['java.io.IOException'])
        self.assertEqual(summary['by_phase']['e2e']['n'], 2)
        self.assertEqual(summary['by_phase']['e2e']['median'], 28.2)
        self.assertEqual(summary['by_endpoint']['/api/chat/sessions/s1/messages/page']['n'], 2)

    def test_tls_phase_is_absent_for_cleartext_loopback(self):
        # Cleartext loopback has no DNS lookup and no TLS handshake at all.
        summary = m.summarize_netcalls(self.call(dns_ms=None, tls_ms=None))
        self.assertEqual(summary['by_phase']['tls']['n'], 0)
        self.assertEqual(summary['unavailable_phases'], ['dns', 'tls'])

    def test_unavailable_phases_is_empty_when_every_phase_has_samples(self):
        text = self.call(dns_ms=1.0, tls_ms=2.0)
        self.assertEqual(m.summarize_netcalls(text)['unavailable_phases'], [])


class EnvironmentTest(unittest.TestCase):
    BATTERY = 'Current Battery Service state:\n  AC powered: false\n  level: 83\n  scale: 100\n'
    THERMAL_LIGHT = 'IsStatusOverride: false\nCurrent thermal status: 1\n'
    THERMAL_NONE = 'IsStatusOverride: false\nCurrent thermal status: 0\n'

    def test_reads_battery_thermal_and_refresh(self):
        self.assertEqual(m.parse_battery_level(self.BATTERY), 83)
        self.assertEqual(m.parse_thermal_status(self.THERMAL_LIGHT), 1)
        self.assertEqual(m.parse_thermal_status(self.THERMAL_NONE), 0)
        self.assertEqual(m.parse_refresh_rate('60.0'), 60.0)
        self.assertIsNone(m.parse_refresh_rate('null'))
        self.assertIsNone(m.parse_refresh_rate('Infinity'))

    def test_gate_rejects_the_cle73_exploratory_condition(self):
        gate = m.environment_gate({'battery_pct': 83, 'thermal_status': 1, 'peak_refresh_rate': None,
                                   'min_refresh_rate': None, 'low_power': 0})
        self.assertFalse(gate['budget_grade'])
        self.assertEqual(gate['blocking'], ['battery_in_range', 'fixed_60hz', 'thermal_none'])

    def test_gate_accepts_controlled_condition(self):
        gate = m.environment_gate({'battery_pct': 60, 'thermal_status': 0, 'peak_refresh_rate': 60.0,
                                   'min_refresh_rate': 60.0, 'low_power': 0})
        self.assertTrue(gate['budget_grade'])
        self.assertEqual(gate['blocking'], [])

    def test_gate_blocks_battery_saver_and_unknown_state(self):
        gate = m.environment_gate({'battery_pct': None, 'thermal_status': None, 'peak_refresh_rate': 60.0,
                                   'min_refresh_rate': 60.0, 'low_power': 1})
        self.assertIn('battery_in_range', gate['blocking'])
        self.assertIn('thermal_none', gate['blocking'])
        self.assertIn('battery_saver_off', gate['blocking'])


class MemoryAndEnergyTest(unittest.TestCase):
    APP_SUMMARY = 'App Summary\n                       Pss(KB)\nTOTAL PSS:           151100\n'
    TABLE = '** MEMINFO in pid 1234 **\n                   Pss  Private\n         TOTAL   149822   140000\n'
    DEAD = 'No process found for: ai.chatty.app.benchmark\n'

    def test_accepts_both_meminfo_shapes(self):
        self.assertEqual(m.parse_total_pss_kib(self.APP_SUMMARY), 151100)
        self.assertEqual(m.parse_total_pss_kib(self.TABLE), 149822)

    def test_dead_process_is_none_not_zero(self):
        self.assertIsNone(m.parse_total_pss_kib(self.DEAD))
        self.assertIsNone(m.parse_total_pss_kib(''))

    def test_peak_and_leak_slope(self):
        samples = [{'at_s': hour * 3600, 'pss_kib': 100000 + hour * 1000} for hour in range(4)]
        self.assertEqual(m.peak_pss_kib([s['pss_kib'] for s in samples]), 103000)
        self.assertAlmostEqual(m.leak_slope_kib_per_hour(samples), 1000.0)

    def test_leak_slope_needs_three_distinct_timestamps(self):
        self.assertIsNone(m.leak_slope_kib_per_hour([{'at_s': 0, 'pss_kib': 1}, {'at_s': 1, 'pss_kib': 2}]))
        flat = [{'at_s': 5, 'pss_kib': v} for v in (1, 2, 3)]
        self.assertIsNone(m.leak_slope_kib_per_hour(flat))

    def test_energy_proxy_parsing(self):
        dump = 'Estimated power use (mAh):\n  Capacity: 5003\n  Computed drain: 292.4\n  Uid u0a321: 12.5\n'
        self.assertEqual(m.parse_energy_mah(dump), 292.4)
        self.assertEqual(m.parse_uid_energy_mah(dump, 'u0a321'), 12.5)
        self.assertIsNone(m.parse_uid_energy_mah(dump, 'u0a999'))
        self.assertIsNone(m.parse_energy_mah('nothing here'))


class NoiseEnvelopeTest(unittest.TestCase):
    def test_reports_worst_relative_change_per_metric(self):
        envelope = m.noise_envelope({'round-1': {'cold_median': 315.05, 'hot_p95': 59.0},
                                     'round-2': {'cold_median': 304.92, 'hot_p95': 49.69}})
        self.assertAlmostEqual(envelope['cold_median']['max_abs_relative_change'], 0.0322, places=4)
        self.assertAlmostEqual(envelope['hot_p95']['max_abs_relative_change'], 0.1578, places=4)

    def test_single_round_leaves_metric_undefined(self):
        envelope = m.noise_envelope({'round-1': {'cold_median': 300}})
        self.assertIsNone(envelope['cold_median']['max_abs_relative_change'])

    def test_relative_change_guards_zero_baseline(self):
        self.assertIsNone(m.relative_change(0, 5))
        self.assertAlmostEqual(m.relative_change(100, 90), -0.1)


class CaptureSummaryTest(unittest.TestCase):
    def test_summarizes_a_collector_directory_without_claiming_missing_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            (out / 'cold-logcat.txt').write_text(
                'I ChattyStartupProbe: composer-interactive elapsed_ms=310 start_uptime_ms=1000 now_uptime_ms=1310 pid=7 fully_drawn=true\n'
                'I ChattyNetProbe: netcall ' + json.dumps({'id': 'c1', 'method': 'GET', 'host': '127.0.0.1',
                    'port': 8765, 'path': '/api/workspaces', 'dns_ms': None, 'tcp_ms': 0.8, 'tls_ms': None,
                    'ttfb_ms': 9.0, 'body_ms': 1.0, 'e2e_ms': 11.0, 'status': 200, 'protocol': 'http/1.1',
                    'outcome': 'success', 'error': ''}) + '\n')
            (out / 'pss-1.json').write_text(json.dumps([{'at_s': 0, 'pss_kib': 100000},
                                                        {'at_s': 3600, 'pss_kib': 101000},
                                                        {'at_s': 7200, 'pss_kib': 102000}]))
            (out / 'soak-batterystats.txt').write_text('Computed drain: 292.4\n')
            summary = m.summarize_capture(out)
            self.assertEqual(summary.startup['elapsed_ms']['median'], 310)
            self.assertEqual(summary.network['by_phase']['e2e']['median'], 11.0)
            self.assertEqual(summary.memory['peak_pss_kib'], 102000)
            self.assertAlmostEqual(summary.memory['leak_slope_kib_per_hour'], 1000.0)
            self.assertEqual(summary.energy['estimated_device_mah'], 292.4)

    def test_empty_directory_reports_zero_samples(self):
        with tempfile.TemporaryDirectory() as tmp:
            summary = m.summarize_capture(tmp)
            self.assertEqual(summary.startup['samples'], 0)
            self.assertEqual(summary.network['calls'], 0)
            self.assertIsNone(summary.memory['peak_pss_kib'])


if __name__ == '__main__':
    unittest.main()
