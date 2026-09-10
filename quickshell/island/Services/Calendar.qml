pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Calendar events.
//
// There is no desktop-wide calendar to read on Linux, so this reads
// khal, which keeps a local store synced by vdirsyncer. Without khal
// installed it reports nothing and the control centre simply omits
// the list — no error, no empty box.
//
//     sudo dnf install khal vdirsyncer

Singleton {
    id: root

    // [{ date, time, title, allDay }]
    property var events: []
    property bool available: false

    readonly property int count: events.length

    readonly property var today: events.filter(e => e.date === todayKey)
    readonly property string todayKey: Qt.formatDateTime(Clock.now, "yyyy-MM-dd")

    function hasEvents(year, month, day) {
        const key = year + "-"
            + String(month + 1).padStart(2, "0") + "-"
            + String(day).padStart(2, "0");
        return events.some(e => e.date === key);
    }

    function refresh() { query.running = true }

    Process {
        id: query
        running: true
        // A fixed format so the output does not depend on the user's
        // khal config. Two weeks is enough for the month view's dots
        // without pulling a year of history.
        command: ["sh", "-c",
            "command -v khal >/dev/null 2>&1 || exit 3; " +
            "khal list --format '{start-date}\\t{start-time}\\t{title}' " +
            "--day-format '' today 14d 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (line.trim() === "") continue;
                    const f = line.split("\t");
                    if (f.length < 3) continue;

                    // khal prints dd/mm/yyyy or yyyy-mm-dd depending on
                    // locale; normalise to the latter.
                    let d = f[0].trim();
                    const slash = d.split("/");
                    if (slash.length === 3) {
                        d = slash[2] + "-" + slash[1].padStart(2, "0")
                          + "-" + slash[0].padStart(2, "0");
                    }

                    out.push({
                        date: d,
                        time: f[1].trim(),
                        title: f.slice(2).join("\t").trim(),
                        allDay: f[1].trim() === ""
                    });
                }
                root.events = out;
            }
        }

        onExited: function(code) {
            root.available = code !== 3;
            if (code === 3) root.events = [];
        }
    }

    Timer {
        running: root.available
        interval: 300000
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "calendar"

        function status(): string {
            if (!root.available) return "khal not installed";
            return root.count + " events, " + root.today.length + " today";
        }
        function refresh(): void { root.refresh() }
    }
}
