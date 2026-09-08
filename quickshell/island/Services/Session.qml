pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Session
//
// Power actions. Each resolves through logind first and falls back
// to the older tools, so this works whether or not systemd owns the
// session.
//
// Nothing here confirms — the island asks before running anything
// destructive, so the confirmation lives with the UI rather than
// being baked into the action.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    readonly property var actions: [
        { id: "lock",     label: "Lock",     glyph: "\uf023" },
        { id: "logout",   label: "Log out",  glyph: "\uf2f5" },
        { id: "suspend",  label: "Suspend",  glyph: "\uf186" },
        { id: "reboot",   label: "Reboot",   glyph: "\uf021" },
        { id: "shutdown", label: "Shut down", glyph: "\uf011" }
    ]

    // Which ones need a second press before they run.
    readonly property var destructive: ["logout", "reboot", "shutdown"]

    function isDestructive(id) {
        return destructive.indexOf(id) !== -1;
    }

    function run(id) {
        let cmd = "";
        switch (id) {
            case "lock":
                cmd = "loginctl lock-session || hyprlock";
                break;
            case "logout":
                // Ask the compositor first; it exits cleanly and lets
                // apps save. loginctl is the blunt fallback.
                cmd = "hyprctl dispatch exit || loginctl terminate-user \"$USER\"";
                break;
            case "suspend":
                cmd = "systemctl suspend || loginctl suspend";
                break;
            case "reboot":
                cmd = "systemctl reboot || loginctl reboot";
                break;
            case "shutdown":
                cmd = "systemctl poweroff || loginctl poweroff";
                break;
            default:
                return;
        }

        proc.command = ["sh", "-c", cmd];
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[Session]", this.text.trim());
            }
        }
    }
}
