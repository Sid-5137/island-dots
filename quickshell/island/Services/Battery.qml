pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool present: false
    property int level: 0
    property string status: "Unknown"     // Charging | Discharging | Full | Not charging
    property int timeToEmpty: 0           // minutes, 0 when unknown

    readonly property bool charging: status === "Charging"
    readonly property bool full: status === "Full" || (charging && level >= 99)
    readonly property bool low: !charging && level <= 20
    readonly property bool critical: !charging && level <= 10

    // Font Awesome, matching the rest of the shell's icon set.
    readonly property string icon:
        charging ? "\uf0e7"
        : level > 80 ? "\uf240"
        : level > 60 ? "\uf241"
        : level > 40 ? "\uf242"
        : level > 20 ? "\uf243"
        : "\uf244"

    readonly property string label: {
        if (!present) return "No battery";
        if (full) return "Full";
        if (charging) return "Charging";
        if (timeToEmpty > 0) {
            const h = Math.floor(timeToEmpty / 60);
            const m = timeToEmpty % 60;
            return h > 0 ? h + "h " + m + "m left" : m + "m left";
        }
        return "On battery";
    }

    function refresh() { poll.running = true }

    Process {
        id: poll
        running: true
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); " +
            "[ -z \"$b\" ] && { echo 'none'; exit 0; }; " +
            "cat \"$b/capacity\" 2>/dev/null; " +
            "cat \"$b/status\" 2>/dev/null; " +
            // energy_now / power_now gives hours remaining; some
            // machines expose charge_* instead, hence the fallback.
            "e=$(cat \"$b/energy_now\" 2>/dev/null || cat \"$b/charge_now\" 2>/dev/null); " +
            "p=$(cat \"$b/power_now\" 2>/dev/null || cat \"$b/current_now\" 2>/dev/null); " +
            "if [ -n \"$e\" ] && [ -n \"$p\" ] && [ \"$p\" -gt 0 ]; then " +
            "  echo $(( e * 60 / p )); else echo 0; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                if (l.length === 0 || l[0] === "none") {
                    root.present = false;
                    return;
                }
                root.present = true;
                root.level = parseInt(l[0]) || 0;
                root.status = (l[1] || "Unknown").trim();
                root.timeToEmpty = parseInt(l[2]) || 0;
            }
        }
    }

    Timer {
        running: true
        interval: 20000
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "battery"
        function status(): string {
            return root.present
                ? root.level + "% · " + root.label
                : "no battery";
        }
    }
}
