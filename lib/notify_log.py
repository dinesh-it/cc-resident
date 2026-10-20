"""Append a sent notification to the cc-resident notification log.

For Python scripts that send to Telegram themselves:

    import sys; sys.path.insert(0, '/path/to/cc-resident/lib')
    from notify_log import log_sent
    log_sent("🔥 Disk almost full")          # source = calling script name

Anything else can use:  cc-resident/bin/notify --log-only "text"
"""

import json
import os
from datetime import datetime


def _log_file():
    path = os.environ.get('NOTIFY_LOG')
    if not path:
        # Same default as bin/_env.sh; read config.env if we can find it
        cfg = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'config.env')
        try:
            for line in open(cfg):
                if line.startswith('NOTIFY_LOG='):
                    path = os.path.expandvars(line.split('=', 1)[1].strip().strip('"'))
        except OSError:
            pass
    return path or os.path.expanduser('~/.local/state/cc-resident/notifications.jsonl')


def caller_name():
    """Name of the script that invoked us, skipping shells and interpreters"""
    pid = os.getppid()
    for _ in range(5):
        try:
            with open(f'/proc/{pid}/cmdline', 'rb') as f:
                args = [a.decode(errors='replace') for a in f.read().split(b'\0') if a]
            with open(f'/proc/{pid}/stat') as f:
                ppid = int(f.read().rsplit(')', 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
        for arg in args:
            name = os.path.basename(arg.split()[0]) if arg.strip() else ''
            if name.endswith(('.pl', '.py', '.sh', '.rb', '.js')):
                return name
        if ppid <= 1:
            break
        pid = ppid
    return 'unknown'


def log_sent(text, source=None, kind='text'):
    path = _log_file()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        entry = {
            'ts': datetime.now().isoformat(timespec='seconds'),
            'source': source or caller_name(),
            'kind': kind,
            'text': text,
        }
        with open(path, 'a') as f:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except OSError as e:
        print(f"Warning: could not log notification - {e}")
