---
name: voice-message
description: Transcribe a Telegram voice message from the owner and act on it. Use whenever a channel message has attachment_kind="voice" (or an audio attachment).
---

1. `download_attachment` with the message's attachment_file_id; it returns a path in the inbox.
2. Run `bin/transcribe <path>` (local faster-whisper, small model, ~10 s). Text is on
   stdout; detected language and confidence go to stderr. Short clips fall back to English
   when detection is unsure.
3. Treat the transcript as the owner's message. If it's unclear or garbled, reply with what
   you heard and ask, rather than guessing at anything risky (grid, services).
4. Briefly echo what you heard in your reply, e.g. "🎤 'send me the new report' — sent."

Setup notes: venv lives in local/stt-venv (gitignored). Audio is decoded with system ffmpeg
because the PyAV wheel pip installs (19.x) breaks faster-whisper 1.2.1's own decoder.
The health-check whitelist (/opt/tapo/services_whitelist.yaml) ignores `stt-venv` and
`bin/transcribe`.
