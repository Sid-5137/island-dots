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

    // Geometry of every window on the focused workspace, so the island
    // can tell whether anything actually reaches the strip it sits in
    // rather than hiding whenever any window exists at all.
    // [{ x, y, w, h }]
    property var windows: []

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
            "hyprctl activeworkspace -j; echo '###'; " +
            "hyprctl workspaces -j; echo '###'; hyprctl clients -j"]

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
                    const clients = JSON.parse(parts[2] || "[]");
                    root.windows = clients
                        .filter(c => c.workspace && c.workspace.id === root.activeId
                                     && c.mapped && !c.hidden)
                        .map(c => ({
                            x: c.at[0], y: c.at[1],
                            w: c.size[0], h: c.size[1]
                        }));
                } catch (e) {
                    console.warn("[Wm] clients parse failed:", e);
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

    // Hyprland's socket has no resize event: openwindow, closewindow,
    // movewindow and the workspace events all fire, but dragging a
    // tiled window's edge fires nothing. Geometry therefore goes stale
    // after a resize until some unrelated event happens to refresh it.
    //
    // A slow poll covers the gap, and only while something is reading
    // the geometry — the other visibility modes need nothing but the
    // window count, which the events do cover.
    Timer {
        running: Config.island.visibility === "smart"
        interval: 1200
        repeat: true
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
                case "activewindow":
                case "activewindowv2":
                case "movewindowv2":
                case "togglegroup":
                case "pin":
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
                + " · " + root.windows.length + " mapped"
                + (root.fullscreen ? " · fullscreen" : "");
        }

        function refresh(): void { root.refresh() }
    }
}
