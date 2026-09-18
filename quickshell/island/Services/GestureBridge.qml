pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// A socket the gesture daemon writes deltas to. One socket held open
// rather than a `qs ipc call` per step (~20ms each), so a swipe can
// adjust on every frame the touchpad reports.
//
// One line per event:
//
//     v <delta>    volume, percent
//     b <delta>    brightness, percent
//     m            toggle mute
//     M            toggle mic

Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/island-gestures.sock"

    SocketServer {
        active: true
        path: root.path

        handler: Socket {
            parser: SplitParser {
                onRead: function(line) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length === 0) return;

                    switch (parts[0]) {
                        case "v": {
                            const d = parseInt(parts[1]) || 0;
                            Audio.stepVolume(d);
                            Osd.show("volume", Audio.volume, Audio.muted);
                            break;
                        }
                        case "b": {
                            const d = parseInt(parts[1]) || 0;
                            Audio.stepBrightness(d);
                            Osd.show("brightness", Audio.brightness, false);
                            break;
                        }
                        case "m":
                            Audio.toggleMute();
                            Osd.show("volume", Audio.volume, Audio.muted);
                            break;
                        case "M":
                            Audio.toggleMic();
                            Osd.show("mic", 0, Audio.micMuted);
                            break;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "gestures"
        function socket(): string { return root.path }
    }
}
