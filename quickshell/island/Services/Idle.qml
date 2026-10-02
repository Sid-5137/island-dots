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
                 + "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ state = \"on\" })'\n"
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
                     +  "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ state = \"off\" })'\n"
                     +  "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ state = \"on\" })'\n"
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

    // ── Keep awake ───────────────────────────────────────────
    //
    // The control centre's toggle. It used to set a flag nothing read,
    // so the screen dimmed, locked and suspended on schedule with it on.
    //
    // A logind inhibitor, held for exactly as long as the toggle is on.
    // hypridle honours it (ignore_systemd_inhibit is off), it blocks
    // the suspend at the end of the idle chain as well as the dim and
    // the lock, and it shows in `systemd-inhibit --list`, so whether it
    // is working is one command away. Not the Wayland idle inhibitor:
    // that one counts only while its window is on screen, and this
    // shell's windows are behind every fullscreen video — exactly when
    // you would want it. Closing the lid still sleeps; logind lets the
    // lid through any inhibitor unless told otherwise.
    //
    // What it holds the inhibitor open with watches this shell and
    // exits when it does, so a crash cannot leave the machine unable to
    // sleep until someone thinks to look.
    readonly property bool keepAwake: Config.island.caffeine

    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--mode=block",
                  "--who=island", "--why=Keep awake is on",
                  "sh", "-c",
                  "shell=$(ps -o ppid= -p $PPID | tr -d ' '); "
                  + "while kill -0 \"$shell\" 2>/dev/null; do sleep 15; done"]
    }

    IpcHandler {
        target: "idle"
        function apply(): void { root.apply() }
        function preview(): string { return root.script() }
        function keepAwake(): string { return root.keepAwake ? "on" : "off" }
    }
}
