pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var actions: [
        { id: "lock",     label: "Lock",      glyph: Icons.lock },
        { id: "logout",   label: "Log out",   glyph: Icons.logout },
        { id: "suspend",  label: "Suspend",   glyph: Icons.suspend },
        { id: "reboot",   label: "Reboot",    glyph: Icons.reboot },
        { id: "shutdown", label: "Shut down", glyph: Icons.shutdown }
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
                cmd = "qs -c island ipc call lock activate";
                break;
            case "logout":
                // Ask the compositor first; it exits cleanly and lets
                // apps save. loginctl is the blunt fallback.
                // Lua, not a bare dispatcher name: hyprctl wraps the
                // argument as hl.dispatch(<arg>).
                cmd = "hyprctl dispatch 'hl.dsp.exit()' "
                    + "|| loginctl terminate-user \"$USER\"";
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
