#!/usr/bin/env bash
#
# jbl-sb271-autoeffects.sh
#
# Watches PipeWire for the JBL CINEMA SB271 Bluetooth sink appearing and,
# only when that specific device is the one connecting, loads a dedicated
# EasyEffects enhancement preset onto it (bass/presence EQ + a loudness
# limiter). Runs indefinitely as a systemd --user service; does nothing to
# any other audio output.
#
# Deliberately scoped to one device by MAC/sink-name match, unlike a naive
# "load this preset on login" autostart hook, which would apply to whatever
# happens to be the default sink at the time (e.g. built-in speakers).

set -euo pipefail

JBL_MAC="F8_1B_D8_6C_90_F2"
JBL_SINK_PATTERN="bluez_output.${JBL_MAC}"
PRESET_NAME="jbl_sb271_enhance"
LOG_TAG="jbl-sb271-autoeffects"

log() {
    logger -t "$LOG_TAG" -- "$*" 2>/dev/null || echo "[$LOG_TAG] $*" >&2
}

apply_preset() {
    if ! pgrep -x easyeffects >/dev/null 2>&1; then
        log "starting easyeffects service"
        easyeffects --service-mode --hide-window >/dev/null 2>&1 &
        disown
        for _ in $(seq 1 20); do
            pgrep -x easyeffects >/dev/null 2>&1 && break
            sleep 0.5
        done
    fi

    # give the service a moment to finish registering with PipeWire
    sleep 1

    if easyeffects -l "$PRESET_NAME" >/dev/null 2>&1; then
        log "applied preset '$PRESET_NAME' for JBL CINEMA SB271"
    else
        log "failed to load preset '$PRESET_NAME'"
    fi
}

jbl_sink_present() {
    pactl list sinks short 2>/dev/null | grep -q "$JBL_SINK_PATTERN"
}

# Handle the case where the speaker is already connected when this starts
# (e.g. service (re)start while the JBL is already paired and playing).
if jbl_sink_present; then
    apply_preset
fi

# Then watch PipeWire events for it connecting from here on.
pactl subscribe 2>/dev/null | while read -r line; do
    if [[ "$line" == *"Event 'new' on sink"* ]] && jbl_sink_present; then
        apply_preset
    fi
done
