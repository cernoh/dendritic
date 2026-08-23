#!/bin/sh
set -eu

Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &

python /opt/agentwebsearch/chrome_launcher.py start
exec python /opt/agentwebsearch/mcp_server.py --sse --port 8902
