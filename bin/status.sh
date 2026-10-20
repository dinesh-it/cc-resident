#!/bin/bash

# Compact machine status for the SessionStart hook, the machine-status skill
# and the "back up" message. Lists only problems for watched units/containers.
# Machine-specific lines (battery, sensors...) go in local/status-extra.sh.

. "$(dirname "$0")/_env.sh"

echo "$(hostname) status at $(date '+%Y-%m-%d %H:%M')"

problems=0
for unit in $WATCH_UNITS; do
    state=$(systemctl is-active "$unit")
    [ "$state" = "active" ] || { echo "❌ $unit: $state"; problems=1; }
done
for c in $WATCH_CONTAINERS; do
    state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)
    [ "$state" = "running" ] || { echo "❌ container $c: $state"; problems=1; }
done
[ -n "$WATCH_UNITS$WATCH_CONTAINERS" ] && [ $problems = 0 ] && echo "✅ All watched services running"

[ -x "$CCR_DIR/local/status-extra.sh" ] && "$CCR_DIR/local/status-extra.sh"

echo "Disk /: $(df -h --output=pcent,avail / | tail -1 | xargs)"
echo "Memory available: $(awk '/MemAvailable/{printf "%.1f GB", $2/1048576}' /proc/meminfo)"
echo "Uptime: $(uptime -p)"
