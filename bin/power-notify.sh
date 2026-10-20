#!/bin/bash

# Telegram messages when the machine goes down / comes back up, and when the
# agent stops unexpectedly.
#   power-notify.sh up            boot (cc-resident-power.service ExecStart)
#   power-notify.sh down          shutdown (cc-resident-power.service ExecStop)
#   power-notify.sh agent-stop    cc-resident.service ExecStopPost
#   power-notify.sh agent-start   cc-resident.service ExecStartPost

. "$(dirname "$0")/_env.sh"
[ "$POWER_NOTIFY" = 1 ] || exit 0

CLEAN_MARK="$CCR_STATE/clean-shutdown"
AGENT_MARK="$CCR_STATE/agent-down-notified"
PLANNED_MARK="$CCR_STATE/agent-planned-restart"
BOOT_MARK="$CCR_STATE/announced-boot"

send() {
    timeout 25 "$CCR_DIR/bin/notify" --source power-notify "$1" >/dev/null 2>&1
}

wait_for_network() {
    for _ in $(seq 1 40); do
        curl -s -m 5 -o /dev/null https://api.telegram.org && return 0
        sleep 3
    done
    return 1
}

shutdown_kind() {
    case "$(systemctl list-jobs --no-legend 2>/dev/null)" in
        *reboot.target*) echo "rebooting" ;;
        *poweroff.target*|*halt.target*) echo "powering off" ;;
        *) echo "shutting down" ;;
    esac
}

now() { date '+%Y-%m-%d %H:%M:%S'; }
host=$(hostname)

case "$1" in
    up)
        wait_for_network
        # Service (re)started during a boot we already announced: not a power event
        boot_id=$(cat /proc/sys/kernel/random/boot_id)
        if [ "$(cat "$BOOT_MARK" 2>/dev/null)" = "$boot_id" ]; then
            send "🔔 Shutdown/boot notifications are on for $host ($(now))"
            exit 0
        fi
        echo "$boot_id" > "$BOOT_MARK"
        if [ -f "$CLEAN_MARK" ]; then
            msg="✅ $host is back up
Booted: $(uptime -s)
Went down: $(cat "$CLEAN_MARK") (clean shutdown)"
        else
            msg="⚠️ $host is back up after an UNEXPECTED stop (power cut, crash or hard reset)
Booted: $(uptime -s)
What happened before: journalctl -b -1 -n 30"
        fi
        rm -f "$CLEAN_MARK" "$AGENT_MARK" "$PLANNED_MARK"
        # Let boot finish so services still starting aren't reported as down
        timeout 150 systemctl is-system-running --wait >/dev/null 2>&1
        sleep 15
        send "$msg

$("$CCR_DIR/bin/status.sh" | tail -n +2)"
        ;;
    down)
        now > "$CLEAN_MARK"
        send "🔌 $host is $(shutdown_kind) at $(now)
Uptime was: $(uptime -p | sed 's/^up //')"
        ;;
    agent-stop)
        # Covered by the shutdown message, or a planned daily restart
        [ "$(systemctl is-system-running 2>/dev/null)" = "stopping" ] && exit 0
        [ -f "$PLANNED_MARK" ] && exit 0
        touch "$AGENT_MARK"
        send "❌ cc-resident agent on $host stopped at $(now) (result: ${SERVICE_RESULT:-unknown}, exit: ${EXIT_STATUS:-?})
systemd will try to restart it in 30 s."
        ;;
    agent-start)
        rm -f "$PLANNED_MARK"
        if [ -f "$AGENT_MARK" ]; then
            rm -f "$AGENT_MARK"
            send "✅ cc-resident agent on $host is running again ($(now))"
        fi
        ;;
    *)
        echo "usage: $0 up|down|agent-stop|agent-start" >&2
        exit 1
        ;;
esac

exit 0
