pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// The island's keyboard shortcuts, delivered by the compositor.
//
// hypr/binds.lua binds these with hl.dsp.global("island:<name>"), and
// Hyprland hands the press straight to this process over Wayland.
// They used to be `qs -c island ipc call …`: a new process per key,
// about a hundred and twenty milliseconds before the shell heard of
// it — on every Tab of an Alt+Tab, held or not.
//
// A singleton because a global shortcut can be registered once per
// name, and there is an island per screen. The primary one listens.

Singleton {
    id: root

    signal switchNext()
    signal switchPrevious()
    signal switchCancel()
    // Alt went up: a release bind on the bare modifier, which is what
    // lets a switch happen the moment you let go rather than after a
    // timer guesses that you have.
    signal switchRelease()
    signal overviewToggle()

    GlobalShortcut {
        appid: "island"; name: "switcher-next"
        description: "Switch to the next window"
        onPressed: root.switchNext()
    }

    GlobalShortcut {
        appid: "island"; name: "switcher-previous"
        description: "Switch to the previous window"
        onPressed: root.switchPrevious()
    }

    GlobalShortcut {
        appid: "island"; name: "switcher-cancel"
        description: "Cancel switching"
        onPressed: root.switchCancel()
    }

    GlobalShortcut {
        appid: "island"; name: "switcher-release"
        description: "Alt released: commit the switch"
        onPressed: root.switchRelease()
    }

    GlobalShortcut {
        appid: "island"; name: "overview"
        description: "Toggle the overview"
        onPressed: root.overviewToggle()
    }
}
