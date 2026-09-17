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

    // ── Fonts ────────────────────────────────────────────────────
    //
    // Two lists, because the two settings have different jobs and
    // different ways of going wrong.
    //
    // `fonts` drives the interface font and is filtered by GLYPH
    // rather than by name — ':charset=f0928', the same probe
    // install.sh uses, md-wifi_strength_4 out of the shell's own
    // register. Every icon the shell draws is a codepoint in the text
    // font, not an image; Services/Icons.qml is the list. So an
    // interface font without them turns the Wi-Fi bars, the settings
    // tabs and the padlock on a secured network into boxes, and does
    // it everywhere at once. A dropdown that can only offer fonts
    // which answer that probe cannot be used to do that, which is
    // worth more than offering all 132 and a warning underneath.
    //
    // `monoFonts` is the plain fontconfig question, ':spacing=100'.
    // Nothing drawn in the mono font is an icon — clipboard entries,
    // workspace numbers, the password field, the value beside a
    // slider — so there is nothing to protect and no reason to narrow
    // the list.
    property var fonts: []
    property var monoFonts: []

    // fontconfig names every weight a font was patched into as a
    // family of its own: "JetBrainsMono NF" arrives alongside NF
    // Light, NF Medium, NF SemiBold and six more, and 206 families on
    // this machine are about 132 fonts. Worse, "ExtraBold" as an
    // interface font is a mistake the list should not be holding the
    // door open for.
    //
    // So a weight word at the end goes — but only when the family it
    // is a weight OF is installed too. Somebody whose only copy of a
    // face is "Iosevka Light" still gets to choose it.
    function families(text) {
        const all = [];
        for (const line of text.split("\n"))
            for (const name of line.split(",")) {
                const f = name.trim();
                if (f !== "" && all.indexOf(f) < 0) all.push(f);
            }

        const weight = /^(Thin|ExtraLight|UltraLight|Light|Regular|Book|Medium|SemiBold|DemiBold|Bold|ExtraBold|UltraBold|Black|Heavy|Italic|Oblique)$/i;   // Adobe spells it Semibold, Nerd Fonts SemiBold

        return all.filter(f => {
            const cut = f.lastIndexOf(" ");
            if (cut < 0 || !weight.test(f.slice(cut + 1))) return true;
            return all.indexOf(f.slice(0, cut)) < 0;
        }).sort((a, b) => a.localeCompare(b));
    }

    Process {
        id: fontScan
        running: true
        command: ["sh", "-c", "fc-list ':charset=f0928' family 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fonts = root.families(this.text);
                console.log("[Theming] found", root.fonts.length,
                            "fonts carrying the shell's icon glyphs");
                if (root.fonts.length === 0)
                    console.warn("[Theming] no font answers ':charset=f0928' —"
                        + " the icons will be boxes until a Nerd Font v3 is"
                        + " installed. See install.sh.");
            }
        }
    }

    Process {
        id: monoScan
        running: true
        command: ["sh", "-c", "fc-list ':spacing=100' family 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monoFonts = root.families(this.text);
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
        function fonts(): string { return root.fonts.join(", ") }
        function mono(): string { return root.monoFonts.join(", ") }
        function rescan(): void {
            iconScan.running = true;
            cursorScan.running = true;
            gtkScan.running = true;
            fontScan.running = true;
            monoScan.running = true;
        }
    }
}
