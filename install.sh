#!/usr/bin/env bash
# Installs the JBL SB271 auto-effects trigger for the current user:
#   - copies the EasyEffects preset into ~/.local/share/easyeffects/output/
#   - copies the trigger script into ~/.local/bin/
#   - installs + enables the systemd --user service
#
# Safe to re-run; overwrites previous copies of the same files.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PRESET_DIR="$HOME/.local/share/easyeffects/output"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

mkdir -p "$PRESET_DIR" "$BIN_DIR" "$UNIT_DIR"

install -m 644 presets/jbl_sb271_enhance.json "$PRESET_DIR/jbl_sb271_enhance.json"
install -m 755 bin/jbl-sb271-autoeffects.sh "$BIN_DIR/jbl-sb271-autoeffects.sh"
install -m 644 systemd/jbl-sb271-autoeffects.service "$UNIT_DIR/jbl-sb271-autoeffects.service"

systemctl --user daemon-reload
systemctl --user enable --now jbl-sb271-autoeffects.service

echo "Installed. Status:"
systemctl --user status --no-pager jbl-sb271-autoeffects.service || true
