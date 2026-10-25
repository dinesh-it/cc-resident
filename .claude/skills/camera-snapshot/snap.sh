#!/bin/bash
# usage: snap.sh <camera-name> <out.jpg>   e.g. snap.sh dd-back-door /tmp/x.jpg
# Reads the RTSP URL from ~/view_all_new.py; never prints credentials.
name="$1"; out="$2"
url=$(grep -o "rtsp://[^\"]*${name}[^\"]*" "$HOME/view_all_new.py" | head -1)
[ -z "$url" ] && { echo "no camera matching '$name'"; exit 1; }
ffmpeg -hide_banner -loglevel error -rtsp_transport tcp -i "$url" -frames:v 1 -y "$out" 2>&1 | sed -E 's#://[^@ ]+@#://****@#g'
[ -s "$out" ] && echo "saved $out"
