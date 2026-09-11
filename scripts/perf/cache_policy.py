#!/usr/bin/env python3
"""Isolated cache-policy model for the approved 4A capacity matrix.

This is **not** a device measurement and not product code. Baseline main has no
business cache, so cache-hit rate, database size and query time are UNMEASURED.
What this model provides is the policy half of the calibration: given the
approved limits (30 sessions, 10,000 messages or 50 MiB, evict on capacity, a
session untouched for 7 days may be evicted), it reports which accesses the
policy can serve from cache and when it evicts.

Device numbers still require the Room/disk prototype on a controlled Pixel: the
model cannot tell you database size, query latency or PSS. Treat its output as
the expected-hit-rate baseline that those measurements are compared against.

Access traces are synthetic and deterministic: a message key, its session, its
serialized size, and the day it is accessed. Nothing here reads or writes real
conversation content.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass

DEFAULT_MAX_SESSIONS = 30
DEFAULT_MAX_MESSAGES = 10_000
DEFAULT_MAX_BYTES = 50 * 1024 * 1024
DEFAULT_IDLE_DAYS = 7.0


@dataclass(frozen=True)
class Access:
    """One read of a cached-eligible message on `day` (fractional days allowed)."""

    key: str
    session: str
    day: float
    size_bytes: int = 1024


@dataclass
class CachePolicy:
    max_sessions: int = DEFAULT_MAX_SESSIONS
    max_messages: int = DEFAULT_MAX_MESSAGES
    max_bytes: int = DEFAULT_MAX_BYTES
    idle_days: float = DEFAULT_IDLE_DAYS

    def __post_init__(self):
        if min(self.max_sessions, self.max_messages, self.max_bytes) <= 0:
            raise ValueError('capacity limits must be positive')
        if self.idle_days <= 0:
            raise ValueError('idle_days must be positive')

    def simulate(self, accesses):
        """Replay accesses; return hits/misses/evictions and the retained footprint.

        Rules, in order: a session untouched for longer than `idle_days` may be
        evicted before the access is served; capacity eviction is least-recently-
        accessed first, messages before sessions, so a burst cannot exceed either
        the message or the byte ceiling.
        """
        entries = {}          # key -> {'session', 'size_bytes', 'last_access'}
        sessions = {}         # session -> last access day
        hits = misses = evicted_messages = evicted_sessions = idle_sessions = 0
        total_bytes = 0
        accesses = list(accesses)
        for access in sorted(accesses, key=lambda a: (a.day, a.key)):
            if access.session in sessions and access.day - sessions[access.session] > self.idle_days:
                for key in [k for k, value in entries.items() if value['session'] == access.session]:
                    total_bytes -= entries[key]['size_bytes']
                    del entries[key]
                del sessions[access.session]
                idle_sessions += 1
            entry = entries.get(access.key)
            if entry is not None:
                hits += 1
                entry['last_access'] = access.day
            else:
                misses += 1
                entries[access.key] = {'session': access.session, 'size_bytes': access.size_bytes,
                                       'last_access': access.day}
                total_bytes += access.size_bytes
            sessions[access.session] = access.day
            while len(entries) > self.max_messages or total_bytes > self.max_bytes:
                victim = min(entries, key=lambda key: (entries[key]['last_access'], key))
                total_bytes -= entries[victim]['size_bytes']
                del entries[victim]
                evicted_messages += 1
            while len(sessions) > self.max_sessions:
                victim_session = min(sessions, key=lambda session: (sessions[session], session))
                del sessions[victim_session]
                for key in [k for k, value in entries.items() if value['session'] == victim_session]:
                    total_bytes -= entries[key]['size_bytes']
                    del entries[key]
                evicted_sessions += 1
        return {
            'accesses': len(accesses),
            'hits': hits,
            'misses': misses,
            'hit_rate': (hits / (hits + misses)) if (hits + misses) else None,
            'evicted_messages': evicted_messages,
            'evicted_sessions': evicted_sessions,
            'idle_session_evictions': idle_sessions,
            'retained_messages': len(entries),
            'retained_bytes': total_bytes,
            'retained_sessions': len(sessions),
            'policy': {'max_sessions': self.max_sessions, 'max_messages': self.max_messages,
                       'max_bytes': self.max_bytes, 'idle_days': self.idle_days},
            'scope': 'policy model only; device cache-hit/DB/query/PSS numbers remain UNMEASURED',
        }


def synthetic_trace(sessions=40, messages_per_session=400, size_bytes=1024, rereads=2, idle_gap_days=9.0):
    """Deterministic two-pass trace: read every message, then re-read one session.

    The second pass starts after `idle_gap_days` so the idle rule is exercised for
    sessions that were not touched in between.
    """
    accesses = []
    for session in range(sessions):
        for message in range(messages_per_session):
            accesses.append(Access(key=f's{session:02d}:m{message:04d}', session=f's{session:02d}', day=0.1, size_bytes=size_bytes))
    for message in range(messages_per_session):
        accesses.append(Access(key=f's00:m{message:04d}', session='s00', day=idle_gap_days, size_bytes=size_bytes))
    for _ in range(max(0, rereads - 1)):
        for message in range(messages_per_session):
            accesses.append(Access(key=f's01:m{message:04d}', session='s01', day=0.5, size_bytes=size_bytes))
    return accesses


def main():
    parser = argparse.ArgumentParser(description='Replay a synthetic access trace against the approved cache policy.')
    parser.add_argument('--sessions', type=int, default=40)
    parser.add_argument('--messages-per-session', type=int, default=400)
    parser.add_argument('--size-bytes', type=int, default=1024)
    parser.add_argument('--max-sessions', type=int, default=DEFAULT_MAX_SESSIONS)
    parser.add_argument('--max-messages', type=int, default=DEFAULT_MAX_MESSAGES)
    parser.add_argument('--max-bytes', type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument('--idle-days', type=float, default=DEFAULT_IDLE_DAYS)
    args = parser.parse_args()
    trace = synthetic_trace(args.sessions, args.messages_per_session, args.size_bytes)
    policy = CachePolicy(args.max_sessions, args.max_messages, args.max_bytes, args.idle_days)
    print(json.dumps(policy.simulate(trace), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
