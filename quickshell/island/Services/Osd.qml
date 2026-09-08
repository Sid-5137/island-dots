pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Transient readout for volume, brightness and mic.
//
// Driven by the media keys rather than by polling: Audio refreshes on
// a 2s timer, which is far too slow to feel like feedback. The keys
// call in here, which applies the change and shows the bar in one go.

Singleton {
    id: root

    property string kind: ""        // "" | volume | brightness | mic
    property int value: 0
    property bool muted: false

    signal shown()

    readonly property bool active: kind !== ""

    readonly property string icon: {
        if (kind === "brightness") return Audio.brightnessIcon;
        if (kind === "mic") return Audio.micIcon;
        return Audio.volumeIcon;
    }

    readonly property string label: {
        if (kind === "brightness") return "Brightness";
        if (kind === "mic") return muted ? "Mic muted" : "Mic live";
        return muted ? "Muted" : "Volume";
    }

    function show(k, v, m) {
        kind = k;
        value = v;
        muted = m === true;
        shown();
        hideTimer.restart();
    }

    function hide() {
        kind = "";
        hideTimer.stop();
    }

    Timer {
        id: hideTimer
        interval: Config.island.osdDuration
        onTriggered: root.kind = ""
    }

    IpcHandler {
        target: "osd"

        function volumeUp(): void {
            const v = Math.min(100, Audio.volume + Config.island.osdStep);
            Audio.setVolume(v);
            root.show("volume", v, false);
        }

        function volumeDown(): void {
            const v = Math.max(0, Audio.volume - Config.island.osdStep);
            Audio.setVolume(v);
            root.show("volume", v, false);
        }

        function volumeMute(): void {
            Audio.toggleMute();
            root.show("volume", Audio.volume, Audio.muted);
        }

        function micMute(): void {
            Audio.toggleMic();
            root.show("mic", 0, Audio.micMuted);
        }

        function brightnessUp(): void {
            const v = Math.min(100, Audio.brightness + Config.island.osdStep);
            Audio.setBrightness(v);
            root.show("brightness", v, false);
        }

        function brightnessDown(): void {
            const v = Math.max(0, Audio.brightness - Config.island.osdStep);
            Audio.setBrightness(v);
            root.show("brightness", v, false);
        }
    }
}
