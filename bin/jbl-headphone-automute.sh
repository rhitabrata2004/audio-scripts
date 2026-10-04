#!/usr/bin/env bash
# Keeps the internal speakers and headphone-out mutually exclusive.
#
# Why this exists: on this machine (Realtek ALC897 / HDA Intel PCH),
# WirePlumber correctly detects the headphone jack and updates the
# reported "Active Port" on the sink, but the ALSA-card-profile (ACP)
# mixer-path directive that's supposed to mute the Speaker control
# when the Headphones path activates ([Element Speaker] switch=off in
# analog-output-headphones.conf) silently fails to apply in that
# direction (the reverse direction, muting Headphone when Speaker
# activates, works fine). Net effect without this script: both outputs
# play at once when headphones are plugged in.
#
# This script watches for port-change events via `pactl subscribe` and
# directly enforces the correct mute state with amixer, independent of
# the buggy ACP directive.
set -euo pipefail

SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"

apply_mute() {
  local port
  port=$(pactl list sinks 2>/dev/null | awk -v name="$SINK" '
    /^Sink #/{active=0}
    $0 ~ ("Name: " name) {active=1}
    active && /Active Port:/{print $3; exit}
  ')

  case "$port" in
    analog-output-headphones)
      amixer -q -c 0 sset 'Speaker' mute
      amixer -q -c 0 sset 'Headphone' unmute
      ;;
    analog-output-speaker)
      amixer -q -c 0 sset 'Headphone' mute
      amixer -q -c 0 sset 'Speaker' unmute
      ;;
  esac
}

# Sync once at startup in case state is already wrong.
apply_mute

pactl subscribe 2>/dev/null | while read -r line; do
  case "$line" in
    *"on card"*|*"on sink"*)
      # ACP's own (buggy, asymmetric) path-switch handling is still
      # running asynchronously right after this event fires and can
      # briefly re-enable the Speaker switch after we mute it. Give it
      # a moment to settle before asserting the correct final state.
      ( sleep 0.6; apply_mute ) &
      ;;
  esac
done
