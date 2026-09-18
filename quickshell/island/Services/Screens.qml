pragma Singleton

// island-dots. GPL-3.0 — see LICENSE.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Which monitor the shell's single-instance surfaces belong to.
//
// Island.qml is a Variants over every screen, so everything in it
// exists once per monitor. Right for the pill, wrong for anything that
// can only exist once — IpcHandler targets (two claiming one name
// collide and the loser is silently unregistered), the notification
// popup, and the exclusive keyboard grab. Those gate on `activeName`.
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

    // The scale Qt has already applied to the scene.
    // QT_AUTO_SCREEN_SCALE_FACTOR (hypr/env.lua) makes Qt scale by a
    // screen's devicePixelRatio, but it picks one factor for the
    // application, not one per surface — so on a mixed-DPI setup every
    // island is drawn at the first screen's scale. Island.qml divides
    // by this to correct the ones that differ.
    readonly property real baseScale: {
        const all = Quickshell.screens;
        if (!all || all.length === 0) return 1;
        const d = all[0].devicePixelRatio;
        return d > 0 ? d : 1;
    }

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
