---
name: camera-snapshot
description: Send the owner a current photo from one of the house IP cameras (front-door, koki-front-door, back-door, garage). Use when asked for a photo/snapshot/view of a camera or place.
---

1. Run `.claude/skills/camera-snapshot/snap.sh <name> <scratchpad>/<name>.jpg`.
   Names (match substring in ~/view_all_new.py): dd-front-door, koki-front-door, dd-back-door, dd-garage.
2. Send the jpg with the Telegram reply tool (files: [path]), one short line of text.
3. Never print the RTSP URLs (they contain passwords).
