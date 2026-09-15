pragma Singleton

// island-dots — a Hyprland shell built around a morphing pill.
// Copyright (C) 2026 Siddhartha Mallavolu
//
// This program is free software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. See LICENSE.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Which monitor the shell's single-instance surfaces belong to.
//
// Island.qml is a Variants over every screen, so on a two-monitor
// machine every declaration inside it exists twice. That is right for
// the pill — you want one per screen — and wrong for everything that
// can only exist once:
//
//   - IpcHandler targets. Two handlers claiming "launcher" collide,
//     and whichever loses is simply not registered. Every shell bind
//     then works or doesn't depending on load order.
//   - The notification popup, which otherwise appears on both screens.
//   - Keyboard focus. Two surfaces asking for an exclusive grab is
//     one more than the compositor will give out.
//
// Those are gated on `activeName` so exactly one island owns them at a
// time: the one on the monitor you are actually looking at.
//
// Hyprland maintains the focused monitor itself and Quickshell mirrors
// it, so this follows the compositor rather than polling it.
Singleton {
    id: root

    // Name of the monitor Hyprland considers focused. Falls back to
    // the first screen, which is also what a single-monitor machine
    // resolves to before the first focusedmon event arrives.
    readonly property string activeName: {
        const f = Hyprland.focusedMonitor;
        if (f && f.name) return f.name;
        const all = Quickshell.screens;
        return (all && all.length > 0) ? all[0].name : "";
    }

    // The matching ShellScreen, for surfaces that take a `screen:`.
    // Deliberately a property rather than a function: a function call
    // would not re-evaluate when the focus moves.
    readonly property var active: {
        const all = Quickshell.screens;
        if (!all || all.length === 0) return null;
        for (const s of all) {
            if (s.name === root.activeName) return s;
        }
        return all[0];
    }

    readonly property int count: Quickshell.screens.length
    readonly property bool multi: count > 1

    IpcHandler {
        target: "screens"

        function status(): string {
            return Quickshell.screens.map(s =>
                (s.name === root.activeName ? "* " : "  ")
                + s.name + "  " + s.width + "x" + s.height).join("\n");
        }

        function active(): string { return root.activeName }
    }
}
