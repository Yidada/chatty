#!/usr/bin/env python3
"""Summarize raw Macrobenchmark files without converting absent data to zero."""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    records = measure.summarize_benchmark_dir(args.directory)
    print(json.dumps({'status': 'MEASURED_CANDIDATE' if records else 'UNMEASURED',
                      'budget': 'NO_BUDGET', 'records': records}, indent=2))


if __name__ == '__main__':
    main()
