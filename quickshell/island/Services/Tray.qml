pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// System tray.
//
// Referencing SystemTray.items is what makes quickshell start tracking
// the tray at all, so this singleton existing is load-bearing — the
// StatusNotifierItem host is not registered until something asks.

Singleton {
    id: root

    readonly property var items: SystemTray.items
    readonly property int count: items ? items.values.length : 0

    IpcHandler {
        target: "tray"

        function count(): int { return root.count }
        function list(): string {
            if (root.count === 0) return "empty";
            return root.items.values.map(i => i.id + "  " + i.title).join("\n");
        }
    }
}
