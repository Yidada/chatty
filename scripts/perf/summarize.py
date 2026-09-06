#!/usr/bin/env python3
"""Summarize raw Macrobenchmark files without converting absent data to zero."""
import argparse
import json
import math
import statistics
from pathlib import Path


def percentile(values, q):
    if not values:
        return None
    values = sorted(values)
    pos = (len(values) - 1) * q
    low = math.floor(pos)
    high = math.ceil(pos)
    return values[low] + (values[high] - values[low]) * (pos - low)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    output = []
    seen = set()
    for path in sorted(args.directory.rglob('*benchmarkData.json')):
        data = json.loads(path.read_text())
        for benchmark in data.get('benchmarks', []):
            # A pull may include previous test outputs. Keep source filename and
            # identical-record deduplication; never inflate sample counts.
            signature = json.dumps(benchmark, sort_keys=True)
            if signature in seen:
                continue
            seen.add(signature)
            row = {'source': str(path.relative_to(args.directory)), 'name': benchmark['name'],
                   'context': data.get('context', {}), 'metrics': {}}
            for name, metric in benchmark.get('metrics', {}).items():
                runs = metric.get('runs', [])
                if not runs or not all(isinstance(v, (int, float)) for v in runs):
                    row['metrics'][name] = {'status': 'UNMEASURED', 'raw': metric}
                    continue
                row['metrics'][name] = {'n': len(runs), 'runs': runs, 'median': statistics.median(runs),
                    'p95': percentile(runs, .95), 'p99': percentile(runs, .99), 'min': min(runs), 'max': max(runs)}
            # Frame metrics use sampledMetrics in this library. Preserve iteration
            # grouping and library-computed distribution, never average percentiles.
            row['sampledMetrics'] = benchmark.get('sampledMetrics', {})
            output.append(row)
    print(json.dumps({'status': 'MEASURED_CANDIDATE' if output else 'UNMEASURED',
                      'budget': 'NO_BUDGET', 'records': output}, indent=2))


if __name__ == '__main__': main()
