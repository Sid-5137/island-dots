pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var available: []
    property var cursors: []
    property var gtkThemes: []

    // bin/island-gtk-apply does the actual work. It is a script and
    // not a string of shell built here because it has to touch
    // gsettings, two settings.ini files, two gtk.css files and
    // qt6ct.conf, and quoting all of that through QML was where the
    // GTK half of theming kept breaking.
    function applyAll() {
        const a = Config.appearance;

        // A Process that is still running silently drops whatever is
        // assigned to it next, so a burst of changes coalesces into
        // one run rather than losing the last one.
        if (proc.running) {
            debounce.restart();
            return;
        }

        proc.command = [
            // Hyprland does not always start the shell with
            // ~/.local/bin on PATH, and that is where install.sh puts
            // the script.
            "sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec island-gtk-apply "$@"',
            "sh",
            "--gtk", a.gtkTheme || "",
            "--icon", a.iconTheme || "",
            "--cursor", a.cursorTheme || "",
            "--cursor-size", String(a.cursorSize || 24)
        ];
        proc.running = true;
    }

    Process {
        id: proc
        running: false

        onExited: function(code) {
            if (code === 127)
                console.warn("[Theming] island-gtk-apply not found on PATH —"
                    + " run install.sh to link it into ~/.local/bin");
            else if (code !== 0)
                console.warn("[Theming] island-gtk-apply exited with", code);
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[Theming]", this.text.trim());
            }
        }
    }

    // Search every standard location, including Flatpak's exports and
    // anything on XDG_DATA_DIRS — a scan of /usr/share/icons alone
    // misses themes installed per-user or by Flatpak.
    readonly property string iconDirs:
        "/usr/share/icons /usr/local/share/icons " +
        "$HOME/.local/share/icons $HOME/.icons " +
        "/var/lib/flatpak/exports/share/icons " +
        "$HOME/.local/share/flatpak/exports/share/icons " +
        "$(echo \"${XDG_DATA_DIRS:-}\" | tr ':' ' ' | sed 's|\\([^ ]*\\)|\\1/icons|g')"

    Process {
        id: iconScan
        running: true
        command: ["sh", "-c",
            "for d in " + root.iconDirs + "; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  for t in \"$d\"/*/; do " +
            "    [ -f \"$t/index.theme\" ] || continue; " +
            // A theme with no directories listed is a cursor theme.
            "    if grep -qi '^Directories' \"$t/index.theme\" 2>/dev/null; then " +
            "      basename \"$t\"; " +
            "    fi; " +
            "  done; " +
            "done | sort -u"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                root.available = out === "" ? [] : out.split("\n");
                console.log("[Theming] found", root.available.length, "icon themes");
            }
        }
    }

    // Cursor themes live in the same tree but have a cursors/ dir.
    Process {
        id: cursorScan
        running: true
        command: ["sh", "-c",
            "for d in " + root.iconDirs + "; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  for t in \"$d\"/*/; do " +
            "    [ -d \"$t/cursors\" ] && basename \"$t\"; " +
            "  done; " +
            "done | sort -u"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                root.cursors = out === "" ? [] : out.split("\n");
            }
        }
    }

    // GTK themes are a separate tree.
    Process {
        id: gtkScan
        running: true
        command: ["sh", "-c",
            "for d in /usr/share/themes $HOME/.local/share/themes $HOME/.themes; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  for t in \"$d\"/*/; do " +
            "    { [ -d \"$t/gtk-3.0\" ] || [ -d \"$t/gtk-4.0\" ]; } && basename \"$t\"; " +
            "  done; " +
            "done | sort -u"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                root.gtkThemes = out === "" ? [] : out.split("\n");
            }
        }
    }

    // Reapply whenever any of the three change.
    // Not readonly, for the same reason as Compositor: an unread
    // readonly binding is evaluated lazily and never signals.
    property string watched:
        Config.appearance.iconTheme + "|"
        + Config.appearance.cursorTheme + "|"
        + Config.appearance.cursorSize + "|"
        + Config.appearance.gtkTheme

    onWatchedChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 200
        onTriggered: root.applyAll()
    }

    IpcHandler {
        target: "theming"
        function apply(): void { root.applyAll() }
        function preview(): string {
            root.applyAll();
            // From index 4: the sh -c wrapper and its $0 are noise.
            return proc.command.length > 4
                ? proc.command.slice(4).join(" ") : "(nothing to apply)";
        }
        function icons(): string { return root.available.join(", ") }
        function cursors(): string { return root.cursors.join(", ") }
        function gtk(): string { return root.gtkThemes.join(", ") }
        function rescan(): void {
            iconScan.running = true;
            cursorScan.running = true;
            gtkScan.running = true;
        }
    }
}
