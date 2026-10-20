# Sourced by the bin/ scripts: repo dir, config.env, defaults.

CCR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CCR_DIR

if [ -f "$CCR_DIR/config.env" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$CCR_DIR/config.env"
    set +a
fi

: "${RC_NAME:=$(hostname)}"
: "${TMUX_SESSION:=cc-resident}"
: "${TELEGRAM_ENABLED:=0}"
: "${TELEGRAM_STATE_DIR:=$HOME/.config/cc-resident/telegram}"
: "${NOTIFY_LOG:=$HOME/.local/state/cc-resident/notifications.jsonl}"
: "${POWER_NOTIFY:=1}"
export RC_NAME TMUX_SESSION TELEGRAM_ENABLED TELEGRAM_STATE_DIR TELEGRAM_ALLOW_IDS \
    NOTIFY_LOG POWER_NOTIFY WATCH_UNITS WATCH_CONTAINERS DAILY_RESTART

export PATH="$HOME/.local/bin:$HOME/.bun/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
CCR_STATE="$CCR_DIR/.state"
mkdir -p "$CCR_STATE"
