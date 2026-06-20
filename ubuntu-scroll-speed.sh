#!/usr/bin/env bash
# ubuntu-scroll-speed — GUI control of mouse wheel scroll speed via imwheel.
# Bipolar slider: negative = slower (event delay), 0 = normal, positive = faster (click multiplier).
# Adapted from a 2013 script by Nick Norton (nicknorton.net).

set -euo pipefail

IMWHEELRC="$HOME/.imwheelrc"
STATE_DIR="$HOME/.config/ubuntu-scroll-speed"
STATE_FILE="$STATE_DIR/state"

for cmd in imwheel zenity; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: '$cmd' is not installed. install with: sudo apt install $cmd" >&2
        exit 1
    fi
done

if [ ! -f "$IMWHEELRC" ]; then
    cat > "$IMWHEELRC" <<'EOF'
".*"
None,      Up,   Button4, 1
None,      Down, Button5, 1
Control_L, Up,   Control_L|Button4
Control_L, Down, Control_L|Button5
Shift_L,   Up,   Shift_L|Button4
Shift_L,   Down, Shift_L|Button5
EOF
fi

mkdir -p "$STATE_DIR"
CURRENT=0
if [ -f "$STATE_FILE" ]; then
    read -r CURRENT < "$STATE_FILE" || CURRENT=0
    [[ "$CURRENT" =~ ^-?[0-9]+$ ]] || CURRENT=0
fi

NEW=$(zenity --scale \
    --title="Scroll Speed" \
    --text="Mouse wheel speed   (-50 = slowest · 0 = normal · 100 = fastest)" \
    --min-value=-50 \
    --max-value=100 \
    --value="$CURRENT" \
    --step=1 \
    --ok-label="Apply" \
    --window-icon=info) || exit 0

[ -z "$NEW" ] && exit 0

# Positive: speed up via click multiplier. Non-positive: slow down via per-event delay.
if [ "$NEW" -ge 0 ]; then
    MULT=$((NEW + 1))
    DELAY=0
else
    MULT=1
    DELAY=$(( -NEW * 10 ))
fi

# Only the "None, ..., Button4, N" / "Button5, N" lines have a comma after the button name,
# so the Control_L|Button4 / Shift_L|Button4 modifier lines are left untouched.
sed -i "s/\(Button4, *\).*/\1$MULT/" "$IMWHEELRC"
sed -i "s/\(Button5, *\).*/\1$MULT/" "$IMWHEELRC"

echo "$NEW" > "$STATE_FILE"

# -D/-U only take effect at process start, so a kill-and-relaunch is required to change delay.
pkill -x imwheel 2>/dev/null || true
sleep 0.2
if [ "$DELAY" -gt 0 ]; then
    imwheel -b "4 5" -D "$DELAY" -U "$DELAY"
else
    imwheel -b "4 5"
fi
