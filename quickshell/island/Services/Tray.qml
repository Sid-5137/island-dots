pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// System tray.
//
// Referencing SystemTray.items is what makes quickshell register as
// the StatusNotifierItem host, so this singleton existing is
// load-bearing — no application can place an icon until something
// asks for the list.

Singleton {
    id: root

    readonly property var items: SystemTray.items
    readonly property int count: items ? items.values.length : 0

    readonly property bool anyAttention: {
        if (!items) return false;
        for (const i of items.values) {
            if (i.status === Status.NeedsAttention) return true;
        }
        return false;
    }

    IpcHandler {
        target: "tray"

        function count(): int { return root.count }

        function list(): string {
            if (root.count === 0) return "empty";
            return root.items.values.map(i =>
                i.id
                + (i.title !== "" ? "  " + i.title : "")
                + (i.hasMenu ? "  [menu]" : "")
                + (i.onlyMenu ? " only" : "")
                + (i.status === Status.NeedsAttention
                   ? "  [attention]" : "")
            ).join("\n");
        }

        // Activating from the command line is useful when an item has
        // no visible icon because its theme lookup failed.
        function activate(id: string): void {
            if (!root.items) return;
            for (const i of root.items.values) {
                if (i.id === id) { i.activate(); return; }
            }
        }
    }
}
