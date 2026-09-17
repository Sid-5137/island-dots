pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

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

    // Every mapped window, across all workspaces, for the switcher.
    // [{ address, cls, title, workspaceId, workspaceName, focused }]
    property var allWindows: []
    property string focusedAddress: ""

    // Dispatchers take Lua now, not a bare command string. `hyprctl
    // dispatch workspace 2` is wrapped as `hl.dispatch(workspace 2)`,
    // which is not valid Lua and fails silently — so every switch and
    // every Alt+Tab did nothing at all.
    function dispatch(lua) {
        Hyprland.dispatch(lua);
        refreshLater.restart();
    }

    // The key is `window`, and its value carries the address: prefix.
    // A bare `address =` is accepted and silently ignored.
    function focusWindow(address) {
        dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
    }

    function moveWindowTo(address, workspaceId) {
        dispatch("hl.dsp.window.move({ workspace = " + workspaceId
                 + ", window = \"address:" + address + "\", follow = false })");
    }

    readonly property bool empty: windowCount === 0

    function refresh() {
        query.running = true;
    }

    function switchTo(id) {
        dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    // What is on a workspace, as one window class — the one you were
    // last in there. For the pod's icon style, which answers "what is
    // over there" rather than "is anything over there". allWindows is
    // already in focus order, so the first hit is the right one, and
    // "" means the workspace is empty.
    function classFor(workspaceId) {
        for (const w of allWindows)
            if (w.workspaceId === workspaceId) return w.cls;
        return "";
    }

    // One workspace either way. Relative rather than arithmetic on
    // `workspaces`: `e+1` is Hyprland's own "the next one that
    // exists", so scrolling the island lands exactly where SUPER+right
    // lands, including when the numbers have gaps in them.
    function cycleWorkspace(step) {
        if (step === 0) return;
        const rel = (step > 0 ? "+" : "-") + Math.abs(step);
        dispatch("hl.dsp.focus({ workspace = \"e" + rel + "\" })");
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
                    const mapped = clients.filter(c => c.mapped && !c.hidden);

                    root.windows = mapped
                        .filter(c => c.workspace && c.workspace.id === root.activeId)
                        .map(c => ({
                            x: c.at[0], y: c.at[1],
                            w: c.size[0], h: c.size[1]
                        }));

                    // Most-recently-focused first, so Alt+Tab lands on
                    // the previous window rather than an arbitrary one.
                    root.allWindows = mapped
                        .filter(c => c.workspace && c.workspace.id > 0)
                        // Current workspace first, then focus history
                        // within each group. Pure focus order sends the
                        // first Tab to whatever you last used, which
                        // may be on another workspace — so a window
                        // sitting next to you needs two presses.
                        .sort((a, b) => {
                            const aHere = a.workspace.id === root.activeId ? 0 : 1;
                            const bHere = b.workspace.id === root.activeId ? 0 : 1;
                            if (aHere !== bHere) return aHere - bHere;
                            return (a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99);
                        })
                        .map(c => ({
                            address: c.address,
                            cls: c.class || c.initialClass || "",
                            title: c.title || "",
                            workspaceId: c.workspace.id,
                            workspaceName: c.workspace.name,
                            focused: c.focusHistoryID === 0
                        }));

                    const f = mapped.find(c => c.focusHistoryID === 0);
                    root.focusedAddress = f ? f.address : "";
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
        running: Config.island.visibility !== "always"
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

        function windows(): string {
            if (root.allWindows.length === 0) return "none";
            return root.allWindows.map(w =>
                w.address + "  ws" + w.workspaceId + "  " + w.cls).join("\n");
        }

        function focus(address: string): void { root.focusWindow(address) }
        function go(id: int): void { root.switchTo(id) }

        function lua(code: string): void { root.dispatch(code) }
    }

    // Actions run detached rather than through a shared Process: a
    // Process that is still running drops the next command assigned
    // to it. State is re-read shortly after instead of on exit.
    Timer {
        id: refreshLater
        interval: 400
        onTriggered: root.refresh()
    }
}
