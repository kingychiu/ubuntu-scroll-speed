# ubuntu-scroll-speed

Control mouse-wheel scroll **speed** on Ubuntu / X11 / Wayland — both **faster
and slower** — from a single slider.

Most guides reach for [`imwheel`](https://github.com/somebodyfsf/imwheel), but
imwheel can only *multiply* wheel clicks: it speeds scrolling up and **cannot
slow it down** below one notch. libinput/xinput expose no wheel-speed setting
either. So this tool works one layer lower: a small daemon intercepts the raw
wheel events with **evdev** and re-emits them through a **uinput** virtual
pointer, scaled by a factor you choose. Below 100% genuinely slows the wheel;
above 100% speeds it up.

It scales the high-resolution wheel axes too, and uses a fractional accumulator,
so slowing down stays smooth (e.g. 50% = one logical notch per two physical
notches) instead of jerky.

## How it works

```
real wheel  --grab-->  wheel-scale-daemon.py  --scale FACTOR-->  uinput virtual pointer  -->  apps
```

- `wheel-scale-daemon.py` — grabs every wheel-capable pointer, re-emits all
  events, scaling the wheel axes by `FACTOR` from the config file.
- `ubuntu-scroll-speed.sh` — a zenity slider (10–400 %) that writes the factor
  and signals the daemon to reload live.
- The grab is released automatically if the daemon ever exits, so your pointer
  keeps working even if something goes wrong — important over a remote KVM.

## Install

```sh
git clone https://github.com/kingychiu/ubuntu-scroll-speed.git
cd ubuntu-scroll-speed
./install.sh
```

`install.sh` will (with `sudo` where needed):

1. install `python3-evdev`, `zenity`, `libnotify-bin`;
2. install the daemon to `~/.local/bin` and a **systemd `--user` service**;
3. add a udev rule so the `input` group may open `/dev/uinput`;
4. add you to the `input` group (read access to input devices).

If you were just added to the `input` group, **log out and back in** (group
membership only applies to new sessions), then:

```sh
systemctl --user start ubuntu-scroll-speed.service
```

## Usage

Run the slider any time to change speed:

```sh
./ubuntu-scroll-speed.sh
```

- **< 100 %** — slower scrolling (e.g. 50 % = half speed)
- **100 %** — normal
- **> 100 %** — faster scrolling

The setting is saved to `~/.config/ubuntu-scroll-speed/config` and applied
immediately to the running daemon.

Bind `ubuntu-scroll-speed.sh` to a keyboard shortcut or add it to your
launcher for quick access.

## Service control

```sh
systemctl --user status  ubuntu-scroll-speed.service   # check it's running
systemctl --user restart ubuntu-scroll-speed.service   # restart
systemctl --user stop    ubuntu-scroll-speed.service   # disable scaling
journalctl --user -u ubuntu-scroll-speed.service       # logs
```

## Uninstall

```sh
systemctl --user disable --now ubuntu-scroll-speed.service
rm ~/.local/bin/wheel-scale-daemon.py
rm ~/.config/systemd/user/ubuntu-scroll-speed.service
sudo rm /etc/udev/rules.d/99-uinput.rules
# optional: sudo gpasswd -d "$USER" input
```

## Requirements

- Linux with evdev/uinput (any modern kernel) — works on both X11 and Wayland.
- `python3-evdev`, `zenity`, `libnotify-bin` (installed by `install.sh`).

## License

MIT — see [LICENSE](LICENSE). Inspired by older imwheel-based scripts, but
re-implemented at the evdev layer to support slowing down, which imwheel cannot.
