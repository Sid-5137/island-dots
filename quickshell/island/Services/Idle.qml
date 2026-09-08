pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Idle timings.
//
// hypridle has its own config format and cannot read settings.json, so
// this generates hypridle.conf from Config and restarts the daemon when
// the values change. Without it the timings live in two places and
// drift apart.

Singleton {
    id: root

    readonly property string confPath:
        Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"

    function apply() {
        writer.command = ["sh", "-c", script()];
        writer.running = true;
    }

    function script() {
        const i = Config.idle;
        const lock = "qs -c island ipc call lock activate";

        let conf = "# Generated from settings.json by Services/Idle.qml.\n"
                 + "# Edit the Session page in settings, not this file.\n\n"
                 + "general {\n"
                 + "    lock_cmd = " + lock + "\n"
                 + "    before_sleep_cmd = " + lock + "\n"
                 + "    after_sleep_cmd = hyprctl dispatch dpms on\n"
                 + "    ignore_dbus_inhibit = false\n"
                 + "}\n";

        if (i.enabled) {
            if (i.dimTimeout > 0) {
                conf += "\nlistener {\n"
                     +  "    timeout = " + i.dimTimeout + "\n"
                     +  "    on-timeout = brightnessctl -s set " + i.dimLevel + "\n"
                     +  "    on-resume = brightnessctl -r\n"
                     +  "}\n";
            }
            if (i.lockTimeout > 0) {
                conf += "\nlistener {\n"
                     +  "    timeout = " + i.lockTimeout + "\n"
                     +  "    on-timeout = " + lock + "\n"
                     +  "}\n";
            }
            if (i.screenOffTimeout > 0) {
                conf += "\nlistener {\n"
                     +  "    timeout = " + i.screenOffTimeout + "\n"
                     +  "    on-timeout = hyprctl dispatch dpms off\n"
                     +  "    on-resume = hyprctl dispatch dpms on\n"
                     +  "}\n";
            }
            if (i.suspendTimeout > 0) {
                conf += "\nlistener {\n"
                     +  "    timeout = " + i.suspendTimeout + "\n"
                     +  "    on-timeout = systemctl suspend\n"
                     +  "}\n";
            }
        }

        // Heredoc rather than echo: the config contains quotes and
        // newlines that would need escaping through a shell string.
        // setsid detaches the daemon into its own session. Backgrounded
        // with & it stays a child of this Process, and dies with it —
        // which left the config written and nothing watching it.
        return "cat > '" + confPath + "' <<'ISLANDEOF'\n"
             + conf
             + "ISLANDEOF\n"
             + "pkill hypridle 2>/dev/null; "
             + (i.enabled
                ? "sleep 0.3; setsid -f hypridle -c '" + confPath + "' >/dev/null 2>&1; "
                : "")
             + "true";
    }

    Process {
        id: writer
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[Idle]", this.text.trim());
            }
        }
    }

    // Rewriting the file and restarting the daemon on every slider
    // frame would be absurd, so this waits for the drag to settle.
    property string watched:
        Config.idle.enabled + "|" + Config.idle.dimTimeout + "|"
        + Config.idle.dimLevel + "|" + Config.idle.lockTimeout + "|"
        + Config.idle.screenOffTimeout + "|" + Config.idle.suspendTimeout

    onWatchedChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 800
        onTriggered: root.apply()
    }

    IpcHandler {
        target: "idle"
        function apply(): void { root.apply() }
        function preview(): string { return root.script() }
    }
}
