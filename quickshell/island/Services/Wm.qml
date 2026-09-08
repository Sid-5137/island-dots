pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// ─────────────────────────────────────────────────────────────
// Wm
//
// What the compositor is doing: which workspaces exist, which is
// focused, how many windows are on it, and whether anything is
// fullscreen.
//
// Hyprland's event socket is only a trigger — the state itself comes
// from hyprctl's JSON, whose shape is stable. Parsing event payloads
// would mean tracking window counts by hand and drifting out of sync.
//
// "auto" visibility leans on `empty`: a workspace with nothing on it
// has nothing to be in the way of, so the island stays put.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    property int windowCount: 0
    property bool fullscreen: false
    property string workspaceName: ""
    property int activeId: 1

    // [{ id, name, windows }], sorted, for the island's indicator.
    property var workspaces: []

    readonly property bool empty: windowCount === 0

    function refresh() {
        query.running = true;
    }

    function switchTo(id) {
        act.command = ["hyprctl", "dispatch", "workspace", String(id)];
        act.running = true;
    }

    Process {
        id: query
        running: true
        // Two JSON blobs, separated by a marker so one read gets both.
        command: ["sh", "-c",
            "hyprctl activeworkspace -j; echo '###'; hyprctl workspaces -j"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("###");
                if (parts.length < 2) return;

                try {
                    const ws = JSON.parse(parts[0]);
                    root.windowCount = ws.windows ?? 0;
                    root.fullscreen = ws.hasfullscreen ?? false;
                    root.workspaceName = ws.name ?? "";
                    root.activeId = ws.id ?? 1;
                } catch (e) {
                    console.warn("[Wm] activeworkspace parse failed:", e);
                }

                try {
                    const all = JSON.parse(parts[1]);
                    root.workspaces = all
                        // Special workspaces have negative ids and
                        // shouldn't appear in the indicator.
                        .filter(w => w.id > 0)
                        .map(w => ({ id: w.id, name: w.name, windows: w.windows }))
                        .sort((a, b) => a.id - b.id);
                } catch (e) {
                    console.warn("[Wm] workspaces parse failed:", e);
                }
            }
        }
    }

    Process { id: act; running: false; onExited: root.refresh() }

    // Opening a window fires several events at once; coalesce them so
    // one action doesn't spawn five hyprctl calls.
    Timer {
        id: debounce
        interval: 60
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
                case "openwindow":
                case "closewindow":
                case "movewindow":
                case "workspace":
                case "createworkspace":
                case "destroyworkspace":
                case "focusedmon":
                case "fullscreen":
                case "changefloatingmode":
                    debounce.restart();
                    break;
            }
        }
    }

    IpcHandler {
        target: "wm"

        function status(): string {
            return "workspace " + root.workspaceName
                + " · " + root.windowCount + " windows"
                + " · " + root.workspaces.length + " total"
                + (root.fullscreen ? " · fullscreen" : "");
        }

        function refresh(): void { root.refresh() }
    }
}
