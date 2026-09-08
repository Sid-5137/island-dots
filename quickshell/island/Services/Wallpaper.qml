pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Wallpaper
//
// Owns which wallpaper is current, the list of available ones, and
// the matugen call. Nothing here draws — WallpaperLayer binds to
// `current` and handles the crossfade.
//
// The chosen path is persisted so the next login restores it.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: Config.wallpaper.directory
    readonly property string statePath: home + "/.local/state/island/wallpaper"

    property string current: ""
    property var list: []
    property bool busy: false

    // ── Actions ──────────────────────────────────────────────

    function set(path) {
        if (!path || path === current)
            return;

        current = path;
        stateFile.setText(path);
        generate(path);
    }

    function next() {
        if (list.length === 0)
            return;
        const i = list.indexOf(current);
        set(list[(i + 1) % list.length]);
    }

    function previous() {
        if (list.length === 0)
            return;
        const i = list.indexOf(current);
        set(list[(i - 1 + list.length) % list.length]);
    }

    function random() {
        if (list.length === 0)
            return;
        set(list[Math.floor(Math.random() * list.length)]);
    }

    function refresh() {
        lister.running = true;
    }

    // Re-scan when the configured directory changes.
    onDirChanged: refresh()

    // Regenerate the palette. scheme-monochrome keeps everything
    // greyscale while still tracking the wallpaper's luminance.
    // Drop the -t flag for full color.
    // Queued rather than fired directly: reassigning a Process that
    // is still running silently drops the new command, which is why
    // changing wallpapers quickly used to apply only some of them.
    property string pending: ""

    function generate(path) {
        if (busy) {
            pending = path;
            return;
        }
        busy = true;
        watchdog.restart();
        matugen.command = [
            "matugen",
            "--config", root.home + "/island-dots/matugen/config.toml",
            "image", path,
            "--source-color-index", "0",
            "-t", Config.wallpaper.scheme
        ];
        matugen.running = true;
    }

    // ── Persistence ──────────────────────────────────────────

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        // Create the file (and its directory) if this is a first run.
        preload: true

        onLoaded: {
            const saved = stateFile.text().trim();
            if (saved !== "")
                root.current = saved;
        }
    }

    // ── Listing ──────────────────────────────────────────────

    Process {
        id: lister
        running: true
        command: [
            "sh", "-c",
            "find '" + root.dir + "' -type f "
            + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' "
            + "-o -iname '*.webp' \\) 2>/dev/null | sort"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                root.list = out === "" ? [] : out.split("\n");

                // First run with nothing saved: take the first one.
                if (root.current === "" && root.list.length > 0)
                    root.set(root.list[0]);
            }
        }
    }

    // Optional rotation. 0 in the config disables it.
    Timer {
        running: Config.wallpaper.rotateMinutes > 0
        interval: Math.max(1, Config.wallpaper.rotateMinutes) * 60000
        repeat: true
        onTriggered: root.random()
    }

    // If matugen never exits — a bad image, a hung process — `busy`
    // would stay true and every later change would queue behind it
    // forever. Release the lock after 15s rather than wedging.
    Timer {
        id: watchdog
        interval: 15000
        onTriggered: {
            if (root.busy) {
                console.warn("[Wallpaper] matugen did not finish; releasing lock");
                root.busy = false;
                if (root.pending !== "") {
                    const next = root.pending;
                    root.pending = "";
                    root.generate(next);
                }
            }
        }
    }

    // ── Matugen ──────────────────────────────────────────────

    Process {
        id: matugen
        running: false

        onExited: function(code) {
            root.busy = false;
            watchdog.stop();
            if (code !== 0)
                console.warn("Wallpaper: matugen exited with", code);

            // Run whatever arrived while we were busy. Only the last
            // one matters — intermediate palettes would be overwritten
            // a moment later anyway.
            if (root.pending !== "") {
                const next = root.pending;
                root.pending = "";
                root.generate(next);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("matugen:", this.text.trim());
            }
        }
    }

    // ── IPC ──────────────────────────────────────────────────
    // Wired to SUPER+SHIFT+W in binds.conf:
    //   qs -c island ipc call wallpaper next

    IpcHandler {
        target: "wallpaper"

        function next(): void { root.next() }
        function previous(): void { root.previous() }
        function random(): void { root.random() }
        function refresh(): void { root.refresh() }
        function set(path: string): void { root.set(path) }
        function current(): string { return root.current }
    }
}
