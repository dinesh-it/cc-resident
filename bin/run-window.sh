#!/bin/bash

# Keep one claude process running in a tmux window, restarting it if it exits.
#   run-window.sh telegram | rc

. "$(dirname "$0")/_env.sh"
cd "$CCR_DIR" || exit 1

case "$1" in
    telegram)
        cmd=(claude --channels plugin:telegram@claude-plugins-official --permission-mode "$PERMISSION_MODE") ;;
    rc)
        # Not exported to the telegram window: the plugin only finds the token here
        unset TELEGRAM_STATE_DIR
        cmd=(claude remote-control --name "$RC_NAME" --spawn same-dir --permission-mode "$PERMISSION_MODE") ;;
    *)
        echo "usage: $0 telegram|rc" >&2; exit 1 ;;
esac

# Ctrl+C here would kill the loop and close the window; detach with Ctrl+B D
while true; do
    "${cmd[@]}"
    echo "claude exited ($?), restarting in 10s - detach with Ctrl+B then D"
    sleep 10
done
