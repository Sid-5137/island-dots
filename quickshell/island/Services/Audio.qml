pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int volume: 0
    property bool muted: false
    property int brightness: 0
    property bool micMuted: false

    // Font Awesome codepoints rather than Material: they're present in
    // every Nerd Font patch, and the Material set renders as boxes on
    // some builds.
    readonly property string volumeIcon:
        muted ? "\uf6a9"
        : volume > 66 ? "\uf028"
        : volume > 33 ? "\uf027"
        : "\uf026"

    readonly property string micIcon: micMuted ? "\uf131" : "\uf130"

    readonly property string brightnessIcon: "\uf185"

    function setVolume(v) {
        run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(v) + "%");
        volume = v;
    }

    function toggleMute() {
        run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
        muted = !muted;
    }

    function toggleMic() {
        run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle");
        micMuted = !micMuted;
    }

    function setBrightness(v) {
        run("brightnessctl --class=backlight set " + Math.round(v) + "%");
        brightness = v;
    }

    function run(cmd) {
        act.command = ["sh", "-c", cmd];
        act.running = true;
    }

    function refresh() { poll.running = true }

    Process {
        id: poll
        running: true
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; " +
            "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed 's/^Volume:/Mic:/'; " +
            "brightnessctl -m 2>/dev/null | cut -d, -f4"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                for (const l of lines) {
                    if (l.startsWith("Volume:")) {
                        root.volume = Math.round(parseFloat(l.split(" ")[1]) * 100);
                        root.muted = l.includes("MUTED");
                    } else if (l.startsWith("Mic:")) {
                        root.micMuted = l.includes("MUTED");
                    } else if (l.endsWith("%")) {
                        root.brightness = parseInt(l) || 0;
                    }
                }
            }
        }
    }

    Process { id: act; running: false }

    Timer {
        running: true
        interval: 2000
        repeat: true
        onTriggered: root.refresh()
    }
}
