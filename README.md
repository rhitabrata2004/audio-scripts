# audio-scripts

Small, targeted PipeWire/EasyEffects automation scripts for specific audio
devices — as opposed to blanket "run this on every login" hacks that end up
affecting whatever output happens to be active at the time.

## Wired headphone speaker leakage fix

`bin/builtin-audio-boost.sh` keeps this machine's built-in output at 125%
while preserving the ALSA Speaker mute switch. Previously, the boost script
repeatedly unmuted speakers, fighting `bin/jbl-headphone-automute.sh` and
causing audio to play through the laptop speakers with headphones selected.
The headphone script enforces mutually exclusive speaker/headphone output
at startup and on routing changes. Both user services start at login and
restart automatically, reapplying the fix after reboot or forced shutdown.

These scripts target the built-in sink `alsa_output.pci-0000_00_1f.3.analog-stereo`
and ALSA card 0 on this machine. They require PipeWire's PulseAudio
compatibility service, WirePlumber, ALSA utilities, and systemd.

### Install the wired headphone fix

This is separate from the soundbar installer below. Run from the repository root:

```sh
mkdir -p ~/.local/bin ~/.config/systemd/user ~/.config/wireplumber/wireplumber.conf.d
install -m 755 bin/builtin-audio-boost.sh bin/jbl-headphone-automute.sh ~/.local/bin/
install -m 644 systemd/builtin-audio-boost.service systemd/jbl-headphone-automute.service ~/.config/systemd/user/
install -m 644 wireplumber/51-alsa-auto-port.conf ~/.config/wireplumber/wireplumber.conf.d/
systemctl --user daemon-reload
systemctl --user restart wireplumber.service
systemctl --user enable --now builtin-audio-boost.service jbl-headphone-automute.service
systemctl --user restart builtin-audio-boost.service jbl-headphone-automute.service
```

With wired headphones selected, `amixer -c 0 sget Speaker` should show
`[off]`, and `amixer -c 0 sget Headphone` should show `[on]`. Both services
should be enabled and active. Shell syntax, service validation, and service
restart checks passed; full reboot and audible playback checks remain to
be confirmed.

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
