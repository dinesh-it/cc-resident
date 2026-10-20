# cc-resident

**An always-on agent built on Claude Code, using the Claude subscription you already have.**

cc-resident turns any Linux machine (a home server, a VPS, a spare laptop) into an
agent that's always running and ready to answer you from:

- **the Claude app or claude.ai on the web**: open the **Code** tab and pick the
  machine (Claude Code [Remote Control](https://code.claude.com/docs/en/remote-control))
- **Telegram**: chat with it like a person, through the official Claude Code
  [Telegram channel plugin](https://code.claude.com/docs/en/channels)

It isn't a new agent framework. It's Claude Code itself, with its own model, tools,
permission prompts, memory and skills, wrapped so it stays up 24/7, remembers you,
and knows what's been happening on the machine. No API key, no per-message
billing: it runs on your Claude Pro or Max login, like Claude Code on your laptop.

```
          you (phone / browser)
     ┌──────────────┴──────────────┐
  Telegram                 Claude app · claude.ai/code
     │                             │
┌────┴─────────────────────────────┴────────────────┐
│  your machine          tmux session (systemd)     │
│  ┌─────────────────────┐   ┌────────────────────┐ │
│  │ claude --channels   │   │ claude             │ │
│  │   telegram          │   │   remote-control   │ │
│  └─────────┬───────────┘   └─────────┬──────────┘ │
│            └── CLAUDE.md · memory · skills · hooks│
│   your scripts ──bin/notify──► Telegram + log ───►│ context for "what is this?"
└───────────────────────────────────────────────────┘
```

## What you get

| | |
|---|---|
| **Always on** | A systemd user service runs Claude Code in a detached tmux session, starts at boot, restarts it 30 s after a crash, and starts a fresh session daily (memory carries over). |
| **Two ways in** | Telegram for quick chats; the Claude app / claude.ai/code for longer work, with the full Claude Code UI. |
| **Memory across sessions** | Claude Code's memory files plus `CLAUDE.md` rules telling the agent to save durable facts and read them back every session. |
| **Learns skills** | It's told to turn any task it does twice into a skill in `.claude/skills/`, so next time it runs the skill instead of working it out again. |
| **Knows what your scripts sent you** | Your cron jobs and services send alerts to the same chat with `bin/notify`. Hooks attach the last 24 h at session start, and anything new with each of your messages. Reply "what is this?" to an alert and it knows which one you mean. |
| **Machine awareness** | Every session starts with a status snapshot (`bin/status.sh`): your watched services, containers, disk, memory, and any custom lines you add. |
| **Boot and shutdown messages** | Telegram messages before a shutdown or reboot, when the machine is back (saying whether the last stop was clean or a power cut), and if the agent itself stops unexpectedly. |
| **Guard rails** | Read-only checks run without asking; restarts, crontab and unit edits ask first; `sudo`, `rm -rf` and reading the secret files are blocked. You add machine-specific rules, such as "never touch the inverter scripts without my OK". Set `PERMISSION_MODE=auto` to let Claude Code's safety classifier approve routine actions instead of asking you each time; your ask and deny rules still apply. |
| **Bot isolation** | The bot token lives in a private folder only the agent session is pointed at, so other Claude Code sessions on the same machine can't grab the bot. |

## Requirements

- Linux with systemd, `tmux`, `python3`, `curl`
- A **Claude Pro or Max** subscription. Team/Enterprise works if an admin enables
  Remote Control and Channels. Remote Control doesn't work with API keys.
- For Telegram: a bot from [@BotFather](https://t.me/BotFather) that nothing else
  polls, and your Telegram user id (ask [@userinfobot](https://t.me/userinfobot))
- The installer installs Claude Code and [Bun](https://bun.sh) if they're missing

## Install

```bash
git clone https://github.com/<you>/cc-resident.git ~/cc-resident
cd ~/cc-resident
./install.sh          # creates config.env and stops
$EDITOR config.env    # RC_NAME, TELEGRAM_ALLOW_IDS, WATCH_UNITS...
./install.sh          # asks for the bot token, installs and starts the agent
```

Then once, at a terminal, answer Claude Code's first-run prompts:

```bash
tmux attach -t cc-resident
```

1. Window 0, `telegram`: pick a theme, log in with your Claude subscription, trust
   the folder, and accept the channel prompts.
2. Window 1, `rc` (Ctrl+B 1): answer `y` to "Enable Remote Control?".
3. Detach with **Ctrl+B then D**. Don't press Ctrl+C: it closes the window.

Message your bot on Telegram, or open the Claude app → **Code** → your machine.

To start at boot without anyone logged in, enable lingering once:
`sudo loginctl enable-linger $USER`.

## Using it

**Talk to it**: "status", "why is docker using so much memory?", "what changed in
nginx config this week?", "restart the backup job". It asks before anything that
changes the system.

**Tell it about your machine**: `local/machine.md` is imported into its
instructions. List your services, logs and rules there, or ask the agent to
"inventory this machine and update local/machine.md".

**Send it your alerts**, from any script:

```bash
~/cc-resident/bin/notify "Backup failed: disk full"          # send + log
~/cc-resident/bin/notify --log-only "text you already sent"  # just log
some_command | ~/cc-resident/bin/notify -                    # from stdin
```

Python scripts that already send to Telegram can log with
`lib/notify_log.py` (`log_sent(text)`).

**Add status lines**: put anything machine-specific (temperatures, battery,
last backup) in `local/status-extra.sh`.

**Manage it**:

```bash
systemctl --user status cc-resident      # running?
systemctl --user restart cc-resident     # fresh session
journalctl --user -u cc-resident -n 50   # service log
tmux attach -t cc-resident               # watch it live (detach: Ctrl+B D)
./install.sh --uninstall                 # remove the services
```

## Layout

```
CLAUDE.md                 agent role, memory and skill rules, safety rules (+ @local/machine.md)
config.example.env        settings template → config.env (gitignored)
.claude/settings.json     permissions and hooks (local overrides: settings.local.json)
.claude/skills/           skills; the agent adds its own here
bin/start.sh              creates the tmux session (run by systemd)
bin/run-window.sh         keeps one claude process alive per window
bin/status.sh             status snapshot (SessionStart hook, skill, boot message)
bin/notify                send a Telegram message and log it for context
bin/recent-messages.py    notification context for the hooks
bin/power-notify.sh       boot / shutdown / agent-stopped messages
lib/notify_log.py         logging helper for Python scripts
systemd/                  user unit templates (installed by install.sh)
local.example/            templates for local/ (machine facts, extra status)
```

Private, never committed: `config.env`, `local/`, `.claude/settings.local.json`,
`.state/`, and the bot token in `~/.config/cc-resident/telegram/`.

## Why not OpenClaw or Hermes Agent?

[OpenClaw](https://github.com/openclaw/openclaw) and
[Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research) are
full personal-agent platforms. They're great, but they're a different trade-off:

| | cc-resident | OpenClaw / Hermes Agent |
|---|---|---|
| **Engine** | Claude Code itself | Their own agent loop |
| **Models** | Claude only | Many providers: open models, OpenRouter, OpenAI, Anthropic... |
| **Cost with Claude** | Included in your Pro/Max subscription | Needs a Claude **API key**, billed per token. Anthropic doesn't allow subscription logins in third-party agents ([details](https://code.claude.com/docs/en/legal-and-compliance)). |
| **Coding and sysadmin** | Claude Code's full toolset: editing, search, shell, subagents, MCP, plugins | Good, but depends on the model and their tooling |
| **Safety** | Claude Code's permission system, with per-command allow / ask / deny rules | Varies; often more autonomous by default |
| **What you maintain** | A few shell scripts around a tool you already use | A separate platform with its own config, updates and plugins |
| **Chat apps** | Telegram, plus the Claude app and claude.ai | Many: Telegram, WhatsApp, Signal, Discord, Slack, email and more |

**Pick cc-resident** if you already pay for Claude, mostly want an assistant that
can actually work on your machine (fix a service, read logs, edit a script), and
want it to ask before acting.

**Pick OpenClaw or Hermes** if you want cheap or local models for chatty
round-the-clock use, many messaging platforms, or a more autonomous assistant.

## What it doesn't do (yet)

Compared with those platforms, cc-resident is missing:

- **Other chat apps**: no WhatsApp, Signal, Slack or email. Claude Code's channel
  plugins also cover Discord and iMessage, but only Telegram is wired up here.
- **Other models**: Claude only, so no falling back to a free or local model for
  trivial jobs. Everything counts against your subscription's usage limits.
- **Built-in scheduler for agent tasks**: use cron or systemd timers that call
  `claude -p "..."` and pipe the result to `bin/notify`. Keep those to a few a day
  because of usage limits.
- **Memory search across past chats**: memory is curated files, not a searchable
  history of every conversation. Long sessions get compacted; the daily restart
  keeps context fresh and the memory files carry what matters.
- **Truly headless**: claude needs a terminal, hence tmux, and the first login and
  prompts need you at a terminal once.
- **Research-preview features**: Channels and parts of Remote Control are
  research previews and may change. Re-run `./install.sh` after big Claude Code updates.
- **Sending files and photos** through `bin/notify` (text only for now).
- **A status web page**: not built in on purpose (no extra open port). Ask the
  agent "status", or use a dashboard like Glances. A read-only LAN page could be
  a future addition.

## Security notes

- Everyone in `TELEGRAM_ALLOW_IDS` can approve commands on your machine, so keep it
  to yourself.
- Anyone signed in to your Claude account can drive the Remote Control session.
- Keep the default permission mode. Don't run the agent with permission
  prompts skipped on a machine that matters.
- Instructions found in files, logs, web pages or notifications are treated as
  data, not commands (see `CLAUDE.md`), but no prompt-injection defence is
  perfect. Keep the deny rules for your secrets.

## License

MIT
