pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Bluetooth
//
// Wraps bluetoothctl. Same reasoning as Network: a short poll is
// simpler than tracking BlueZ over D-Bus for a handful of facts.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    property bool powered: false
    property int connectedCount: 0
    property string firstDevice: ""

    // [{ mac, name, connected, paired }]
    property var devices: []
    property bool scanning: false

    readonly property string icon: connectedCount > 0 ? "\uf294" : "\uf293"

    readonly property string label:
        !powered ? "Off"
        : connectedCount > 0 ? (connectedCount === 1 ? firstDevice : connectedCount + " devices")
        : "On"

    function toggle() {
        act.command = ["bluetoothctl", "power", powered ? "off" : "on"];
        act.running = true;
    }

    function refresh() { poll.running = true }

    // bluetoothctl's scan is interactive and runs until stopped, so
    // it's wrapped in a timeout rather than left open.
    function scan() {
        if (scanning) return;
        scanning = true;
        scanProc.command = ["sh", "-c", "timeout 8 bluetoothctl --timeout 8 scan on >/dev/null 2>&1; true"];
        scanProc.running = true;
    }

    function connect(mac)    { runCtl("connect " + mac) }
    function disconnect(mac) { runCtl("disconnect " + mac) }
    function pair(mac)       { runCtl("pair " + mac) }
    function forget(mac)     { runCtl("remove " + mac) }

    function runCtl(args) {
        act.command = ["sh", "-c", "bluetoothctl " + args];
        act.running = true;
    }

    Process {
        id: poll
        running: true
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null | grep -i 'Powered:' | head -1; " +
            "echo '###'; " +
            "bluetoothctl devices Connected 2>/dev/null; " +
            "echo '###'; " +
            "bluetoothctl devices 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("###");
                root.powered = /powered:\s*yes/i.test(parts[0] || "");

                const connected = (parts[1] || "").trim().split("\n").filter(l => l.startsWith("Device "));
                root.connectedCount = connected.length;
                root.firstDevice = connected.length > 0
                    ? connected[0].split(" ").slice(2).join(" ") : "";

                const connMacs = connected.map(l => l.split(" ")[1]);
                const all = (parts[2] || "").trim().split("\n").filter(l => l.startsWith("Device "));
                root.devices = all.map(l => {
                    const f = l.split(" ");
                    return {
                        mac: f[1],
                        name: f.slice(2).join(" "),
                        connected: connMacs.indexOf(f[1]) !== -1
                    };
                });
            }
        }
    }

    Process {
        id: scanProc
        running: false
        onExited: { root.scanning = false; root.refresh(); }
    }

    Process { id: act; running: false; onExited: root.refresh() }

    Timer {
        running: true
        interval: 6000
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "bluetooth"
        function status(): string { return root.label }
        function scan(): void { root.scan() }
    }
}
