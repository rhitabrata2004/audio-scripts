# audio-scripts

Small, targeted PipeWire/EasyEffects automation scripts for specific audio
devices — as opposed to blanket "run this on every login" hacks that end up
affecting whatever output happens to be active at the time.

## jbl-sb271-autoeffects

Automatically applies an enhancement preset (bass/presence EQ boost + a
loudness-maximizing limiter) to a JBL CINEMA SB271 soundbar **only** when
that specific Bluetooth device is the one connected — every other audio
output (e.g. built-in laptop speakers) is left untouched.

### How it works

- `bin/jbl-sb271-autoeffects.sh` runs persistently, subscribing to PipeWire
  sink events via `pactl subscribe`.
- When a new sink named `bluez_output.F8_1B_D8_6C_90_F2.*` (the SB271's
  Bluetooth MAC) appears, it starts the EasyEffects service (if not already
  running) and loads the `jbl_sb271_enhance` preset.
- `presets/jbl_sb271_enhance.json` is an EasyEffects (v8.x) output preset:
  a 10-band EQ with a mild bass/presence lift and a limiter with
  `gain-boost` enabled to raise overall loudness without clipping.
- `systemd/jbl-sb271-autoeffects.service` is a `systemd --user` unit that
  keeps the watcher running across logins/restarts.

### Install

```sh
./install.sh
```

This copies the preset to `~/.local/share/easyeffects/output/`, the script
to `~/.local/bin/`, installs the systemd unit, and enables + starts it.

### Adapting to a different device

Update `JBL_MAC` in `bin/jbl-sb271-autoeffects.sh` and the `PRESET_NAME` /
preset file to target a different device or tuning. Find a paired device's
MAC with:

```sh
bluetoothctl devices
```

PipeWire sink names replace `:` with `_` in the MAC, e.g. a device
`F8:1B:D8:6C:90:F2` shows up as `bluez_output.F8_1B_D8_6C_90_F2.1`.
