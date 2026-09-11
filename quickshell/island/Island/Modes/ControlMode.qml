import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
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
    anchors.margins: 26
    // The strip's band plus the content margin. Reserving only the
    // band left the content box taller than its cards, and that slack
    // stacked on top of the strip's own gap — which is why the strip
    // sat so far below everything else.
    // The band plus the content margin, so the content box is the same
    // height whether or not the strip is present — otherwise the cards
    // gain slack below them exactly when the strip appears.
    anchors.bottomMargin: island.media
        ? Config.island.mediaStripHeight + 26 : 26

    opacity: (island.isControl
              && pill.width > Config.island.controlWidth * 0.97) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    // Closes the panel. The clock line has no interactive content of
    // its own, so it can carry this without stealing anything.
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.leftCardWidth - 60
        height: 52
        cursorShape: Qt.PointingHandCursor
        onClicked: win.closeControl()
    }

    Row {
        id: bigClock
        anchors.left: parent.left
        anchors.leftMargin: root.cardPad
        anchors.top: parent.top
        // The card has no padding of its own, so its contents provide
        // it. Without this the clock sits on the card's top edge and
        // the battery ring, being taller than the clock line, spills
        // out above it.
        anchors.topMargin: root.cardPad
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
        anchors.leftMargin: root.cardPad + calendar.width - width
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
        anchors.leftMargin: root.cardPad
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

    // Four cards with real gaps between them, each its own surface.
    // The pill behind is transparent in this mode, so nothing joins
    // them into one panel.
    //
    // Drawn at z: -1 so every control above keeps its own clicks.
    // A 7% white wash is below the layer rule's ignore_alpha, so the
    // compositor skipped these entirely and nothing behind them was
    // blurred. Painting them as a real translucent surface — the same
    // alpha the pill uses — gives the blur something to work on.
    // Every card dimension is computed from configuration, not from
    // measured content. Sizing a card from its children while the
    // children size from the card takes two layout passes: the first
    // runs against a zero-width card, which is the flicker you see on
    // open.
    readonly property int calWidth: 266
    readonly property int cardGap: 10
    readonly property int cardPad: 16
    readonly property int leftCardWidth: calWidth + cardPad * 2
    readonly property int rightCardWidth:
        width - leftCardWidth - cardGap

    readonly property int tileCell:
        Math.floor((rightCardWidth - 28 - 24) / 3)
    readonly property int tilesCardHeight: tileCell * 2 + 12 + 28

    // Two 38px slider rows and the gap between them, plus the tray
    // when it is present, inside 14px of padding.
    readonly property int controlsCardHeight: 14 + (38 * 2 + 12) + 14

    readonly property int eventRows:
        Calendar.available ? Math.min(Calendar.today.length, 3) : 0
    readonly property int eventsHeight: eventRows * 20 + 20

    // header + gap + weekday row + gap + six rows of cells
    // Sized to the month on screen rather than to the worst case.
    // From the grid's own numbers rather than a service call. Those
    // are already correct — the day cells render from them — whereas
    // a function taking a date fails to zero if the date is undefined
    // on the frame it is first read, which collapses the card and
    // leaves the dates drawing outside it.
    readonly property int calendarRows:
        Math.ceil((calendar.firstWeekday + calendar.daysInMonth) / 7)
    readonly property int calendarHeight: 30 + 6 + 17 + 4 + calendarRows * 32

    function surface(alpha) {
        const c = Qt.color(Theme.surfaceContainer);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    component Card: Rectangle {
        radius: Config.appearance.panelRadius
        color: root.surface(Config.island.opacity)
        // Faint enough to read as an edge rather than a frame — at the
        // fill's own contrast the modules start looking like separate
        // windows instead of groups on one surface.
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: -1
    }

    Card {
        id: calendarCard
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.leftCardWidth
        // Clock line, gap, then the calendar's own fixed height.
        height: root.cardPad + 52 + 16 + root.calendarHeight + root.cardPad
    }

    Card {
        id: eventsCard
        anchors.left: calendarCard.left
        anchors.top: calendarCard.bottom
        anchors.topMargin: 10
        width: calendarCard.width
        height: root.eventsHeight
        visible: root.eventRows > 0
    }

    Card {
        id: tilesCard
        anchors.left: calendarCard.right
        anchors.leftMargin: root.cardGap
        anchors.top: parent.top
        width: root.rightCardWidth
        height: root.tilesCardHeight
    }

    Card {
        id: controlsCard
        anchors.left: tilesCard.left
        anchors.right: tilesCard.right
        anchors.top: tilesCard.bottom
        anchors.topMargin: root.cardGap
        // Sized to its content rather than stretched to the panel
        // floor. Filling the height left two sliders sitting at the
        // top of a mostly empty card; the right column simply ends
        // higher than the calendar, which is fine.
        height: root.controlsCardHeight
    }

    Grid {
        id: tiles
        anchors.horizontalCenter: tilesCard.horizontalCenter
        anchors.top: tilesCard.top
        anchors.topMargin: 14
        columns: 3
        spacing: 12

        // Derived from the card, not the panel, so the grid fills its
        // own surface with equal margins either side.
        readonly property int columnWidth: root.rightCardWidth - 28

        readonly property int cell: root.tileCell

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

    // Today's events, under the calendar. Absent entirely when khal
    // is not installed, rather than showing an empty list.
    Column {
        id: events
        anchors.left: parent.left
        anchors.leftMargin: root.cardPad
        anchors.top: calendar.bottom
        anchors.topMargin: 22
        width: calendar.width
        spacing: 4
        visible: root.eventRows > 0

        Repeater {
            model: Calendar.today.slice(0, 3)

            Row {
                required property var modelData
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 12
                    radius: 1.5
                    color: Theme.primary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    text: modelData.allDay ? "all day" : modelData.time
                    color: Theme.outline
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall - 2
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: calendar.width - 60
                    text: modelData.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Column {
        id: sliders
        anchors.horizontalCenter: controlsCard.horizontalCenter
        anchors.top: controlsCard.top
        anchors.topMargin: 14
        width: controlsCard.width - 28
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
