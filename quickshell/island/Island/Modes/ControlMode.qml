import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Control centre: clock, battery, calendar, quick toggles and
// sliders. This is what "expanded" means.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent
    anchors.margins: 18
    anchors.bottomMargin: island.media
        ? Config.island.mediaStripHeight + 2 : 18

    opacity: (island.isControl
              && pill.width > Config.island.controlWidth * 0.8) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    Row {
        id: bigClock
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 10
        width: 266

        Text {
            id: clockTime
            anchors.bottom: parent.bottom
            text: Clock.time
            color: Theme.primary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
            renderType: Text.NativeRendering
        }

        Text {
            // Sits on the time's baseline rather than
            // centred, so the pair reads as one line.
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            text: Clock.date
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }
    }

    BatteryRing {
        id: batteryRing
        visible: Battery.present

        anchors.left: parent.left
        anchors.leftMargin: calendar.width - width
        anchors.verticalCenter: bigClock.verticalCenter

        // Sized to the clock line rather than standing
        // above it — it's a status glance, not a
        // headline.
        width: 38
        height: 38

        level: Battery.level
        charging: Battery.charging
        low: Battery.low

    }

    Item {
        id: calendar
        anchors.left: parent.left
        anchors.top: bigClock.bottom
        anchors.topMargin: 16
        height: calHeader.height + 6 + weekdays.height + 4 + dayGrid.height
        width: 266

        property int monthOffset: 0
        property var shown: {
            const d = new Date(Clock.now);
            d.setDate(1);
            d.setMonth(d.getMonth() + monthOffset);
            return d;
        }
        readonly property int daysInMonth:
            new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
        // Monday-first, so shift Sunday from 0 to 6.
        readonly property int firstWeekday:
            (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7

        Item {
            id: calHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(calendar.shown, "MMMM yyyy")
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.letterSpacing: 0.8
                renderType: Text.NativeRendering
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [{ g: "\u2039", d: -1 }, { g: "\u203a", d: 1 }]
                    Rectangle {
                        required property var modelData
                        width: 24; height: 24; radius: 6
                        color: navHover.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.g
                            color: Theme.textDim
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: navHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendar.monthOffset += modelData.d
                        }
                    }
                }
            }
        }

        Row {
            id: weekdays
            anchors.top: calHeader.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            spacing: 0

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Text {
                    required property var modelData
                    width: 38
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }
            }
        }

        Grid {
            id: dayGrid
            anchors.top: weekdays.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            columns: 7
            spacing: 0

            Repeater {
                model: calendar.firstWeekday + calendar.daysInMonth

                Item {
                    required property int index
                    readonly property int day: index - calendar.firstWeekday + 1
                    readonly property bool isToday:
                        calendar.monthOffset === 0
                        && day === Clock.now.getDate()

                    width: 38
                    height: 32
                    visible: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 8
                        color: parent.isToday ? Theme.primary : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.day > 0
                        text: parent.day
                        color: parent.isToday ? Theme.textOnPrimary : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.left: calendar.right
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        width: 1
        color: Theme.outlineVariant
    }

    Grid {
        id: tiles
        anchors.left: calendar.right
        anchors.leftMargin: 36
        anchors.top: parent.top
        columns: 3
        spacing: 12

        readonly property int columnWidth:
            root.width - calendar.width - 36

        readonly property int cell:
            Math.floor((columnWidth - spacing * (columns - 1)) / columns)

        width: columnWidth

        Repeater {
            model: [
                { key: "wifi",     label: "Wi-Fi" },
                { key: "bt",       label: "Bluetooth" },
                { key: "mic",      label: "Mic" },
                { key: "dnd",      label: "Focus" },
                { key: "caffeine", label: "Awake" },
                { key: "settings", label: "Settings" }
            ]

            Tile {
                required property var modelData

                width: tiles.cell
                height: tiles.cell

                label: modelData.label
                hasSecondary: modelData.key === "wifi" || modelData.key === "bt"

                active: {
                    switch (modelData.key) {
                        case "wifi":     return Network.wifiEnabled;
                        case "bt":       return Bluetooth.powered;
                        case "mic":      return !Audio.micMuted;
                        case "dnd":      return Config.island.dnd;
                        case "caffeine": return Config.island.caffeine;
                        default:         return false;
                    }
                }

                glyph: {
                    switch (modelData.key) {
                        case "wifi":     return Network.icon;
                        case "bt":       return Bluetooth.icon;
                        case "mic":      return Audio.micIcon;
                        case "dnd":      return Config.island.dnd ? "\uf1f6" : "\uf0f3";
                        case "notif":    return Notifications.count > 0 ? "\uf0f3" : "\uf1f6";
                        case "caffeine": return "\uf0f4";
                        default:         return "\uf013";
                    }
                }

                sub: {
                    switch (modelData.key) {
                        case "wifi": return Network.label;
                        case "bt":   return Bluetooth.label;
                        case "mic":  return Audio.micMuted ? "Muted" : "Live";
                        case "dnd":  return Config.island.dnd ? "On" : "Off";
                        case "caffeine": return Config.island.caffeine ? "On" : "Off";
                        default:     return "Open";
                    }
                }

                onTriggered: {
                    switch (modelData.key) {
                        case "wifi":     Network.toggle(); break;
                        case "bt":       Bluetooth.toggle(); break;
                        case "mic":      Audio.toggleMic(); break;
                        case "dnd":      Config.island.dnd = !Config.island.dnd; break;
                        case "caffeine": Config.island.caffeine = !Config.island.caffeine; break;
                        default:
                            win.closeControl();
                            win.openSettings("island");
                    }
                }

                onSecondary: {
                    win.closeControl();
                    win.openSettings("network");
                }

            }
        }
    }

    Column {
        id: sliders
        anchors.left: calendar.right
        anchors.leftMargin: 36
        anchors.top: tiles.bottom
        anchors.topMargin: 22
        width: tiles.columnWidth
        spacing: 12

        Repeater {
            model: [{ key: "vol" }, { key: "bright" }]

            Item {
                required property var modelData
                readonly property bool isVol: modelData.key === "vol"
                readonly property int value:
                    isVol ? Audio.volume : Audio.brightness

                width: parent.width
                height: 38

                Text {
                    id: sIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    text: parent.isVol ? Audio.volumeIcon : Audio.brightnessIcon
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 17

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        enabled: parent.parent.isVol
                        onClicked: Audio.toggleMute()
                    }
                }

                Item {
                    id: sTrack
                    anchors.left: sIcon.right
                    anchors.leftMargin: 10
                    anchors.right: sValue.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            width: Math.max(8, parent.width * (sTrack.parent.value / 100))
                            height: parent.height
                            radius: 4
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        id: knob
                        width: 14
                        height: 14
                        radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(sTrack.width - width,
                            (sTrack.parent.value / 100) * sTrack.width - width / 2))
                        color: Theme.primary
                        border.width: 2
                        border.color: Theme.surfaceContainer
                        opacity: sDrag.containsMouse || sDrag.pressed ? 1 : 0
                        scale: sDrag.pressed ? 1.2 : 1

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: sDrag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function apply(mx) {
                            const r = Math.max(0, Math.min(1, mx / sTrack.width));
                            const v = Math.round(r * 100);
                            if (sTrack.parent.isVol) Audio.setVolume(v);
                            else Audio.setBrightness(v);
                        }

                        onPressed: function(m) { apply(m.x) }
                        onPositionChanged: function(m) { if (pressed) apply(m.x) }
                        onWheel: function(w) {
                            const step = w.angleDelta.y > 0 ? 5 : -5;
                            const v = Math.max(0, Math.min(100, sTrack.parent.value + step));
                            if (sTrack.parent.isVol) Audio.setVolume(v);
                            else Audio.setBrightness(v);
                        }
                    }
                }

                Text {
                    id: sValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Three digits at most, so the label
                    // only needs room for "100" — the
                    // rest was dead space the track
                    // could have used.
                    width: 28
                    horizontalAlignment: Text.AlignRight
                    text: parent.value
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: island.isControl
        Keys.onEscapePressed: win.closeControl()
    }
}
