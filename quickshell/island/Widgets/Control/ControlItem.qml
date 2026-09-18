import QtQuick

import "root:/Services"

// One control, chosen by key.
//
// The panel and the layout editor draw from this same file, so the
// editor shows the thing itself rather than a sketch that can drift.
//
// `live` is the only difference: in the editor the controls are drawn
// but inert, so a click starts a drag rather than turning Wi-Fi off.

Item {
    id: root

    required property string itemKey
    property bool live: true

    // Whether this control shows its words. Held by the layout rather
    // than by the delegate, so the answer survives a restart and can
    // be different for two cards of the same kind.
    property bool labels: true

    readonly property var spec: ControlLayout.spec(itemKey)

    // Everything a control wants to happen elsewhere goes out as one
    // signal, and the panel decides what it means. Some of these open
    // a sub-page inside the panel ("wifi"), some close the panel and
    // open a window ("settings"). A card should not have to know
    // which — it knows what was clicked, not what the shell does
    // about it.
    signal openPage(string name)

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (!root.spec) return null;
            switch (root.spec.kind) {
                case "conn":    return connCard;
                case "level":   return levelCard;
                case "media":   return mediaCard;
                case "month":   return monthCard;
                case "notes":   return notesCard;
                case "clock":   return statCard;
                case "battery": return statCard;
                default:        return toggleCard;
            }
        }
    }

    // ── Connectivity ─────────────────────────────────────────

    Component {
        id: connCard

        ConnRow {
            readonly property bool isWifi: root.itemKey === "wifi"

            showText: root.labels

            glyph: isWifi ? Network.icon : Bluetooth.icon
            name: isWifi ? "Wi-Fi" : "Bluetooth"
            sub: isWifi ? Network.label : Bluetooth.label
            on: isWifi ? Network.wifiEnabled : Bluetooth.powered
            busy: isWifi ? Network.scanning : Bluetooth.scanning

            onToggled: {
                if (!root.live) return;
                if (isWifi) Network.toggle();
                else Bluetooth.toggle();
            }

            onOpened: {
                if (!root.live) return;
                root.openPage(root.itemKey);
            }
        }
    }

    // ── Levels ───────────────────────────────────────────────

    Component {
        id: levelCard

        LevelSlider {
            readonly property bool isSound: root.itemKey === "sound"

            showText: root.labels

            label: isSound ? "Sound" : "Display"
            glyph: isSound ? Audio.volumeIcon : Audio.brightnessIcon
            value: isSound ? Audio.volume : Audio.brightness
            dimmed: isSound && Audio.muted

            // Sound has outputs to choose between. Brightness has one
            // backlight and nothing to say about it, so it gets no
            // chevron rather than a chevron that opens an apology.
            hasPage: isSound

            onMoved: function(v) {
                if (!root.live) return;
                if (isSound) Audio.setVolume(v);
                else Audio.setBrightness(v);
            }

            onToggled: {
                if (!root.live) return;
                // Brightness has nothing to mute, so the glyph there
                // is the way into the sub-page rather than a dead
                // target that looks like the volume one.
                if (isSound) Audio.toggleMute();
                else root.openPage("display");
            }

            onOpened: {
                if (!root.live) return;
                root.openPage(isSound ? "sound" : "display");
            }
        }
    }

    // ── The rest ─────────────────────────────────────────────

    Component {
        id: mediaCard

        MediaCard {
            showText: root.labels

            onOpened: {
                if (!root.live) return;
                Player.toggle();
            }
        }
    }

    Component {
        id: monthCard
        MonthCard {}
    }

    Component {
        id: notesCard

        NotesCard {
            onOpened: {
                if (!root.live) return;
                root.openPage("notifications");
            }
        }
    }

    Component {
        id: statCard
        StatCard {
            kind: root.itemKey
            showText: root.labels
        }
    }

    Component {
        id: toggleCard

        ToggleCard {
            showText: root.labels

            glyph: {
                switch (root.itemKey) {
                    case "mic":      return Audio.micIcon;
                    case "dnd":      return Config.island.dnd
                        ? "" : "";
                    case "caffeine": return "";
                    case "lock":     return "";
                    default:         return "";
                }
            }

            name: root.spec ? root.spec.name : ""

            sub: {
                switch (root.itemKey) {
                    case "mic":      return Audio.micMuted ? "Muted" : "Live";
                    case "dnd":      return Config.island.dnd ? "On" : "Off";
                    case "caffeine": return Config.island.caffeine ? "On" : "Off";
                    case "lock":     return "Lock now";
                    default:         return "Open";
                }
            }

            on: {
                switch (root.itemKey) {
                    case "mic":      return !Audio.micMuted;
                    case "dnd":      return Config.island.dnd;
                    case "caffeine": return Config.island.caffeine;
                    default:         return false;
                }
            }

            onTriggered: {
                if (!root.live) return;
                switch (root.itemKey) {
                    case "mic":
                        Audio.toggleMic();
                        break;
                    case "dnd":
                        Config.island.dnd = !Config.island.dnd;
                        break;
                    case "caffeine":
                        Config.island.caffeine = !Config.island.caffeine;
                        break;
                    case "lock":
                        root.openPage("lock");
                        break;
                    default:
                        root.openPage("settings");
                }
            }
        }
    }
}
