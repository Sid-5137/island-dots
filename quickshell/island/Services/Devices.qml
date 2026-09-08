pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Input devices, from hyprctl.
//
// Hyprland lists touchpads under "mice", distinguished only by their
// name, so they're separated here by matching the usual substrings.
// The alternative is asking the user which is which, which is worse.

Singleton {
    id: root

    property var mice: []          // pointing devices that aren't touchpads
    property var touchpads: []
    property var keyboards: []

    readonly property bool hasTouchpad: touchpads.length > 0
    readonly property bool hasMouse: mice.length > 0

    function isTouchpad(name) {
        const n = name.toLowerCase();
        return n.includes("touchpad") || n.includes("trackpad")
            || n.includes("synaptics") || n.includes("glidepoint")
            || n.includes("elan") && n.includes("pad");
    }

    function refresh() { query.running = true }

    Process {
        id: query
        running: true
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const pointers = (d.mice || []).map(m => m.name);
                    root.touchpads = pointers.filter(n => root.isTouchpad(n));
                    root.mice = pointers.filter(n => !root.isTouchpad(n));
                    root.keyboards = (d.keyboards || []).map(k => k.name);
                } catch (e) {
                    console.warn("[Devices] parse failed:", e);
                }
            }
        }
    }

    IpcHandler {
        target: "devices"

        function list(): string {
            return "touchpads: " + (root.touchpads.join(", ") || "none")
                + "\nmice: " + (root.mice.join(", ") || "none")
                + "\nkeyboards: " + (root.keyboards.join(", ") || "none");
        }

        function refresh(): void { root.refresh() }
    }
}
