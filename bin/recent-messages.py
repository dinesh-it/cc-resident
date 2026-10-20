#!/usr/bin/env python3
"""Print notifications your scripts sent to Telegram, as context for the agent.

  recent-messages.py --new        only messages since the last call (UserPromptSubmit hook)
  recent-messages.py --hours 24   messages from the last N hours (SessionStart hook)

Reads NOTIFY_LOG from the environment or config.env.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'lib'))
from notify_log import _log_file  # noqa: E402

CURSOR_FILE = os.path.join(ROOT, '.state', 'messages.cursor')
MAX_MESSAGES = 20
MAX_CHARS = 1500


def read_entries(path, offset=0):
    entries = []
    try:
        with open(path, 'rb') as f:
            # Log was truncated or rotated: start over
            if offset > os.fstat(f.fileno()).st_size:
                offset = 0
            f.seek(offset)
            for line in f:
                try:
                    entries.append(json.loads(line))
                except ValueError:
                    pass
            end = f.tell()
    except OSError:
        return [], offset
    return entries, end


def save_cursor(end):
    os.makedirs(os.path.dirname(CURSOR_FILE), exist_ok=True)
    with open(CURSOR_FILE, 'w') as f:
        f.write(str(end))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--new', action='store_true')
    parser.add_argument('--hours', type=float, default=24)
    args = parser.parse_args()
    path = _log_file()

    if args.new:
        try:
            offset = int(open(CURSOR_FILE).read().strip())
        except (OSError, ValueError):
            offset = 0
        entries, end = read_entries(path, offset)
        title = 'New notifications sent to the user on Telegram since their last message'
    else:
        entries, end = read_entries(path)
        cutoff = (datetime.now() - timedelta(hours=args.hours)).isoformat(timespec='seconds')
        entries = [e for e in entries if e.get('ts', '') >= cutoff]
        title = f'Notifications sent to the user on Telegram in the last {args.hours:g} hours'
    # Everything up to here is now in context, so --new continues from here
    save_cursor(end)

    if not entries:
        return

    entries = entries[-MAX_MESSAGES:]
    print(f'{title} by scripts on this machine (not by you). '
          'If they ask "what is this?" or similar, they most likely mean the latest one:')
    for e in entries:
        text = e.get('text', '')
        if len(text) > MAX_CHARS:
            text = text[:MAX_CHARS] + ' …[truncated]'
        print(f"\n[{e.get('ts', '?').replace('T', ' ')} · {e.get('source', 'unknown')}]\n{text}")


if __name__ == '__main__':
    main()
