#!/usr/bin/env python3
"""wheel-scale-daemon — scale mouse-wheel scroll speed at the input-event layer.

imwheel can only *multiply* wheel clicks (speed up); it cannot slow scrolling
below 1 notch, and libinput/xinput expose no wheel-speed knob. This daemon works
one level lower: it grabs the real wheel-capable pointer(s) with evdev, then
re-emits every event through a uinput virtual device, scaling the wheel axes by a
configurable FACTOR. FACTOR < 1 slows scrolling, FACTOR > 1 speeds it up.

A fractional accumulator per axis means a factor of e.g. 0.5 emits one logical
notch for every two physical notches, so slow-down is smooth rather than lumpy.
High-resolution wheel axes (REL_WHEEL_HI_RES / REL_HWHEEL_HI_RES) are scaled the
same way so smooth-scrolling apps stay consistent with legacy ones.

Config: ~/.config/ubuntu-scroll-speed/config  ->  a line "FACTOR=0.5".
Send SIGHUP to reload the factor live (the GUI does this on Apply).

Safety: EVIOCGRAB is released automatically when this process exits, so if the
daemon dies the real pointer keeps working — important when the only input is a
remote KVM.
"""

import os
import sys
import signal
import selectors

try:
    from evdev import InputDevice, UInput, ecodes, list_devices
except ImportError:
    sys.exit("wheel-scale: python3-evdev is not installed (sudo apt install python3-evdev)")

CONFIG = os.path.expanduser("~/.config/ubuntu-scroll-speed/config")
VIRTUAL_NAME = "ubuntu-scroll-speed virtual pointer"

# Wheel axes we scale. HI_RES codes exist on kernels >= 5.0 / recent evdev.
REL_WHEEL_HI_RES = getattr(ecodes, "REL_WHEEL_HI_RES", 0x0B)
REL_HWHEEL_HI_RES = getattr(ecodes, "REL_HWHEEL_HI_RES", 0x0C)
WHEEL_CODES = {ecodes.REL_WHEEL, ecodes.REL_HWHEEL, REL_WHEEL_HI_RES, REL_HWHEEL_HI_RES}


def read_factor():
    """Return the FACTOR from the config file, defaulting to 1.0 (no change)."""
    factor = 1.0
    try:
        with open(CONFIG) as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("FACTOR="):
                    factor = float(line.split("=", 1)[1])
    except (FileNotFoundError, ValueError):
        pass
    return factor if factor > 0 else 1.0


def find_wheel_devices():
    """Open every pointer that has a vertical wheel, skipping our own virtual one."""
    devices = []
    for path in list_devices():
        try:
            dev = InputDevice(path)
        except OSError:
            continue
        rel = dev.capabilities().get(ecodes.EV_REL, [])
        if ecodes.REL_WHEEL in rel and VIRTUAL_NAME.lower() not in dev.name.lower():
            devices.append(dev)
        else:
            dev.close()
    return devices


def main():
    state = {"factor": read_factor()}
    accum = {}  # (device_path, axis_code) -> carried fractional remainder

    devices = find_wheel_devices()
    if not devices:
        sys.exit("wheel-scale: no wheel-capable pointer found")

    uinputs = {}
    grabbed = []
    for dev in devices:
        try:
            dev.grab()
            grabbed.append(dev)
        except OSError as exc:
            print(f"wheel-scale: cannot grab {dev.path}: {exc}", file=sys.stderr)
            continue
        uinputs[dev.path] = UInput.from_device(dev, name=VIRTUAL_NAME)

    if not uinputs:
        sys.exit("wheel-scale: could not grab any wheel device (is the user in the 'input' group?)")

    def cleanup(*_):
        for dev in grabbed:
            try:
                dev.ungrab()
            except OSError:
                pass
        for ui in uinputs.values():
            ui.close()
        sys.exit(0)

    def reload(*_):
        state["factor"] = read_factor()

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGHUP, reload)

    print(f"wheel-scale: scaling {len(uinputs)} device(s) by factor {state['factor']}",
          file=sys.stderr)

    sel = selectors.DefaultSelector()
    for dev in grabbed:
        sel.register(dev, selectors.EVENT_READ)

    try:
        while True:
            for key, _ in sel.select():
                dev = key.fileobj
                ui = uinputs[dev.path]
                try:
                    events = list(dev.read())
                except OSError:
                    continue
                for ev in events:
                    if ev.type == ecodes.EV_REL and ev.code in WHEEL_CODES:
                        akey = (dev.path, ev.code)
                        carried = accum.get(akey, 0.0) + ev.value * state["factor"]
                        out = int(carried)  # truncate toward zero
                        accum[akey] = carried - out
                        if out != 0:
                            ui.write(ecodes.EV_REL, ev.code, out)
                    else:
                        # Forward everything else verbatim, including EV_SYN frames.
                        ui.write(ev.type, ev.code, ev.value)
    finally:
        cleanup()


if __name__ == "__main__":
    main()
