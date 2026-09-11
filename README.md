<div align="center">

# island

**one shape, everything**

A Hyprland desktop shell built around a single morphing pill.
No bar. No panels. No tray. The island *is* the interface.

[![License](https://img.shields.io/badge/license-GPL--3.0-4c566a?style=for-the-badge)](LICENSE)
[![Quickshell](https://img.shields.io/badge/built%20with-Quickshell-5e81ac?style=for-the-badge)](https://quickshell.org)
[![Hyprland](https://img.shields.io/badge/compositor-Hyprland-81a1c1?style=for-the-badge)](https://hypr.land)
[![Wayland](https://img.shields.io/badge/wayland-native-8fbcbb?style=for-the-badge)](https://wayland.freedesktop.org)

<br>

https://github.com/Sid-5137/island-dots/assets/PLACEHOLDER/demo.mp4

*One surface. Clock, launcher, control centre, notifications, power —
it becomes each of them and hands the shape back.*

</div>

---

## Features

<table>
<tr>
<td width="50%" valign="top">

**One surface, eleven modes**
Clock, hover, control centre, launcher, clipboard, wallpaper picker,
power menu, notifications, notification history, volume OSD and
authorization prompts — all the same shape, morphing between them.

**Wallpaper-driven theming**
matugen derives a palette from your wallpaper and feeds the shell,
GTK3, GTK4 *and* Hyprland's own window borders. Change the wallpaper,
the desktop follows.

**A launcher in the pill**
Fuzzy application search with subsequence matching — `fx` finds
Firefox, `ed` finds Text Editor. Keyboard-first, results scored not
filtered.

**Notification daemon**
Not a client of one. The shell claims
`org.freedesktop.Notifications`: popups with action buttons, full
history, Focus mode that records without interrupting, and critical
notifications that ignore it.

**Session lock**
A real `ext-session-lock` surface with PAM authentication — not a
shell-out to hyprlock. Clock, wallpaper, battery, and a password field
that knows when to mask itself.

**Polkit agent**
Authorization prompts appear in the island rather than a mismatched
GTK dialog. polkitd still makes every decision; only the asking moved.

</td>
<td width="50%" valign="top">

**Continuous gestures**
Four-finger swipes that track your fingers rather than firing once on
release. Reads libinput directly and drives PipeWire over a persistent
socket — no process spawned per step.

**Live compositor control**
Blur, gaps, borders, rounding, pointer acceleration and key repeat,
applied to Hyprland as you move the slider. No reload, no config edit.

**Window switcher and overview**
Alt+Tab across every workspace with app icons; `Super+W` for a
workspace overview with live window thumbnails, captured through the
compositor.

**Smart visibility**
Reserve the strip so windows start below it, or let windows use the
whole screen and have the island move aside only when one actually
reaches it.

**Clipboard history**
Filterable, keyboard-driven, backed by cliphist. `Ctrl+D` deletes an
entry without leaving the field.

**System tray**
A face on the collapsed pill — scroll to it. Left-click activates,
right-click opens the application's own menu, and items asking for
attention show a dot.

**Calendar with events**
Dates carry a dot when something is scheduled, and today's events list
under the month. Reads khal; absent entirely without it.

**Settings that reset**
Six pages, every value adjustable. Anything you have changed grows a
revert control beside it; sections and the whole config can be reset
too.

</td>
</tr>
</table>

<div align="center">

![control centre](docs/control-centre.png)

**The control centre** — one blurred container, modules inside it:
calendar, battery ring, quick toggles, sliders, media, system tray

![settings](docs/settings.png)

**Settings** — six pages, live preview, per-control revert

</div>

---

## Why

Most Wayland setups are a bar, plus a launcher, plus a notification
daemon, plus a lock screen, plus a wallpaper tool. Five programs that
don't know about each other, don't match each other, and each need
configuring separately.

island is one surface that becomes whatever it needs to be. At rest
it's a small pill showing the time. Hover it and workspaces appear.
Click it and it grows into a control centre. Press `Super+R` and it
stretches into a launcher. A notification arrives and it *becomes* the
notification, then hands the shape back.

Because it's one program, the palette is shared, the animation is
shared, and there is one settings app rather than five config files.

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

Scrolling the collapsed pill cycles its face: clock, media, system
tray.
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

- **Hyprland's Lua migration breaks things silently.** Three separate
  APIs stopped working with no error and no log line:
  - `hyprctl keyword` — rejected outright with "keyword can't work
    with non-legacy parsers". Use `hyprctl eval` with an
    `hl.config({...})` block.
  - `hyprctl dispatch workspace 2` — wrapped as
    `hl.dispatch(workspace 2)`, which is not valid Lua. Dispatchers
    take Lua now: `hl.dsp.focus({ workspace = 2 })`.
  - Argument names changed with it. Focusing a window is
    `hl.dsp.focus({ window = "address:0x..." })`; a top-level
    `address =` is accepted and silently ignored, which is worse than
    an error.

  After a Hyprland update, test each of these by hand before assuming
  the shell is at fault:

  ```bash
  hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'
  hyprctl eval 'hl.config({ decoration = { rounding = 12 } })'
  qs -c island ipc call wm windows      # then focus one by address
  ```

- Do not make the pill's own properties conditional per mode. Colour,
  border width and `clip` switching mid-morph were the cause of every
  flicker in the control centre. Content inside a mode can vary
  freely; the surface it sits on should not.
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

- [ ] **Alt+Tab does not reliably change focus.** The pieces all work
      in isolation: `wm windows` lists every window with its address,
      and `wm focus <address>` moves focus correctly both within a
      workspace and across workspaces. The switcher opens, selects,
      and calls the same function — but focus often does not move.
      Suspects not yet ruled out: the commit timer firing between two
      Tab presses, `repeating: true` on the bind not keeping the
      switcher open, or `Qt.callLater` dispatching after the surface
      is down but before the compositor is ready to accept it.

- [ ] **Multi-monitor.** `Variants` creates one island per screen, but
      Settings and the notification popup are pinned to
      `Quickshell.screens[0]`.
- [ ] **Inline reply** for chat notifications.
      `NotificationServer.inlineReplySupported` is off.

- [ ] **Calendar events need khal.** There is no desktop-wide calendar
      to read on Linux, so `Services/Calendar.qml` shells out to khal
      and shows nothing without it. Reading `.ics` files directly, or
      through a portal, would drop the dependency.
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

`docs/RECORDING.md` covers how the demo was captured, if you want to
show a variation.

---

<div align="center">

Built on [Quickshell](https://quickshell.org) (LGPL-3.0).
GTK/libadwaita theming follows the method documented by
[Noctalia](https://docs.noctalia.dev).

**GPL-3.0** · Copyright © 2026 Siddhartha Mallavolu

</div>
