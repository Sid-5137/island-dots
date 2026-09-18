pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool wifiEnabled: false
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property string connType: ""          // wifi | ethernet | none

    // [{ ssid, signal, secure, active, known }]
    property var networks: []
    property bool scanning: false
    property string lastError: ""

    // Font Awesome for both, which is what the comment here always
    // claimed and what the wired icon was not: it was U+F6FF, a
    // Material codepoint from Nerd Fonts v2, and it drew exactly the
    // box this comment was written to avoid. See Services/Icons.qml.
    readonly property string icon:
        connType === "ethernet" ? Icons.ethernet : Icons.wifi

    readonly property string label: {
        if (connType === "ethernet") return "Wired";
        if (!wifiEnabled) return "Off";
        if (!connected) return "Disconnected";
        return ssid;
    }

    function toggle() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
        refreshLater.restart();
    }

    function refresh() { poll.running = true }

    function scan() {
        if (scanning) return;
        scanning = true;
        lister.running = true;
    }

    // Connecting to a known network needs no password; nmcli reuses
    // the stored one. A new network needs the passphrase passed in.
    function connect(name, password) {
        lastError = "";
        const q = name.replace(/'/g, "'\\''");
        act.command = password && password !== ""
            ? ["nmcli", "device", "wifi", "connect", name, "password", password]
            : ["sh", "-c", "nmcli connection up id '" + q + "' 2>/dev/null "
                         + "|| nmcli device wifi connect '" + q + "'"];
        act.running = true;
    }

    function disconnect() {
        Quickshell.execDetached(["sh", "-c",
            "nmcli -t -f DEVICE,TYPE device status | grep ':wifi$' | cut -d: -f1 "
            + "| xargs -r -n1 nmcli device disconnect"]);
        refreshLater.restart();
    }

    function forget(name) {
        const q = name.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "nmcli connection delete id '" + q + "'"]);
        refreshLater.restart();
    }

    Process {
        id: poll
        running: true
        command: ["sh", "-c",
            "nmcli radio wifi; " +
            "nmcli -t -f TYPE,STATE device status; " +
            "echo '###'; " +
            "nmcli -t -f IN-USE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep '^\\*' | head -1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("###");
                const lines = parts[0].trim().split("\n");
                if (lines.length === 0) return;

                root.wifiEnabled = lines[0].trim() === "enabled";

                let type = "none", up = false;
                for (const l of lines.slice(1)) {
                    const f = l.split(":");
                    if (f.length < 2) continue;
                    if (f[1] === "connected") {
                        up = true;
                        if (f[0] === "ethernet") { type = "ethernet"; break; }
                        if (f[0] === "wifi") type = "wifi";
                    }
                }
                root.connected = up;
                root.connType = type;

                const active = (parts[1] || "").trim();
                if (active.startsWith("*")) {
                    const f = active.split(":");
                    root.strength = parseInt(f[1]) || 0;
                    root.ssid = f.slice(2).join(":");
                } else {
                    root.strength = 0;
                    root.ssid = "";
                }
            }
        }
    }

    Process {
        id: lister
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME connection show | sort -u > /tmp/.island-known; " +
            "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line === "") continue;
                    const f = line.split(":");
                    if (f.length < 4) continue;
                    const name = f.slice(3).join(":");
                    // Hidden networks report an empty SSID; and the
                    // same network appears once per band.
                    if (name === "" || seen[name]) continue;
                    seen[name] = true;
                    out.push({
                        ssid: name,
                        signal: parseInt(f[1]) || 0,
                        secure: f[2] !== "" && f[2] !== "--",
                        active: f[0] === "*"
                    });
                }
                out.sort((a, b) => b.signal - a.signal);
                root.networks = out;
                root.scanning = false;
            }
        }
    }

    Process {
        id: act
        running: false
        onExited: function(code) {
            if (code !== 0) root.lastError = "Command failed";
            root.refresh();
            root.scan();
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t !== "") root.lastError = t.split("\n")[0];
            }
        }
    }

    // Nothing on the collapsed pill reads this — only the control
    // centre and the settings pages — so the poll runs while
    // something holds it and not otherwise. The first hold refreshes
    // immediately, so a panel opens on current data.
    //
    // A missed release costs a poll that keeps running; a missed hold
    // costs one stale reading. Neither is worth a destructor for.
    property int watchers: 0

    function hold() {
        watchers++;
        if (watchers === 1) refresh();
    }

    function release() {
        watchers = Math.max(0, watchers - 1);
    }

    Timer {
        running: root.watchers > 0
        interval: 5000
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "network"
        function status(): string { return root.label + " (" + root.strength + "%)" }
        function scan(): void { root.scan() }
    }

    // Actions run detached rather than through a shared Process: a
    // Process that is still running drops the next command assigned
    // to it. State is re-read shortly after instead of on exit.
    Timer {
        id: refreshLater
        interval: 400
        onTriggered: { root.refresh(); root.scan(); }
    }
}
