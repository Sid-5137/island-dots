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

# Set if the icon font is still unusable when we finish. Read by the
# summary at the bottom, which is the only place that should decide
# whether an install "worked".
missing_font=0

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

# The lock screen authenticates against a PAM file named by
# Config.island.pamConfig. The shipped default is "login", which exists
# everywhere and works. A dedicated /etc/pam.d/island additionally lets
# a fingerprint reader work at the lock screen without enabling it for
# tty logins, where a failed read looks like a hung terminal.
#
# This needs root, so it asks rather than doing it. Declining leaves a
# perfectly good password-only lock.
if [ -f "$DOTS/pam/island.in" ] && [ ! -e /etc/pam.d/island ]; then
    stack=""
    for candidate in password-auth system-auth common-auth; do
        if [ -f "/etc/pam.d/$candidate" ]; then
            stack="$candidate"
            break
        fi
    done

    if [ -z "$stack" ]; then
        echo
        echo "  Skipping /etc/pam.d/island: no system auth stack found"
        echo "  (looked for password-auth, system-auth, common-auth)."
    else
        echo
        echo "Fingerprint unlock (optional)"
        echo "  Installing /etc/pam.d/island lets the lock screen use a"
        echo "  fingerprint reader, falling back to your password. It"
        echo "  needs root, and the lock screen works without it."
        printf '  Install it now? [y/N] '
        # Braces so a missing controlling terminal is silent — see the
        # icon-font prompt below, which does the same. Unanswered stays
        # "no" here, which it already was.
        if ! { read -r answer </dev/tty; } 2>/dev/null; then
            answer=""
            echo
        fi

        case "$answer" in
            [yY]*)
                tmp="$(mktemp)"
                sed "s|@STACK@|$stack|g" "$DOTS/pam/island.in" > "$tmp"
                if sudo install -m 0644 "$tmp" /etc/pam.d/island; then
                    echo "  /etc/pam.d/island written (stack: $stack)"
                    echo "  Set Lock > PAM configuration to 'island' in settings,"
                    echo "  then enrol a finger with: fprintd-enroll"
                else
                    echo "  Could not write /etc/pam.d/island; leaving it alone."
                fi
                rm -f "$tmp"
                ;;
            *)
                echo "  Skipped. Run install.sh again to be asked once more."
                ;;
        esac
    fi
fi

# ── The icon font ────────────────────────────────────────────────
#
# Every glyph the shell draws comes out of one patched font, named in
# Services/Theme.qml and enumerated in Services/Icons.qml. Without it
# the shell still runs and every icon in it is a box.
#
# The version matters, which is the part worth automating. Nerd Fonts
# v3 moved the whole Material Design range from U+F500..U+FD46 up to
# U+F0000 and beyond, and the shell's glyphs are the new ones — the
# four Wi-Fi bars, the settings tabs, the padlock on a secured network.
# A v2 patch has the family name, satisfies a `fc-list` check for it,
# and draws nothing where those go. That failure is silent and it looks
# like a shell bug rather than a font one, so the check below is for a
# glyph rather than for a name.

NERD_FAMILY="JetBrainsMono Nerd Font"

# md-wifi_strength_4. Any U+F0000-range glyph would do; this one is
# picked because it is in the shell's own register and so cannot
# quietly stop being used.
NERD_PROBE="f0928"

font_has_glyph() {
    fc-list ":charset=$1" family 2>/dev/null | grep -qi "jetbrainsmono nerd"
}

install_nerd_font() {
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"
    local tmp fetch

    if command -v curl >/dev/null 2>&1; then
        fetch=(curl -fsSL -o)
    elif command -v wget >/dev/null 2>&1; then
        fetch=(wget -qO)
    else
        echo "  Need curl or wget to fetch it. Install one, or grab"
        echo "  JetBrainsMono from https://nerdfonts.com and unzip it"
        echo "  into $dest"
        return 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "  Need unzip to unpack it."
        return 1
    fi

    tmp="$(mktemp -d)"
    echo "  Downloading JetBrainsMono Nerd Font..."
    if ! "${fetch[@]}" "$tmp/JetBrainsMono.zip" "$url"; then
        echo "  Download failed. Leaving fonts alone."
        rm -rf "$tmp"
        return 1
    fi

    # Into a directory of its own, so uninstalling is one rm and so a
    # second run replaces rather than accumulates.
    mkdir -p "$dest"
    if ! unzip -qo "$tmp/JetBrainsMono.zip" -d "$dest"; then
        echo "  Could not unpack the archive. Leaving fonts alone."
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"

    fc-cache -f "$dest" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
    echo "  $dest"
    return 0
}

echo
echo "Icon font:"

if font_has_glyph "$NERD_PROBE"; then
    echo "  ok   $NERD_FAMILY (v3)"
else
    # `fc-list : family`, not `fc-list family` — the first argument is
    # a pattern, so the bare form asks for fonts whose family is
    # literally "family" and prints nothing. The colon is the
    # match-everything pattern, and without it this branch can never be
    # taken: a v2 patch would be reported as no font at all.
    if fc-list : family 2>/dev/null | grep -qi "jetbrainsmono nerd"; then
        echo "  $NERD_FAMILY is installed, but it is a Nerd Fonts v2"
        echo "  patch: it has no U+F0928, so the Wi-Fi bars, the settings"
        echo "  tab icons and the secured-network padlock will be blank."
        prompt="  Install the v3 build alongside it? [Y/n] "
    else
        echo "  $NERD_FAMILY is not installed. Without it every icon in"
        echo "  the shell — and all of its text — falls back to whatever"
        echo "  fontconfig picks."
        prompt="  Install it now (~30MB, no root needed)? [Y/n] "
    fi

    # Default yes on a bare Enter, because at a real prompt that is
    # what the person meant. But a read that FAILS is not a yes — it
    # is nobody there to ask, and treating it as consent means a run
    # with no controlling terminal fetches 30MB on its own. Asked for
    # and answered are different things.
    printf '%s' "$prompt"
    # Braces so the redirection failure is swallowed too: when there is
    # no controlling terminal it is the shell, not `read`, that
    # complains, and 2>/dev/null on the read alone does not catch it.
    if { read -r answer </dev/tty; } 2>/dev/null; then
        answer="${answer:-y}"
    else
        answer="n"
        echo
        echo "  (no terminal to ask on)"
    fi

    case "$answer" in
        [nN]*)
            echo "  Skipped."
            missing_font=1
            ;;
        *)
            if install_nerd_font && font_has_glyph "$NERD_PROBE"; then
                echo "  ok   $NERD_FAMILY (v3)"
            else
                echo "  Still not resolving. Check with:"
                echo "    fc-list ':charset=$NERD_PROBE' family"
                missing_font=1
            fi
            ;;
    esac
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

# App icons — the launcher's rows, the tray, the icon on a
# notification. Quickshell resolves these through the XDG icon theme
# named in Config.appearance.iconTheme, which ships as Adwaita; with no
# theme installed every one of them resolves to nothing and the
# launcher becomes a list of names with holes down the left.
#
# hicolor is the fallback every spec-compliant theme inherits from, so
# it is worth naming separately: without it even an installed theme
# resolves badly.
icon_dirs=("/usr/share/icons" "${XDG_DATA_HOME:-$HOME/.local/share}/icons")
has_icon_theme() {
    local name="$1" dir
    for dir in "${icon_dirs[@]}"; do
        [ -d "$dir/$name" ] && return 0
    done
    return 1
}

if has_icon_theme Adwaita; then
    printf '  ok   %s\n' "Adwaita icon theme"
else
    printf '  MISS %s\n' "Adwaita icon theme"
    missing+=("adwaita-icon-theme")
fi

if has_icon_theme hicolor; then
    printf '  ok   %s\n' "hicolor icon theme"
else
    printf '  MISS %s\n' "hicolor icon theme"
    missing+=("hicolor-icon-theme")
fi

# Cursors. Config.appearance.cursorTheme ships as Bibata-Modern-Ice and
# the shell pushes it to GTK, Qt and Hyprland together, so a missing one
# is three inconsistent cursors rather than one missing cursor. Not
# fatal, and not added to `missing` for that reason — the pointer still
# works, it is just the wrong pointer.
if has_icon_theme Bibata-Modern-Ice; then
    printf '  ok   %s\n' "Bibata-Modern-Ice cursors"
else
    printf '  note %s\n' "Bibata-Modern-Ice cursors absent — pick another in Settings > Theme"
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
    echo "      mate-polkit xdg-desktop-portal-gtk xdg-desktop-portal-hyprland \\"
    echo "      adwaita-icon-theme hicolor-icon-theme"
elif [ "$missing_font" -eq 0 ]; then
    echo "All dependencies present."
fi

if [ "$missing_font" -ne 0 ]; then
    echo
    echo "The icon font is still missing or too old. The shell will run,"
    echo "but its icons will not. Fedora ships a v3 patch as:"
    echo "  sudo dnf install jetbrains-mono-nerd-fonts"
    echo "or unzip JetBrainsMono.zip from https://nerdfonts.com into"
    echo "  ~/.local/share/fonts/  &&  fc-cache -f"
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
