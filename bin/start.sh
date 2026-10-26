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

if [ "$TELEGRAM_ENABLED" = 1 ]; then
    tmux new-session -d -s "$TMUX_SESSION" -n telegram -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh telegram"
    tmux new-window -t "$TMUX_SESSION" -n rc -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh rc"
else
    tmux new-session -d -s "$TMUX_SESSION" -n rc -c "$CCR_DIR" "$CCR_DIR/bin/run-window.sh rc"
fi

echo "started (tmux attach -t $TMUX_SESSION)"
