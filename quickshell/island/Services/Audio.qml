pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Volume through PipeWire directly rather than by spawning wpctl.
// A process spawn per step caps the rate at roughly one every 20ms,
// which is what made gesture control feel coarse. Setting the node
// property is immediate.
//
// Backlight still shells out: there is no equivalent binding, and
// brightness changes are far less frequent.

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property int volume:
        (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted:
        (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool micMuted:
        (source && source.audio) ? source.audio.muted : false

    property int brightness: 0

    readonly property string volumeIcon:
        muted ? "\uf6a9"
        : volume > 66 ? "\uf028"
        : volume > 33 ? "\uf027"
        : "\uf026"

    readonly property string micIcon: micMuted ? "\uf131" : "\uf130"
    readonly property string brightnessIcon: "\uf185"

    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = Math.max(0, Math.min(100, v)) / 100;
    }

    function stepVolume(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source && source.audio) source.audio.muted = !source.audio.muted;
    }

    function setBrightness(v) {
        const b = Math.max(0, Math.min(100, Math.round(v)));
        brightness = b;
        Quickshell.execDetached(
            ["brightnessctl", "--class=backlight", "set", b + "%"]);
    }

    function stepBrightness(delta) {
        setBrightness(brightness + delta);
    }

    function refresh() { poll.running = true }

    // Binding the nodes is what makes their audio properties readable
    // and writable; without it they report defaults.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Only the backlight needs polling now — PipeWire pushes volume.
    Process {
        id: poll
        running: true
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4"]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.endsWith("%")) root.brightness = parseInt(t) || 0;
            }
        }
    }

    Timer {
        running: true
        interval: 5000
        repeat: true
        onTriggered: root.refresh()
    }
}
