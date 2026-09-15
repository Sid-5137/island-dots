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
#
# Nothing here assumes the repo is at ~/island-dots. It used to, in
# four separate files, and a clone anywhere else came up with no
# palette, no GTK colours and no gestures — with nothing saying why.
# The paths that genuinely need to be absolute are generated below.
set -euo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN="$HOME/.local/bin"

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

# Executables go on PATH so neither hypr/autostart.lua nor the shell
# has to know where this repo lives.
for exe in "$DOTS"/bin/*; do
    [ -x "$exe" ] || continue
    link "$exe" "$BIN/$(basename "$exe")"
done

# settings.json lives in the first of these, generated colours in the
# second. Without the directories every write fails silently: nothing
# persists, and the shell comes up on declared defaults every time.
mkdir -p "$CONFIG/island" "$STATE/island" "$HOME/Pictures/Screenshots"

echo
echo "Generating:"

# matugen's TOML cannot expand a variable, so every path in it has to
# be absolute — which is exactly why it could not be committed with
# the rest of the config. The template is the tracked file; this is
# the machine-specific output.
sed -e "s|@DOTS@|$DOTS|g" \
    -e "s|@CONFIG@|$CONFIG|g" \
    -e "s|@STATE@|$STATE|g" \
    "$DOTS/matugen/config.toml.in" > "$CONFIG/island/matugen.toml"
echo "  $CONFIG/island/matugen.toml"

# Older installs kept the generated palette inside the checkout. Move
# it rather than making the user sit on stale colours until the next
# wallpaper change.
if [ -f "$DOTS/quickshell/island/colors.json" ] \
   && [ ! -f "$STATE/island/colors.json" ]; then
    mv "$DOTS/quickshell/island/colors.json" "$STATE/island/colors.json"
    echo "  moved colors.json out of the checkout -> $STATE/island/"
fi

# Puts gtk.css under our control and repairs the adw-gtk3 symlink that
# otherwise makes every matugen run fail. Safe to run repeatedly.
#
# Called bare it keeps whatever theme is already configured. The one
# exception is a machine that has never had one set: gsettings answers
# with the schema default, and leaving that in place means everything
# looks unstyled until the shell first starts and applies its own
# default. Seed it here instead.
if [ -x "$DOTS/bin/island-gtk-apply" ]; then
    seed=()
    current=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null \
                | tr -d "'" || true)
    if [ "${current:-Adwaita}" = "Adwaita" ] && [ -d /usr/share/themes/adw-gtk3 ]; then
        seed=(--gtk adw-gtk3)
    fi
    "$DOTS/bin/island-gtk-apply" --no-nudge "${seed[@]}" || true
    echo "  ~/.config/gtk-{3,4}.0/gtk.css"
fi

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

# Not commands, but the shell is visibly wrong without them.
if [ ! -d /usr/share/themes/adw-gtk3 ]; then
    printf '  MISS %s\n' "adw-gtk3 theme"
    missing+=("adw-gtk3-theme")
fi
if ! ls /usr/libexec/xdg-desktop-portal* >/dev/null 2>&1; then
    printf '  MISS %s\n' "xdg-desktop-portal"
    missing+=("xdg-desktop-portal-gtk")
fi

echo
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}"
    echo "On Fedora, most of these are:"
    echo "  sudo dnf install hyprland quickshell matugen kitty nautilus \\"
    echo "      wireplumber brightnessctl playerctl NetworkManager bluez \\"
    echo "      cliphist wl-clipboard hyprshot slurp adw-gtk3-theme qt6ct hypridle \\"
    echo "      mate-polkit xdg-desktop-portal-gtk xdg-desktop-portal-hyprland"
else
    echo "All dependencies present."
fi

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo
       echo "NOTE: $BIN is not on your PATH. Gestures and GTK theming"
       echo "      are started by name, so add it to your shell profile." ;;
esac

cat <<'NOTE'

One thing this script deliberately does not do:

  · It doesn't write ~/.config/island/settings.json. That file is
    machine state and is created on first run from the defaults in
    Services/Config.qml. New keys merge in automatically on start;
    delete the file only if you want to take new defaults for keys
    you already have. settings.example.json shows every key.

It DOES now set your GTK theme, which it used to leave to you. The
shell owns ~/.config/gtk-{3,4}.0/gtk.css and imports the generated
colours from matugen.css next to it; put your own CSS in user.css in
the same directory and it will be imported after both.

Continuous four-finger gestures need read access to the input devices:

    sudo usermod -aG input "$USER"

That takes effect at your next login. Without it island-gestures
exits quietly and the gestures simply do nothing.

Log out and pick Hyprland at your display manager.
NOTE
