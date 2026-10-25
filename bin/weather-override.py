#!/usr/bin/env python3
"""Cloud-based grid OFF override.
  evening: tomorrow avg cloud > 70% -> grid_override.sh on, notify
  morning: if an override file exists, clear it via grid_override.sh status, notify
"""
import os
import subprocess
import sys

sys.path.insert(0, '/opt/tapo')
import weather_alert

THRESHOLD = 70
OVERRIDE_FILE = '/tmp/avoid_grid_off_today'
SCRIPT = '/opt/tapo/grid_override.sh'


def notify(text):
    subprocess.run(['/usr/bin/python3', '/opt/tel-bot/mybot.py', '--text', text])


def evening():
    f = weather_alert.get_tomorrow_forecast()
    if not f:
        notify("⚠️ Weather override: could not fetch tomorrow's forecast, override not changed")
        return
    avg, peak = f['cloud_cover_avg'], f['cloud_cover_max']
    if avg > THRESHOLD:
        subprocess.run([SCRIPT, 'on'], check=True)
        notify(f"🛡️ Grid OFF override ENABLED for {f['date']}\n"
               f"☁️ Cloud cover {avg:.0f}% avg, {peak:.0f}% peak (> {THRESHOLD}%)\n"
               f"Grid stays ON; override ends automatically at 08:00 tomorrow.")
    else:
        print(f"Cloud {avg:.0f}% <= {THRESHOLD}%, no override")


def morning():
    if not os.path.exists(OVERRIDE_FILE):
        print("No override active")
        return
    subprocess.run([SCRIPT, 'status'])  # clears it once past 08:00
    if os.path.exists(OVERRIDE_FILE):
        notify("⚠️ Grid OFF override is still active after 08:05, please check")
    else:
        notify("✅ Grid OFF override ended, normal grid schedule is back")


if __name__ == '__main__':
    {'evening': evening, 'morning': morning}[sys.argv[1]]()
