# island-dots

A Hyprland setup built around a single morphing pill — an island —
that serves as clock, launcher, control centre, picker and power menu.
Written in Quickshell/QML.

Everything is themed from the wallpaper: matugen derives a palette,
and the shell, GTK3, GTK4 and Hyprland's own window borders all read
from it.

![control centre](docs/control-centre.png)

The control centre — calendar and battery on the left, quick toggles
and sliders on the right. This is the pill expanded; at rest it's a
small bar showing the time.

![settings](docs/settings.png)

Settings, as two surfaces rather than one divided box.

## The island

One shape, several modes. Nothing else is on screen.

| Mode | Trigger | Shows |
|---|---|---|
| idle | — | time and date |
| compact | hover | adds workspaces and a playing indicator |
| expanded | click | calendar, battery, quick toggles, sliders, media |
| search | `Super+R` | application launcher, inside the pill |
| picker | `Super+Shift+W/T/I` | wallpapers, palettes, icon themes |
| session | `Super+Shift+Q` | lock, log out, suspend, reboot, shut down |
| hidden | auto visibility | slides away when windows are present |

The pill's collapsed width is derived from its content plus a padding
constant, so nothing ever runs into the edges regardless of what's in
it.

## Layout

    hypr/                 Hyprland config, one module per concern
    matugen/              Wallpaper → palette templates
    quickshell/island/
      Services/           Singletons. No UI.
      Widgets/            Reusable controls. No state.
      Background/         Wallpaper layer
      Island/             The pill and every mode
      Settings/           Settings window and its pages

`Services/Config.qml` is the spine: every preference lives there,
backed by `settings.json`. Components bind to it, the settings app
writes to it, and neither has to know about the other.

## Install

    git clone <this repo> ~/island-dots
    cd ~/island-dots && ./install.sh

The script symlinks `hypr/` and `quickshell/island/` into `~/.config`,
creates the state directories, and reports missing dependencies.

Fonts: JetBrainsMono Nerd Font.

## Configuration

`~/island-dots` is code and belongs in git.
`~/.config/island/settings.json` is this machine's state and doesn't —
it's written on first run from the defaults in `Services/Config.qml`.

Deleting `settings.json` regenerates it. That's also the fix after an
update adds a config key: `JsonAdapter` does not merge new keys into
an existing file, so older files leave new properties undefined.

Almost everything is adjustable from the settings app (`Super+S`):
island geometry and motion, appearance, input, network, wallpaper.

## Theming

Wallpaper → matugen → four outputs:

    colors.json          the shell, via Services/Theme.qml
    gtk-3.0/gtk.css      classic GTK3 colour names
    gtk-4.0/gtk.css      libadwaita colour names
    hyprctl eval         window borders, via Services/Compositor.qml

GTK3 and GTK4 need separate templates — GTK3 reads the `theme_*`
family, GTK4/libadwaita reads only the `adw` names.

The GTK theme must be `adw-gtk3`, **not** `adw-gtk3-dark`, with
`color-scheme: prefer-dark`. The colour scheme selects the dark
variant; naming the dark theme directly loads one that ignores the
overrides.

Firefox, Chrome and Electron apps do their own theming and won't
follow. That's not a bug in the setup.

## Notes for anyone reading the source

Things that cost time to work out:

- `hyprctl keyword` does not work with Hyprland's Lua config parser.
  Use `hyprctl eval` with an `hl.config({...})` block.
- A `PropertyChanges` that overrides a *bound* property replaces the
  binding rather than animating through it. The island uses plain
  bindings and no QML `States` for that reason.
- `clip: true` clips to the bounding rectangle, not the rounded
  shape. Anything opaque touching a rounded corner has to round that
  corner itself.
- `anchors.centerIn` centres a text's line box, not its glyph. Icon
  fonts reserve descent space they never use, so icons sit high
  without a metrics-derived correction.
- A `Grid` takes its width from its children. Deriving a child size
  from the Grid's width is circular and collapses silently.

## Status

Working: wallpaper with crossfade, the island and all its modes,
MPRIS, settings app, network and Bluetooth management, live
compositor control, cross-toolkit theming.

Not built yet: notifications, clipboard panel. Their keybinds are
commented out in `hypr/binds.lua`.

## Credits

Built on [Quickshell](https://quickshell.org) (LGPL-3.0).
The GTK/libadwaita theming approach follows the method documented by
[Noctalia](https://docs.noctalia.dev).

## License

Copyright (C) 2026 Siddhartha Mallavolu

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

See [LICENSE](LICENSE) for the full text.
