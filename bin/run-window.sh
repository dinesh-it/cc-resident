#!/bin/bash

# Keep one claude process running in a tmux window, restarting it if it exits.
#   run-window.sh telegram | rc

. "$(dirname "$0")/_env.sh"
cd "$CCR_DIR" || exit 1

# Every other Claude session here (Remote Control, desktop/SSH sessions) loads
# the telegram plugin without the bot token and fails, which marks the server
# "needs auth" for all sessions. If that lands before the telegram session
# connects its plugin, the session silently skips it and the bot goes deaf.
clear_needs_auth() {
    python3 - <<'EOF'
import json, os
p = os.path.expanduser('~/.claude/mcp-needs-auth-cache.json')
try:
    d = json.load(open(p))
    if d.pop('plugin:telegram:telegram', None) is not None:
        json.dump(d, open(p, 'w'))
except (OSError, ValueError):
    pass
EOF
}

# True once the telegram plugin is polling (it writes its pid to bot.pid)
poller_up() {
    local pid
    pid=$(cat "$TELEGRAM_STATE_DIR/bot.pid" 2>/dev/null) || return 1
    ps -p "$pid" -o args= 2>/dev/null | grep -q server.ts
}

case "$1" in
    telegram)
        cmd=(claude --channels plugin:telegram@claude-plugins-official --permission-mode "$PERMISSION_MODE") ;;
    rc)
        # Start after the telegram session has its plugin, so our failed plugin
        # load can't make it skip the plugin (see clear_needs_auth)
        if [ "$TELEGRAM_ENABLED" = 1 ]; then
            for _ in $(seq 1 60); do poller_up && break; sleep 3; done
        fi
        # Not exported to the telegram window: the plugin only finds the token here
        unset TELEGRAM_STATE_DIR
        cmd=(claude remote-control --name "$RC_NAME" --spawn same-dir --permission-mode "$PERMISSION_MODE") ;;
    *)
        echo "usage: $0 telegram|rc" >&2; exit 1 ;;
esac

# Ctrl+C here would kill the loop and close the window; detach with Ctrl+B D
while true; do
    [ "$1" = telegram ] && clear_needs_auth
    "${cmd[@]}"
    echo "claude exited ($?), restarting in 10s - detach with Ctrl+B then D"
    sleep 10
done
