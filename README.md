<div align="center">

# island

**one shape, everything**

A Hyprland desktop shell built around a single morphing pill.
No bar, no panels, no tray — the island is the interface.

[![License](https://img.shields.io/badge/license-GPL--3.0-4c566a?style=for-the-badge)](LICENSE)
[![Quickshell](https://img.shields.io/badge/built%20with-Quickshell-5e81ac?style=for-the-badge)](https://quickshell.org)
[![Hyprland](https://img.shields.io/badge/compositor-Hyprland-81a1c1?style=for-the-badge)](https://hypr.land)
[![Wayland](https://img.shields.io/badge/wayland-native-8fbcbb?style=for-the-badge)](https://wayland.freedesktop.org)

</div>

---

## What is this?

Most Wayland setups are a bar, plus a launcher, plus a notification
daemon, plus a lock screen, plus a wallpaper tool — five programs that
don't know about each other and never quite match.

island is one surface that becomes whatever it needs to be. At rest
it's a small pill showing the time. Hover it and workspaces appear.
Click it and it grows into a control centre. Press `Super+R` and it
stretches into a launcher. A notification arrives and it becomes the
notification, then hands the shape back.

Everything is themed from your wallpaper: matugen derives a palette,
and the shell, GTK3, GTK4 and Hyprland's own window borders all read
from it.

<div align="center">

![control centre](docs/control-centre.png)

*The control centre — calendar, battery, quick toggles, sliders*

![settings](docs/settings.png)

*Settings, as two surfaces rather than one divided box*

</div>

---

## Features

- 🏝️ **One morphing surface** — eleven modes, one shape, no separate windows
- 🎨 **Wallpaper-driven theming** — matugen feeds the shell, GTK3, GTK4 and window borders
- 🔍 **Launcher inside the pill** — fuzzy application search with subsequence matching
- 🔔 **Notification daemon** — popup with actions, full history, Focus mode
- 🔐 **Session lock** — real `ext-session-lock` surface with PAM, not a shell-out
- 🛡️ **Polkit agent** — authorization prompts in the island, no GTK dialog
- 📋 **Clipboard history** — filterable, keyboard-driven, backed by cliphist
- 🎛️ **Live compositor control** — blur, gaps, borders and input applied without a reload
- ✋ **Continuous gestures** — four-finger swipes that track your fingers, not just fire on release
- 🖥️ **Two visibility modes** — reserve the strip, or let windows use the whole screen and move aside when they reach it
- 🎵 **Media** — MPRIS with artwork and transport
- 🔋 **Circular battery** — a gauge, not a battery outline
- ⚙️ **Settings app** — six pages, everything adjustable, no config file editing

---

## The island

| Mode | Trigger | Shows |
|:--|:--|:--|
| `idle` | — | time and date |
| `compact` | hover | adds workspaces and a playing indicator |
| `expanded` | click | calendar, battery, toggles, sliders, media |
| `search` | `Super+R` | application launcher |
| `clipboard` | `Super+V` | clipboard history |
| `picker` | `Super+Shift+W/T/I` | wallpapers, palettes, icon themes |
| `session` | `Super+Shift+Q` | lock, log out, suspend, reboot, shut down |
| `centre` | `Super+N` | notification history |
| `notify` | on arrival | a notification, briefly |
| `osd` | media keys | volume, brightness, mic |
| `auth` | on request | polkit authorization |

The pill's collapsed width is derived from its content plus a padding
constant, so nothing ever runs into the edges regardless of what's in
it.

---

## Install

```bash
git clone https://github.com/Sid-5137/island-dots ~/island-dots
cd ~/island-dots && ./install.sh
```

The script symlinks `hypr/` and `quickshell/island/` into `~/.config`,
creates the state directories, and reports missing dependencies.

**Requires**

```
hyprland quickshell matugen adw-gtk3-theme qt6ct
wl-clipboard cliphist brightnessctl playerctl hyprshot slurp
hypridle NetworkManager bluez
```

Fonts: JetBrainsMono Nerd Font.

Four-finger gestures need input device access:

```bash
sudo usermod -aG input "$USER"
```

**Two things that will bite you**

The shell is the notification daemon and the polkit agent. mako, dunst
and any external polkit agent must not be running alongside it.

The GTK theme must be `adw-gtk3`, **not** `adw-gtk3-dark`, with
`color-scheme: prefer-dark`. The colour scheme selects the dark
variant; naming the dark theme directly loads one that ignores the
matugen overrides.

```bash
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

---

## Configuration

Everything is in the settings app — `Super+S`.

`~/island-dots` is code and belongs in git.
`~/.config/island/settings.json` is this machine's state and doesn't.
It's written on first run from the defaults in `Services/Config.qml`,
and merged against them on every start — so an update that adds a
setting picks it up without the file being deleted.

`settings.example.json` shows every key and its shipped default. It is
generated from `Services/Config.qml` and is documentation only; the
shell never reads it.

One consequence of the merge worth knowing: it preserves values you
already have. If a release changes a *default*, your existing file
keeps the old value. Delete `settings.json` to take the new defaults.

```
bin/                  island-gestures, the libinput gesture daemon
hypr/                 Hyprland config, one module per concern
matugen/              Wallpaper → palette templates
quickshell/island/
  Services/           Singletons. No UI.
  Widgets/            Reusable controls. No state.
  Background/         Wallpaper layer
  Island/             The pill, its geometry and mode resolution
  Island/Modes/       One file per mode
  Lock/               Session lock surface
  Settings/           Settings window and its pages
```

---

## Theming

Wallpaper → matugen → four outputs:

| Output | Read by |
|:--|:--|
| `colors.json` | the shell, via `Services/Theme.qml` |
| `gtk-3.0/gtk.css` | GTK3, through adw-gtk3 |
| `gtk-4.0/gtk.css` | GTK4 / libadwaita, directly |
| `hyprctl eval` | window borders, via `Services/Compositor.qml` |

GTK3 and GTK4 need separate templates — GTK3 reads the `theme_*`
family, GTK4 reads only the `adw` names.

Firefox, Chrome and Electron apps do their own theming and won't
follow. That isn't a bug in the setup.

---

## Scope

island is a shell, not a desktop environment. It provides the layer
above your compositor and stays there.

**In scope:** the pill and its modes, notifications, launcher,
clipboard, lock, idle, OSD, theming, wallpapers, settings.

**Not in scope:** window management and tiling (Hyprland's job),
drive mounting (udisks), screen casting (the compositor), a file
manager, a terminal.

---

## Notes for anyone reading the source

Things that cost real time to work out:

- `hyprctl keyword` does not work with Hyprland's Lua config parser.
  Use `hyprctl eval` with an `hl.config({...})` block.
- A `PropertyChanges` that overrides a *bound* property replaces the
  binding rather than animating through it. The island uses plain
  bindings and no QML `States` for that reason.
- A `readonly` property nothing reads is evaluated lazily, so its
  change signal never fires.
- `clip: true` clips to the bounding rectangle, not the rounded shape.
  Anything opaque touching a rounded corner must round it itself.
- `anchors.centerIn` centres a text's line box, not its glyph. Icon
  fonts reserve descent space they never use.
- A `Grid` takes its width from its children — deriving a child size
  from the Grid's width is circular and collapses silently.
- Notifications are `Retainable`: they're destroyed on dismiss, so
  history stores copies rather than references.

---

## Roadmap

- [ ] **Multi-monitor.** `Variants` creates one island per screen, but
      Settings and the notification popup are pinned to
      `Quickshell.screens[0]`.
- [ ] **Inline reply** for chat notifications.
      `NotificationServer.inlineReplySupported` is off.
- [ ] **System tray.** `Quickshell.Services.SystemTray` exists; nothing
      reads it yet.
- [ ] **Calendar events.** The control centre calendar shows dates
      only.
- [ ] **Fingerprint at the lock screen.** Needs a dedicated
      `/etc/pam.d` file; `Config.island.pamConfig` selects it.
- [ ] **Per-monitor wallpapers.** One wallpaper is applied to every
      screen.
- [ ] **Continuous gestures upstream.** `bin/island-gestures` reads
      libinput directly because Hyprland's `gesture` action fires once
      on release. A progress callback for custom gestures would make
      the daemon unnecessary.

---

## Contributing

Early, and tested on one machine. If you try it and something breaks,
[open an issue](https://github.com/Sid-5137/island-dots/issues/new) —
that's more useful than a star.

---

<div align="center">

Built on [Quickshell](https://quickshell.org) (LGPL-3.0).
GTK/libadwaita theming follows the method documented by
[Noctalia](https://docs.noctalia.dev).

**GPL-3.0** · Copyright © 2026 Siddhartha Mallavolu

</div>
