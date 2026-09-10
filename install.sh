#!/usr/bin/env bash
# island-dots — a Hyprland shell built around a morphing pill.
# Copyright (C) 2026 Siddhartha Mallavolu
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version. See LICENSE.
# Links this repo into place and reports what's missing.
#
# Symlinks rather than copies: editing the config in ~/.config edits
# the repo, so there's no "which copy is real" question.
set -euo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        echo "  backing up existing $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  $dst -> $src"
}

echo "Linking:"
link "$DOTS/hypr" "$CONFIG/hypr"
link "$DOTS/quickshell/island" "$CONFIG/quickshell/island"

# hypridle reads an explicit path from autostart.lua, so it just needs
# to exist next to the rest of the hypr config.

mkdir -p "$HOME/.local/state/island" "$HOME/Pictures/Screenshots"

echo
echo "Checking dependencies:"
missing=()
for cmd in \
    hyprland quickshell matugen kitty nautilus firefox \
    wpctl brightnessctl playerctl nmcli bluetoothctl \
    cliphist wl-paste hyprshot slurp gsettings hypridle libinput
do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok   %s\n' "$cmd"
    else
        printf '  MISS %s\n' "$cmd"
        missing+=("$cmd")
    fi
done

echo
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}"
    echo "On Fedora, most of these are:"
    echo "  sudo dnf install hyprland quickshell matugen kitty nautilus \\"
    echo "      wireplumber brightnessctl playerctl NetworkManager bluez \\"
    echo "      cliphist wl-clipboard hyprshot slurp adw-gtk3-theme qt6ct hypridle \\"
    echo "      mate-polkit"
else
    echo "All dependencies present."
fi

cat <<'NOTE'

Two things this script deliberately does not do:

  · It doesn't write ~/.config/island/settings.json. That file is
    machine state and is created on first run from the defaults in
    Services/Config.qml. Deleting it is also how you pick up new
    config keys after an update — JsonAdapter does not merge them
    into an existing file.

  · It doesn't set your GTK theme. The matugen colour overrides need
    the theme to be adw-gtk3 (not adw-gtk3-dark) with
    color-scheme prefer-dark:

      gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

Continuous four-finger gestures need read access to the input devices:

    sudo usermod -aG input "$USER"

That takes effect at your next login. Without it bin/island-gestures
exits quietly and the gestures simply do nothing.

Log out and pick Hyprland at your display manager.
NOTE
