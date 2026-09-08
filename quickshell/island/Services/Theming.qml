pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Theming
//
// One setting, three toolkits. Changing the icon theme here writes
// it to all of:
//
//   · GTK  — via gsettings (dconf), which GTK3 and GTK4 both read
//   · Qt   — via qt6ct's config file
//   · Shell — Qt's icon lookup, which is what Quickshell.iconPath
//             resolves against
//
// Without this you'd set the same value in three places and they'd
// drift apart, which is what QS_ICON_THEME was patching over before.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    property var available: []
    property var cursors: []
    property var gtkThemes: []

    // ── Apply ────────────────────────────────────────────────
    //
    // Everything goes in ONE command. An earlier version called three
    // functions that each reassigned the same Process — the first two
    // were clobbered before they ran, and only the last took effect.

    function applyAll() {
        const a = Config.appearance;
        const cmds = [];

        if (a.iconTheme) {
            cmds.push("gsettings set org.gnome.desktop.interface icon-theme '" + a.iconTheme + "'");
            cmds.push(qtctSet("icon_theme", a.iconTheme));
        }

        if (a.gtkTheme) {
            cmds.push("gsettings set org.gnome.desktop.interface gtk-theme '" + a.gtkTheme + "'");
            // GTK4 apps read this file rather than dconf for the theme.
            cmds.push("mkdir -p \"$HOME/.config/gtk-4.0\" \"$HOME/.config/gtk-3.0\"");
            for (const v of ["3.0", "4.0"]) {
                const f = "\"$HOME/.config/gtk-" + v + "/settings.ini\"";
                cmds.push("touch " + f);
                cmds.push("grep -q '^\\[Settings\\]' " + f + " || printf '[Settings]\\n' >> " + f);
                cmds.push("grep -q '^gtk-theme-name=' " + f
                    + " && sed -i \"s|^gtk-theme-name=.*|gtk-theme-name=" + a.gtkTheme + "|\" " + f
                    + " || printf 'gtk-theme-name=" + a.gtkTheme + "\\n' >> " + f);
                cmds.push("grep -q '^gtk-icon-theme-name=' " + f
                    + " && sed -i \"s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=" + a.iconTheme + "|\" " + f
                    + " || printf 'gtk-icon-theme-name=" + a.iconTheme + "\\n' >> " + f);
                cmds.push("grep -q '^gtk-cursor-theme-name=' " + f
                    + " && sed -i \"s|^gtk-cursor-theme-name=.*|gtk-cursor-theme-name=" + a.cursorTheme + "|\" " + f
                    + " || printf 'gtk-cursor-theme-name=" + a.cursorTheme + "\\n' >> " + f);
            }
        }

        if (a.cursorTheme) {
            cmds.push("gsettings set org.gnome.desktop.interface cursor-theme '" + a.cursorTheme + "'");
            cmds.push("gsettings set org.gnome.desktop.interface cursor-size " + a.cursorSize);
            cmds.push("hyprctl setcursor '" + a.cursorTheme + "' " + a.cursorSize + " || true");
            // Keeps XWayland clients in step with the Wayland ones.
            cmds.push("dbus-update-activation-environment --systemd XCURSOR_THEME=" + a.cursorTheme
                + " XCURSOR_SIZE=" + a.cursorSize + " || true");
            cmds.push(qtctSet("cursor_theme", a.cursorTheme));
        }

        if (cmds.length === 0) return;
        proc.command = ["sh", "-c", cmds.join("; ")];
        proc.running = true;
    }

    // qt6ct keeps its settings in an ini; rewrite one key in place so
    // anything else the user set there survives.
    function qtctSet(key, value) {
        const f = "\"$HOME/.config/qt6ct/qt6ct.conf\"";
        return "[ -f " + f + " ] && sed -i \"s|^" + key + "=.*|" + key + "=" + value + "|\" " + f + " || true";
    }

    Process {
        id: proc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[Theming]", this.text.trim());
            }
        }
    }

    // ── Discovery ────────────────────────────────────────────
    // Anything with an index.theme is an icon theme. Listing them
    // means the settings app can offer what's actually installed
    // rather than a hardcoded list.

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
    readonly property string watched:
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
            return proc.command.length > 2 ? proc.command[2] : "(nothing to apply)";
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
