---
name: machine-status
description: Quick status of this machine - watched services and containers, disk, memory, uptime, plus any machine-specific checks. Use when the owner asks "status", "how is the server", "is everything ok?" or similar.
---

Run `bin/status.sh` from the project folder and summarize it for Telegram in 5-8
short lines: anything down first (with a ❌), then the machine-specific lines
(from local/status-extra.sh, if any), then disk, memory and uptime.

If something is down, check its recent logs (`journalctl -u <unit> -n 30 --no-pager`,
`docker logs --tail 30 <container>`, or the log paths in local/machine.md) and say
in one line what you think is wrong, then ask before restarting anything.
