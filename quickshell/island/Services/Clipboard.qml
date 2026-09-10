pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history, from cliphist.
//
// cliphist stores entries as "<id>\t<preview>" and holds the real
// content itself, so decoding is a second call. That keeps the list
// cheap even when an entry is a megabyte of image data.

Singleton {
    id: root

    // [{ id, preview, isImage }]
    property var entries: []
    property bool loading: false

    readonly property int count: entries.length

    function refresh() {
        if (loading) return;
        loading = true;
        lister.running = true;
    }

    // cliphist decode writes the original bytes, so this round-trips
    // through wl-copy rather than trying to handle content in QML.
    function copy(id) {
        Quickshell.execDetached(["sh", "-c",
            "cliphist decode " + id + " | wl-copy"]);
        refreshLater.restart();
    }

    function remove(id) {
        Quickshell.execDetached(["sh", "-c",
            "cliphist decode " + id + " | cliphist delete"]);
        refreshLater.restart();
        entries = entries.filter(e => e.id !== id);
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        refreshLater.restart();
        entries = [];
    }

    Process {
        id: lister
        running: false
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (line === "") continue;
                    const tab = line.indexOf("\t");
                    if (tab === -1) continue;
                    const preview = line.slice(tab + 1);
                    out.push({
                        id: line.slice(0, tab),
                        preview: preview,
                        // cliphist marks images with a bracketed note
                        // rather than giving them a type.
                        isImage: preview.startsWith("[[ binary data")
                    });
                }
                root.entries = out;
                root.loading = false;
            }
        }
    }

    Process {
        id: act
        running: false
        onExited: root.refresh()
    }

    IpcHandler {
        target: "clipboard"

        function count(): int { return root.entries.length }
        function wipe(): void { root.wipe() }
        function refresh(): void { root.refresh() }
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
