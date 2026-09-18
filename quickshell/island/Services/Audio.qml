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

    // sink.audio.volume is on the displayed scale wpctl and pactl
    // use (the cube root of PipeWire's linear gain), so the number
    // here matches every other tool exactly.
    //
    // That is also why 50% does not sound half as loud: loudness goes
    // as p^1.8, so 50% is -18 dB. "perceptual" maps s = p^(5/9)
    // instead, which makes loudness track the number. Off by default —
    // disagreeing with wpctl should be a deliberate choice.
    readonly property bool perceptual:
        Config.audio.volumeCurve === "perceptual"

    // 5/9 in one direction, 9/5 in the other.
    readonly property real exponent: 5 / 9

    function toDisplay(s) {
        const v = Math.max(0, Math.min(1, s));
        return root.perceptual ? Math.pow(v, 1 / root.exponent) : v;
    }

    function toSystem(p) {
        const v = Math.max(0, Math.min(1, p));
        return root.perceptual ? Math.pow(v, root.exponent) : v;
    }

    readonly property int volume:
        (sink && sink.audio) ? Math.round(toDisplay(sink.audio.volume) * 100) : 0

    // What PipeWire itself holds, on its own scale. Only the status
    // handler at the bottom reads it: everything else in the shell
    // works in the percentage above.
    readonly property int systemVolume:
        (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0

    readonly property bool muted:
        (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool micMuted:
        (source && source.audio) ? source.audio.muted : false

    property int brightness: 0

    // Muted was U+F6A9, a Material glyph Nerd Fonts v3 moved out from
    // under it — so the one state you most need to see was the one
    // that drew nothing at all. See Services/Icons.qml; the whole ramp
    // is one font family now, which is why that could not happen to
    // the other three.
    readonly property string volumeIcon:
        muted ? Icons.volumeMuted
        : volume > 66 ? Icons.volumeHigh
        : volume > 33 ? Icons.volumeMedium
        : Icons.volumeLow

    readonly property string micIcon: micMuted ? Icons.micOff : Icons.micOn
    readonly property string brightnessIcon: Icons.brightness

    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = toSystem(Math.max(0, Math.min(100, v)) / 100);
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

    // Somewhere to send it.
    //
    // The sliders in the control centre move the default sink, which
    // is the right answer right up until the moment headphones are
    // plugged in and the question becomes "which one". Listing them is
    // nearly free — PipeWire is already bound for the volume — so the
    // Sound page behind the slider's chevron is a list of these rather
    // than a button that opens a settings window.
    readonly property var sinks: {
        const out = [];
        for (const node of Pipewire.nodes.values) {
            if (!node || !node.isSink || node.isStream) continue;
            out.push(node);
        }
        return out;
    }

    function sinkName(node) {
        if (!node) return "";
        // description is the human one ("Built-in Audio Analog
        // Stereo"); name is the id ("alsa_output.pci-0000_00..."),
        // which is not something to show anybody.
        return node.description || node.nickname || node.name || "";
    }

    // What every output on this machine is called, which is therefore
    // the part that distinguishes none of them.
    //
    // One controller with four ports gives four descriptions reading
    // "500 Series Chipset Family On-Package High Definition Audio (HD
    // Audio) Speaker" and the same again with HDMI 1, 2 and 3 — sixty
    // identical characters, and then the only word that matters,
    // somewhere off the right-hand edge of any list narrow enough to
    // sit in a panel. So the shared head is measured and dropped.
    readonly property string sinkPrefix: {
        const names = sinks.map(sinkName).filter(n => n !== "");
        if (names.length < 2) return "";

        let end = 0;
        while (end < names[0].length
               && names.every(n => n[end] === names[0][end]))
            end++;

        // Back off to a word boundary, or "HDMI / DisplayPort 1" and
        // "HDMI / DisplayPort 2" would come back as "1" and "2".
        const head = names[0].slice(0, end);
        const cut = head.lastIndexOf(" ");
        return cut > 0 ? head.slice(0, cut + 1) : "";
    }

    function sinkLabel(node) {
        const full = sinkName(node);
        return sinkPrefix !== "" && full.startsWith(sinkPrefix)
            ? full.slice(sinkPrefix.length) : full;
    }

    function setSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
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

    // The outputs get their own tracker rather than being concatenated
    // into the one above. An untracked node reports no description, so
    // the Sound page would list the right number of outputs under the
    // wrong labels — but binding the default sink's tracker to a list
    // derived from Pipewire.nodes puts tracking on both sides of the
    // same binding, and Qt resolves that by dropping it. The symptom
    // is not a warning: it is the volume reading zero forever, because
    // the default sink quietly stopped being bound.
    PwObjectTracker {
        objects: root.sinks
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

    // Every other service here can be asked what it thinks is true.
    // This one could not, which is why working out whether a slider
    // reading zero was the slider's fault or PipeWire's took four
    // screenshots rather than one command.
    IpcHandler {
        target: "audio"

        function status(): string {
            // Both scales, because the whole point of the curve
            // setting is that they can differ, and "the slider says
            // 50 and wpctl says 0.68" is exactly the question this
            // handler exists to answer without four screenshots.
            return "volume=" + root.volume
                + " curve=" + Config.audio.volumeCurve
                + " system=" + root.systemVolume
                + " muted=" + root.muted
                + " mic=" + (root.micMuted ? "muted" : "live")
                + " brightness=" + root.brightness
                + " sink='" + root.sinkName(root.sink) + "'";
        }

        function outputs(): string {
            return root.sinks.map(n =>
                (n === root.sink ? "* " : "  ") + root.sinkName(n)).join("\n");
        }
    }
}
