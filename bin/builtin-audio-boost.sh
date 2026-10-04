#!/usr/bin/env bash
# Pins the built-in speakers' output sink at 125% volume (5.8dB software
# gain stacked on top of ALSA's own 100% hardware ceiling), and keeps it
# there across reboots, PipeWire/WirePlumber crashes, and any external
# reset (alsa-restore.service, an app calling pactl, etc).
#
# Re-asserts state once immediately on every start (covers boot and
# crash-restart alike), then reacts live to `pactl subscribe` sink-change
# events instead of polling. If the subscribe pipe dies (PipeWire crashed),
# the script exits and systemd (Restart=always) relaunches it, which
# re-enforces state before resubscribing.
#
# Scoped to the built-in ALSA sink specifically -- independent of which
# sink is currently the PipeWire default (e.g. JBL Cinema SB271 over BT).

set -uo pipefail

SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"
TARGET_PCT=125
LOG_TAG="builtin-audio-boost"

log() {
    logger -t "$LOG_TAG" -- "$*" 2>/dev/null || echo "[$LOG_TAG] $*" >&2
}

alsa_card() {
    pactl list sinks 2>/dev/null | awk -v s="$SINK" '
        $0 ~ "Name: " s { f=1; next }
        f && /^\tName: / { f=0 }
        f && /alsa\.card = / { gsub(/[^0-9]/, "", $NF); print $NF; exit }
    '
}

# True only if $ctrl is already at 100% and (when it has a mute switch at
# all) unmuted. Lets enforce() skip the amixer write entirely when nothing's
# wrong -- important because this runs on every "on sink" event for *any*
# sink, and an unconditional write here could itself emit a change event
# that re-triggers this same loop.
alsa_ctrl_at_target() {
    local card="$1" ctrl="$2" out line
    out="$(amixer -c "$card" sget "$ctrl" 2>/dev/null)" || return 1
    [[ -z "$out" ]] && return 1

    # amixer prints an empty "Mono:" placeholder line before "Front Left:"
    # for stereo-channel controls, so "Mono:" must require actual data
    # ("Mono: Playback ...") or it wins the match over the real line first.
    line="$(grep -m1 -E 'Front Left:|Mono: Playback' <<< "$out")"
    [[ "$line" == *"[100%]"* ]] || return 1

    # PCM has no pswitch capability -- there's no mute state to check there.
    if [[ "$ctrl" != Speaker ]] && grep -q 'pswitch' <<< "$out"; then
        [[ "$line" == *"[on]"* ]] || return 1
    fi

    return 0
}

enforce() {
    # Keep hardware gain at 0dB. Preserve Speaker mute: headphone routing
    # owns that switch, and unmuting it here causes sound to leak.
    local card
    card="$(alsa_card)"
    if [[ -n "$card" ]]; then
        for ctrl in Master Speaker PCM; do
            alsa_ctrl_at_target "$card" "$ctrl" && continue
            if [[ "$ctrl" == Speaker ]]; then
                amixer -c "$card" sset "$ctrl" 100% >/dev/null 2>&1
            else
                amixer -c "$card" sset "$ctrl" 100% unmute >/dev/null 2>&1
            fi
            log "reset ALSA $ctrl on card $card to 100%"
        done
    fi

    # Skip the PipeWire-side steps if the sink isn't present right now
    # (e.g. device enumerating during boot).
    pactl list sinks short 2>/dev/null | grep -q "$SINK" || return 0

    local vol mute
    vol="$(pactl get-sink-volume "$SINK" 2>/dev/null | grep -oP '\d+(?=%)' | head -1)"
    mute="$(pactl get-sink-mute "$SINK" 2>/dev/null | awk '{print $2}')"

    if [[ "$vol" != "$TARGET_PCT" ]]; then
        pactl set-sink-volume "$SINK" "${TARGET_PCT}%"
        log "reset $SINK volume ${vol:-unknown}% -> ${TARGET_PCT}%"
    fi
    if [[ "$mute" == "yes" ]]; then
        pactl set-sink-mute "$SINK" 0
        log "unmuted $SINK"
    fi
}

enforce

pactl subscribe 2>/dev/null | while read -r line; do
    [[ "$line" == *"on sink"* ]] && enforce
done
