import QtQuick

import "root:/Services"
import "root:/Widgets"

// The clock, and the battery, as cards you can place.
//
// Two things rather than two files: they are the same card — a figure
// and a caption — and the only difference is what draws the figure.
// Splitting them would mean two copies of the same sizing arithmetic,
// and the sizing is the part that has to survive being dragged to a
// different shape.

Item {
    id: root

    // "clock" | "battery"
    property string kind: "clock"

    // See ConnRow: the words are optional, per control. For the clock
    // that is the date beside the time; for the battery, the
    // percentage beside the ring, which the ring already says.
    property bool showText: true

    readonly property bool roomy: showText && width > height * 1.5

    Surface { anchors.fill: parent }

    // ── Clock ────────────────────────────────────────────────

    Row {
        anchors.centerIn: parent
        visible: root.kind === "clock"
        spacing: 8

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            text: Clock.time
            color: Theme.primary
            font.family: Theme.fontMono
            font.pixelSize: Math.min(
                Theme.fontSizeTitle,
                Math.round(root.height * 0.46))
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }

        Text {
            // On the time's baseline rather than centred on it, so the
            // pair reads as one line.
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            visible: root.roomy
            text: Clock.date
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            renderType: Text.NativeRendering
        }
    }

    // ── Battery ──────────────────────────────────────────────

    Row {
        anchors.centerIn: parent
        visible: root.kind === "battery"
        spacing: 9

        BatteryRing {
            id: ring
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(32, root.height - 14)
            height: width

            level: Battery.level
            charging: Battery.charging
            low: Battery.low
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.roomy
            spacing: 0

            Text {
                text: Battery.present ? Battery.level + "%" : "—"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }

            Text {
                text: Battery.charging ? "Charging" : "Battery"
                color: Theme.textDim
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }
    }
}
