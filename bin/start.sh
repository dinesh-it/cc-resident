#!/bin/bash

# Start the agent in a detached tmux session (claude needs a terminal):
#   window "telegram" - Claude Code with the Telegram channel (if enabled)
#   window "rc"       - Claude Code Remote Control (Claude app → Code)
# Normally run by the cc-resident systemd user service.

. "$(dirname "$0")/_env.sh"
cd "$CCR_DIR" || exit 1

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "already running (tmux attach -t $TMUX_SESSION)"
    exit 0
fi

# Other Claude sessions on this machine load the telegram plugin without the
# bot token and fail, which marks the server "needs auth" for every session
# and makes the agent's next start skip it
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

if [ "$TELEGRAM_ENABLED" = 1 ]; then
    tmux new-session -d -s "$TMUX_SESSION" -n telegram -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh telegram"
    tmux new-window -t "$TMUX_SESSION" -n rc -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh rc"
else
    tmux new-session -d -s "$TMUX_SESSION" -n rc -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh rc"
fi

echo "started (tmux attach -t $TMUX_SESSION)"
