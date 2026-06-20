#!/usr/bin/env bash
# ubuntu-scroll-speed — GUI to set mouse wheel scroll speed.
#
# Drives the wheel-scale daemon (evdev -> uinput interceptor). The slider is a
# percentage of normal speed: 50 = half speed (slow), 100 = normal, 300 = triple.
# Below 100 genuinely slows scrolling — something imwheel cannot do.

set -euo pipefail

CONFIG_DIR="$HOME/.config/ubuntu-scroll-speed"
CONFIG="$CONFIG_DIR/config"
DAEMON_NAME="wheel-scale-daemon.py"
SERVICE="ubuntu-scroll-speed.service"

command -v zenity >/dev/null 2>&1 || {
    echo "error: zenity is not installed (sudo apt install zenity)" >&2
    exit 1
}

mkdir -p "$CONFIG_DIR"

# Read current factor (default 1.0) and convert to a percentage for the slider.
CURRENT_FACTOR=1.0
if [ -f "$CONFIG" ]; then
    val=$(sed -n 's/^FACTOR=//p' "$CONFIG" | tail -n1)
    [[ "$val" =~ ^[0-9]*\.?[0-9]+$ ]] && CURRENT_FACTOR="$val"
fi
CURRENT_PCT=$(awk -v f="$CURRENT_FACTOR" 'BEGIN { printf "%d", f * 100 + 0.5 }')

NEW_PCT=$(zenity --scale \
    --title="Scroll Speed" \
    --text="Mouse wheel speed (% of normal)   ·   below 100 = slower, above 100 = faster" \
    --min-value=10 \
    --max-value=400 \
    --value="$CURRENT_PCT" \
    --step=5 \
    --ok-label="Apply") || exit 0

[ -z "$NEW_PCT" ] && exit 0

NEW_FACTOR=$(awk -v p="$NEW_PCT" 'BEGIN { printf "%.2f", p / 100 }')
printf 'FACTOR=%s\n' "$NEW_FACTOR" > "$CONFIG"

# Apply live: tell a running daemon to reload (SIGHUP); otherwise start it.
if pkill -HUP -f "$DAEMON_NAME" 2>/dev/null; then
    notify="Scroll speed set to ${NEW_PCT}%."
elif systemctl --user start "$SERVICE" 2>/dev/null; then
    notify="Scroll speed set to ${NEW_PCT}% (daemon started)."
else
    notify="Saved ${NEW_PCT}%, but the daemon isn't running. See README to install the service."
fi

command -v notify-send >/dev/null 2>&1 && notify-send "Scroll Speed" "$notify" || echo "$notify"
