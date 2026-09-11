import importlib.util
import socket
import sys
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('perf_collect', Path(__file__).with_name('collect.py'))
c = importlib.util.module_from_spec(spec)
sys.modules['perf_collect'] = c
spec.loader.exec_module(c)


class FixturePortTest(unittest.TestCase):
    def test_reverse_maps_the_fixed_device_port_to_the_chosen_host_port(self):
        """The device side never moves: the benchmark APK hardcodes 8765 in-process."""
        self.assertEqual(c.reverse_spec(8766), ['reverse', 'tcp:8765', 'tcp:8766'])
        self.assertEqual(c.reverse_spec(9000), ['reverse', 'tcp:8765', 'tcp:9000'])
        self.assertEqual(c.DEVICE_FIXTURE_PORT, 8765)

    def test_host_port_available_detects_a_held_port(self):
        holder = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        holder.bind(('127.0.0.1', 0))
        holder.listen(1)
        port = holder.getsockname()[1]
        try:
            self.assertFalse(c.host_port_available(port))
        finally:
            holder.close()
        self.assertTrue(c.host_port_available(port))


class AmStartParseTest(unittest.TestCase):
    def test_parses_total_time_and_tolerates_absence(self):
        self.assertEqual(c.parse_am_start_total_time('TotalTime: 312\n'), 312)
        self.assertEqual(c.parse_am_start_total_time('TotalTime: not-a-number\n'), None)
        self.assertEqual(c.parse_am_start_total_time('Status: ok\n'), None)


if __name__ == '__main__':
    unittest.main()
