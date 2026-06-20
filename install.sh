#!/usr/bin/env bash
# install.sh — set up the ubuntu-scroll-speed wheel-scaling daemon.
#
# Installs dependencies, grants non-root access to input devices and /dev/uinput,
# installs the daemon + a systemd --user service, and starts it.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
DAEMON="wheel-scale-daemon.py"
SERVICE="ubuntu-scroll-speed.service"

echo "==> Installing dependencies (sudo)"
sudo apt update -qq
sudo apt install -y python3-evdev zenity libnotify-bin

echo "==> Installing daemon to $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 0755 "$SRC_DIR/$DAEMON" "$BIN_DIR/$DAEMON"

echo "==> Installing systemd --user service to $UNIT_DIR"
mkdir -p "$UNIT_DIR"
install -m 0644 "$SRC_DIR/systemd/$SERVICE" "$UNIT_DIR/$SERVICE"

echo "==> Installing udev rule for /dev/uinput (sudo)"
sudo install -m 0644 "$SRC_DIR/udev/99-uinput.rules" /etc/udev/rules.d/99-uinput.rules
sudo udevadm control --reload-rules
sudo udevadm trigger /dev/uinput || true

NEED_RELOGIN=0
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx input; then
    echo "==> Adding $USER to the 'input' group (sudo)"
    sudo usermod -aG input "$USER"
    NEED_RELOGIN=1
fi

echo "==> Cleaning up artifacts from the old imwheel version"
# Earlier releases drove imwheel and left these behind; the daemon doesn't use them.
pkill -x imwheel 2>/dev/null || true
rm -f "$HOME/.config/ubuntu-scroll-speed/state"
if [ -f "$HOME/.imwheelrc" ] && grep -q 'Button4, *[0-9]' "$HOME/.imwheelrc" 2>/dev/null; then
    echo "    note: found ~/.imwheelrc — remove it if you only used it for scroll speed"
fi

echo "==> Enabling the service"
systemctl --user daemon-reload
systemctl --user enable "$SERVICE"

if [ "$NEED_RELOGIN" -eq 1 ]; then
    cat <<EOF

Almost done. You were just added to the 'input' group, which only takes effect
after a fresh login. Log out and back in (or reboot), then run:

    systemctl --user start $SERVICE
    ./ubuntu-scroll-speed.sh

EOF
else
    systemctl --user start "$SERVICE"
    echo
    echo "Done. Run ./ubuntu-scroll-speed.sh to set the speed."
fi
