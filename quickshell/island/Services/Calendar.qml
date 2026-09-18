pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Calendar events.
//
// No desktop-wide calendar service exists on Linux, but .ics on disk
// is the de facto store. bin/island-calendar reads those directly —
// Evolution's store (what GNOME Calendar writes to), plus vdirsyncer
// and khal layouts. khal remains a fallback for anything stored
// somewhere non-standard.
//
// With neither available it reports nothing and the control centre
// omits the list — no error, no empty box.

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

    // Where the events came from, for the settings page and `calendar
    // status`. "" until the first query finishes.
    property string source: ""

    Process {
        id: query
        running: true

        // Both backends emit the same three tab-separated fields, so
        // only the source differs. island-calendar exits 3 when it
        // finds no calendar store at all, which is the signal to try
        // khal before giving up.
        //
        // Two weeks is enough for the month view's dots without
        // pulling a year of history.
        command: ["sh", "-c",
            'PATH="$HOME/.local/bin:$PATH"; ' +
            'if out=$(island-calendar --days 14 2>/dev/null); then ' +
            '  printf "#ics\\n%s" "$out"; exit 0; ' +
            'fi; ' +
            'command -v khal >/dev/null 2>&1 || exit 3; ' +
            'printf "#khal\\n"; ' +
            "khal list --format '{start-date}\\t{start-time}\\t{title}' " +
            '--day-format "" today 14d 2>/dev/null']

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (line.trim() === "") continue;
                    // First line names the backend that answered.
                    if (line[0] === "#") {
                        root.source = line.slice(1).trim();
                        continue;
                    }
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
            if (code === 3) {
                root.events = [];
                root.source = "";
            }
        }
    }

    Timer {
        running: root.available
        interval: 300000
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c",
            'PATH="$HOME/.local/bin:$PATH"; island-calendar --sources']
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                console.log("[Calendar] sources:\n" + (out || "(none)"));
            }
        }
    }

    IpcHandler {
        target: "calendar"

        function status(): string {
            if (!root.available)
                return "no calendar store found (looked for .ics files; "
                     + "khal is not installed either)";
            return root.count + " events, " + root.today.length + " today"
                 + "  ·  via " + (root.source || "?");
        }
        function refresh(): void { root.refresh() }

        // The files island-calendar is actually reading, which is the
        // first thing to check when an event does not show up.
        function sources(): string {
            probe.running = true;
            return "listing to the shell log";
        }
    }
}
