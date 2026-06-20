# ubuntu-scroll-speed

A small GUI to control mouse wheel scroll speed on Ubuntu (or any X11 desktop)
via [`imwheel`](https://github.com/somebodyfsf/imwheel). Supports both
**speeding up** and **slowing down** the scroll wheel from a single slider.

Adapted from a [2013 script by Nick Norton](http://www.nicknorton.net/) that
only supported speeding up the wheel.

## What it does

Opens a single zenity slider:

```
┌─ Scroll Speed ───────────────────────┐
│ Mouse wheel speed                    │
│ slower  ◀──────●──────▶  faster      │
│  -50          0           +100       │
│            [ Apply ]                 │
└──────────────────────────────────────┘
```

- **`0`** — default `imwheel` behaviour (one click per wheel tick).
- **Positive (`1` … `100`)** — sets the click multiplier in `~/.imwheelrc` so
  one wheel tick emits N+1 clicks. Useful on hi-res or slow-feeling wheels.
- **Negative (`-1` … `-50`)** — relaunches `imwheel` with `-D N -U N` so each
  emitted click takes longer (10 ms per step, up to 500 ms). Effectively
  throttles the wheel for fine-grained scrolling.

Modifier rules (`Ctrl + wheel`, `Shift + wheel`) are left untouched — the
script only edits the unmodified `Button4` / `Button5` lines.

## Install

Dependencies:

```sh
sudo apt install imwheel zenity
```

Clone and link the script:

```sh
git clone https://github.com/kingychiu/ubuntu-scroll-speed.git
cd ubuntu-scroll-speed
chmod +x ubuntu-scroll-speed.sh
sudo ln -s "$PWD/ubuntu-scroll-speed.sh" /usr/local/bin/ubuntu-scroll-speed
```

## Usage

```sh
ubuntu-scroll-speed
```

Drag the slider, hit **Apply**. The chosen position is saved to
`~/.config/ubuntu-scroll-speed/state` so the dialog re-opens where you left it.

To make the setting persist across reboots, add `imwheel -b "4 5"` (or
`imwheel -b "4 5" -D 200 -U 200` for a slow-scroll setting) to your desktop's
startup applications.

## How the slider maps

| Slider | `imwheel` config                                | Effect                          |
|-------:|-------------------------------------------------|---------------------------------|
|  `-50` | `Button4, 1` + `-D 500 -U 500`                  | Very slow, fine-grained scroll  |
|  `-10` | `Button4, 1` + `-D 100 -U 100`                  | Slightly slowed                 |
|    `0` | `Button4, 1` (default delay)                    | Normal `imwheel` behaviour      |
|   `+5` | `Button4, 6`                                    | 6 clicks per tick               |
| `+100` | `Button4, 101`                                  | Hyper-fast scroll               |

## Files touched

- `~/.imwheelrc` — created if missing, otherwise the two unmodified
  `Button4` / `Button5` lines are rewritten in place.
- `~/.config/ubuntu-scroll-speed/state` — persists the last slider value.

## License

MIT — see [`LICENSE`](./LICENSE).
