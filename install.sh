#!/bin/bash

# cc-resident installer: run from the cloned repo as your normal user.
#   ./install.sh              set up config, Telegram, systemd user units; start
#   ./install.sh --no-start   install everything but don't start the agent
#   ./install.sh --uninstall  stop and remove the systemd user units

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
UNITS="cc-resident.service cc-resident-restart.service cc-resident-restart.timer cc-resident-power.service"
UNIT_DIR="$HOME/.config/systemd/user"

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }
die()  { printf '\033[31mxx  %s\033[0m\n' "$*" >&2; exit 1; }

if [ "$1" = "--uninstall" ]; then
    say "Stopping and removing cc-resident systemd user units"
    systemctl --user disable --now cc-resident-restart.timer cc-resident-power.service cc-resident.service 2>/dev/null || true
    for u in $UNITS; do rm -f "$UNIT_DIR/$u"; done
    systemctl --user daemon-reload
    say "Done. Config, local/ and $DIR are left as they are."
    exit 0
fi

[ "$(id -u)" = 0 ] && die "Run as your normal user, not root."

# --- Prerequisites -----------------------------------------------------------
say "Checking prerequisites"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
for cmd in tmux python3 curl systemctl; do
    command -v "$cmd" >/dev/null || die "$cmd is required (install it with your package manager)"
done
if ! command -v claude >/dev/null; then
    say "Installing Claude Code (native installer)"
    curl -fsSL https://claude.ai/install.sh | bash
fi
echo "    claude $(claude --version 2>/dev/null | head -1)"

# --- Config ------------------------------------------------------------------
if [ ! -f "$DIR/config.env" ]; then
    cp "$DIR/config.example.env" "$DIR/config.env"
    chmod 600 "$DIR/config.env"
    say "Created config.env. Edit it (at least RC_NAME and TELEGRAM_ALLOW_IDS), then run ./install.sh again."
    exit 0
fi
mkdir -p "$DIR/local" "$DIR/.state" "$DIR/logs"
[ -f "$DIR/local/machine.md" ] || cp "$DIR/local.example/machine.md" "$DIR/local/machine.md"
[ -f "$DIR/local/status-extra.sh" ] || cp "$DIR/local.example/status-extra.sh" "$DIR/local/status-extra.sh"
chmod +x "$DIR"/bin/*.sh "$DIR/bin/notify" "$DIR/bin/recent-messages.py" "$DIR/local/status-extra.sh"

. "$DIR/bin/_env.sh"
[[ "$DAILY_RESTART" =~ ^[0-9]{2}:[0-9]{2}$|^$ ]] || die "DAILY_RESTART must look like 04:30 (or be empty)"

# --- Telegram channel --------------------------------------------------------
if [ "$TELEGRAM_ENABLED" = 1 ]; then
    say "Setting up the Telegram channel"
    [ -n "$TELEGRAM_ALLOW_IDS" ] || die "Set TELEGRAM_ALLOW_IDS in config.env (your Telegram user id; ask @userinfobot)"
    if ! command -v bun >/dev/null; then
        say "Installing Bun (the telegram plugin runs on it)"
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
    fi
    if ! claude plugin list 2>/dev/null | grep -q 'telegram@claude-plugins-official'; then
        claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
        claude plugin install telegram@claude-plugins-official --scope user
    fi

    mkdir -p "$TELEGRAM_STATE_DIR" && chmod 700 "$TELEGRAM_STATE_DIR"
    if [ ! -f "$TELEGRAM_STATE_DIR/.env" ]; then
        token="${TELEGRAM_BOT_TOKEN:-}"
        if [ -z "$token" ]; then
            echo "    Create a bot with @BotFather (/newbot) and paste its token."
            echo "    Use a bot nothing else polls: two readers of one bot lose messages."
            read -rsp "    Bot token: " token; echo
        fi
        [[ "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || die "That doesn't look like a bot token"
        (umask 077; printf 'TELEGRAM_BOT_TOKEN=%s\n' "$token" > "$TELEGRAM_STATE_DIR/.env")
    fi
    # Allowlist only: unknown senders are dropped, no pairing codes
    python3 - "$TELEGRAM_STATE_DIR/access.json" $TELEGRAM_ALLOW_IDS <<'EOF'
import json, os, sys
path, ids = sys.argv[1], sys.argv[2:]
try:
    a = json.load(open(path))
except (OSError, ValueError):
    a = {'groups': {}, 'pending': {}}
a.update(dmPolicy='allowlist', allowFrom=ids)
a.setdefault('groups', {}); a['pending'] = {}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as f:
    json.dump(a, f, indent=2)
EOF
    BOT=$(. "$TELEGRAM_STATE_DIR/.env"; curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe" \
        | python3 -c 'import json,sys; print("@" + json.load(sys.stdin)["result"]["username"])' 2>/dev/null) \
        || die "Telegram rejected the bot token"
    echo "    bot $BOT, allowed users: $TELEGRAM_ALLOW_IDS"
fi

# --- systemd user units ------------------------------------------------------
say "Installing systemd user units"
mkdir -p "$UNIT_DIR"
for u in $UNITS; do
    sed -e "s#@DIR@#$DIR#g" -e "s#@DAILY_RESTART@#${DAILY_RESTART:-04:30}#g" "$DIR/systemd/$u" > "$UNIT_DIR/$u"
done
systemctl --user daemon-reload
systemctl --user enable cc-resident.service >/dev/null
if [ -n "$DAILY_RESTART" ]; then systemctl --user enable cc-resident-restart.timer >/dev/null
else systemctl --user disable cc-resident-restart.timer >/dev/null 2>&1 || true; fi
if [ "$POWER_NOTIFY" = 1 ] && [ "$TELEGRAM_ENABLED" = 1 ]; then systemctl --user enable cc-resident-power.service >/dev/null
else systemctl --user disable cc-resident-power.service >/dev/null 2>&1 || true; fi

if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != yes ]; then
    warn "Lingering is off, so the agent only runs while you're logged in. To start it at boot:"
    warn "    sudo loginctl enable-linger $USER"
fi

if [ "$1" != "--no-start" ]; then
    say "Starting the agent"
    systemctl --user restart cc-resident.service
    # This boot isn't a power event: the next start only says notifications are on
    cat /proc/sys/kernel/random/boot_id > "$DIR/.state/announced-boot"
    [ "$POWER_NOTIFY" = 1 ] && [ "$TELEGRAM_ENABLED" = 1 ] && systemctl --user start cc-resident-power.service || true
    systemctl --user start cc-resident-restart.timer 2>/dev/null || true
fi

cat <<EOF

$(say "Installed")
Next, once (claude needs you at a terminal for first-run prompts):
  tmux attach -t $TMUX_SESSION
  - window 0 "telegram": pick a theme, log in with your Claude subscription,
    trust this folder, accept the channel prompts
  - window 1 "rc" (Ctrl+B 1): answer y to "Enable Remote Control?"
  - detach with Ctrl+B then D (don't press Ctrl+C: it closes the window)
Then message ${BOT:-your bot} on Telegram, or open the Claude app → Code → $RC_NAME.

Manage: systemctl --user status|restart|stop cc-resident
EOF
