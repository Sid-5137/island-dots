pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: Config.wallpaper.directory
    readonly property string statePath: Paths.wallpaper

    // ── One wallpaper, or one per monitor ────────────────────────
    //
    // `chosen` maps a monitor name to its wallpaper, with "_all" as
    // the one used by any screen that has not been given its own. With
    // perMonitor off only "_all" is ever written, which is exactly the
    // single-wallpaper behaviour this had before.
    //
    // The palette cannot be per monitor — there is one GTK theme, one
    // set of window borders and one shell — so it is always derived
    // from the wallpaper on the focused screen. Moving between
    // monitors does not re-derive it; changing a wallpaper does.
    property var chosen: ({ _all: "" })

    function pathFor(name) {
        if (Config.wallpaper.perMonitor && name && chosen[name])
            return chosen[name];
        return chosen._all || "";
    }

    // The wallpaper the palette comes from.
    readonly property string current: pathFor(Screens.activeName)

    property var list: []
    property bool busy: false

    // Which formats the renderer can actually decode. Qt ships no
    // WebP plugin of its own (it comes from qt6-qtimageformats), so a
    // format is probed at startup by decoding a one-pixel image of it
    // and offered only if that worked. Install the package and the
    // files appear on the next scan.
    readonly property var probes: ({
        webp: "data:image/webp;base64,UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="
    })

    // jpg and png are built into Qt and never need checking.
    property var formats: ["jpg", "jpeg", "png"]

    // Number of files skipped because nothing here can display them,
    // so the settings page can say so instead of quietly omitting.
    property int unsupported: 0

    // Instantiator, not Repeater: a Repeater needs a visual parent to
    // instantiate into and this singleton has none, so its delegates
    // were never created and the probe never ran.
    Instantiator {
        model: Object.keys(root.probes)

        delegate: Image {
            required property var modelData

            source: root.probes[modelData]
            asynchronous: false
            cache: false

            onStatusChanged: {
                if (status === Image.Ready) {
                    if (root.formats.indexOf(modelData) === -1) {
                        
                        root.formats = root.formats.concat([modelData]);
                        root.refresh();
                    }
                } else if (status === Image.Error) {
                    // console.warn, not console.log: the log only
                    // carries warnings, and Qt has just emitted its
                    // own unexplained "Unsupported image format" for
                    // this probe. This is the line that says why.
                    console.warn("[Wallpaper] no decoder for ." + modelData
                        + " — install qt6-qtimageformats to use those"
                        + " wallpapers. They are left out of the picker"
                        + " rather than offered as blank tiles.");
                }
            }
        }
    }

    // Set the wallpaper for one screen, or for all of them.
    //
    // `screen` is a monitor name, or "" for every screen. With
    // perMonitor off it is ignored: there is only one wallpaper.
    function set(path, force, screen) {
        if (!path)
            return;

        const perMonitor = Config.wallpaper.perMonitor;
        const target = (perMonitor && screen) ? screen : "_all";

        if (chosen[target] === path && force !== true) {
            // Same image: nothing to fade, but the palette may still
            // need regenerating after a scheme change.
            return;
        }

        // Reassigned rather than mutated: QML does not see a change
        // signal for a property var that is edited in place, so the
        // layers would keep the old wallpaper.
        const next = Object.assign({}, chosen);
        next[target] = path;

        // Per-screen entries are deliberately kept when the shared
        // wallpaper changes. pathFor() already ignores them unless
        // perMonitor is on, so they cannot leak into the single
        // wallpaper case — and keeping them means turning the setting
        // off and on again does not throw away the assignments.
        chosen = next;
        save();

        // Only the focused screen's wallpaper decides the palette.
        const source = pathFor(Screens.activeName);
        if (source !== "") generate(source);
    }

    function setForScreen(screen, path) { set(path, false, screen) }

    function save() {
        stateFile.setText(JSON.stringify(root.chosen));
    }

    function reapply() {
        // A preset is not derived from an image, so it renders on a
        // machine with no wallpaper set at all — which is also the
        // first run on a fresh install.
        if (current !== "" || Config.appearance.colorSource === "preset")
            generate(current);
    }

    // Stepping and rotation act on the focused screen when wallpapers
    // are per monitor, and on everything when they are not.
    readonly property string stepScreen:
        Config.wallpaper.perMonitor ? Screens.activeName : ""

    function next() {
        if (list.length === 0)
            return;
        const i = list.indexOf(current);
        set(list[(i + 1) % list.length], false, stepScreen);
    }

    function previous() {
        if (list.length === 0)
            return;
        const i = list.indexOf(current);
        set(list[(i - 1 + list.length) % list.length], false, stepScreen);
    }

    function random() {
        if (list.length === 0)
            return;
        set(list[Math.floor(Math.random() * list.length)], false, stepScreen);
    }

    function refresh() {
        lister.running = true;
    }

    // Re-scan when the configured directory changes.
    onDirChanged: refresh()

    property string pending: ""

    // Two sources, one set of outputs. Either way the templates in
    // matugen/templates/ are what gets filled, so everything
    // downstream — the shell, GTK, Qt, KDE, the window borders — is
    // told the same thing in the same files and never learns which
    // source it was. See Services/Config.qml, appearance.colorSource.
    function generate(path) {
        if (busy) {
            pending = path;
            return;
        }
        busy = true;
        watchdog.restart();

        if (Config.appearance.colorSource === "preset") {
            // Hyprland does not always start the shell with
            // ~/.local/bin on PATH, and that is where install.sh puts
            // the script — the same dance Services/Theming.qml does.
            matugen.command = [
                "sh", "-c",
                'PATH="$HOME/.local/bin:$PATH"; exec island-palette "$1"',
                "sh", Config.appearance.preset
            ];
        } else {
            matugen.command = [
                "matugen",
                // Generated by install.sh with this machine's absolute
                // paths filled in — matugen's TOML cannot expand one.
                "--config", Paths.matugenConfig,
                "image", path,
                "--source-color-index", "0",
                "-t", Config.wallpaper.scheme
            ];
        }
        matugen.running = true;
    }

    // Changing the source, or the preset, re-renders everything. There
    // is nothing else to do about it: the palette is a set of files on
    // disk, and until they are rewritten the desktop is still wearing
    // the last answer.
    Connections {
        target: Config.appearance

        function onColorSourceChanged() { root.reapply() }
        function onPresetChanged() { root.reapply() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        // Create the file (and its directory) if this is a first run.
        preload: true

        onLoaded: {
            const saved = stateFile.text().trim();
            if (saved === "") return;

            // Older installs wrote a bare path. Read it as the shared
            // wallpaper rather than starting from nothing.
            if (saved[0] !== "{") {
                root.chosen = { _all: saved };
                return;
            }

            try {
                const parsed = JSON.parse(saved);
                if (parsed && typeof parsed === "object")
                    root.chosen = Object.assign({ _all: "" }, parsed);
            } catch (e) {
                console.warn("[Wallpaper] state file is not readable —", e);
                root.chosen = { _all: saved };
            }
        }
    }

    Process {
        id: lister
        running: true

        // Everything is listed, then split by whether this build can
        // decode it — so the count of skipped files is knowable rather
        // than the files merely being absent.
        command: [
            "sh", "-c",
            "find '" + root.dir + "' -type f "
            + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' "
            + "-o -iname '*.webp' -o -iname '*.avif' -o -iname '*.jxl' "
            + "\\) 2>/dev/null | sort"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                const all = out === "" ? [] : out.split("\n");

                const usable = all.filter(p => {
                    const dot = p.lastIndexOf(".");
                    if (dot < 0) return false;
                    return root.formats.indexOf(
                        p.slice(dot + 1).toLowerCase()) !== -1;
                });

                root.unsupported = all.length - usable.length;
                root.list = usable;

                // First run with nothing saved: take the first one.
                if (root.current === "" && root.list.length > 0)
                    root.set(root.list[0], false, "");
            }
        }
    }

    // Turning per-monitor wallpapers on or off changes which wallpaper
    // the palette should come from, without any wallpaper being set.
    // Without this the palette keeps whatever it was derived from
    // last — so switching the option off left the desktop on the
    // colours of a wallpaper no screen was showing any more.
    //
    // Deliberately not bound to `current` itself: that also changes
    // when focus moves between monitors showing different wallpapers,
    // and re-running matugen every time you cross screens would make
    // Alt+Tab repaint the entire desktop.
    Connections {
        target: Config.wallpaper
        function onPerMonitorChanged() { root.reapply() }
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
                console.warn("[Wallpaper] the palette run did not finish;"
                             + " releasing lock");
                root.busy = false;
                if (root.pending !== "") {
                    const next = root.pending;
                    root.pending = "";
                    root.generate(next);
                }
            }
        }
    }

    Process {
        id: matugen
        running: false

        onExited: function(code) {
            root.busy = false;
            watchdog.stop();
            if (code !== 0)
                console.warn("[Wallpaper]",
                             Config.appearance.colorSource === "preset"
                                 ? "island-palette" : "matugen",
                             "exited with", code);

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

    IpcHandler {
        target: "wallpaper"

        function next(): void { root.next() }
        function previous(): void { root.previous() }
        function random(): void { root.random() }
        function refresh(): void { root.refresh() }
        function set(path: string): void { root.set(path) }
        function reapply(): void { root.reapply() }
        function current(): string { return root.current }

        // Which wallpaper each screen is showing, and where it came
        // from — the screen's own choice or the shared one.
        function screens(): string {
            return Quickshell.screens.map(s => {
                const own = root.chosen[s.name];
                return s.name + "  " + root.pathFor(s.name)
                    + (Config.wallpaper.perMonitor
                       ? (own ? "  (its own)" : "  (shared)")
                       : "  (shared)");
            }).join("\n");
        }

        function setOn(screen: string, path: string): void {
            root.setForScreen(screen, path);
        }
    }
}
