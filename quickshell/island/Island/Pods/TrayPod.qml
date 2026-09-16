import QtQuick

import "root:/Services"
import "root:/Widgets"

// The tray, right of the island.
//
// This is the pod the redesign is really for. The tray used to be a
// face you scrolled to, which meant the answer to "is it still
// running" cost a gesture and a wait — and the moment you looked away
// the pill forgot and went back to the clock. Now it is simply there,
// and it is there at a size that four icons do not turn into a bar.
//
// At rest it shows the first few icons, small and quiet, with a count
// for any it is holding back. Open, every icon is on screen at full
// size with room to aim at.

Pod {
    id: root

    side: "right"
    present: Config.island.showTray && Tray.count > 0

    readonly property int pad: 16
    readonly property int restMax: Math.max(1, Config.island.trayRestMax)
    readonly property int hiddenCount: Math.max(0, Tray.count - restMax)

    restWidth: restRow.implicitWidth + pad
    openWidth: openRow.implicitWidth + pad

    // Something arriving or leaving the tray is exactly the kind of
    // change worth a look, and an icon asking for attention is the
    // only thing here that is ever urgent.
    Connections {
        target: Tray
        function onCountChanged() { root.peek() }
        function onAnyAttentionChanged() { if (Tray.anyAttention) root.peek() }
    }

    // ── Rest: the first few, small ───────────────────────────

    Row {
        id: restRow
        anchors.centerIn: parent
        spacing: 7

        opacity: root.open ? 0 : 1
        visible: opacity > 0.01
        // Both layers overlap while they cross-fade, so the one on its
        // way out stops taking clicks well before it stops being
        // visible — otherwise a click during the fade could land on
        // either copy of the same icon.
        enabled: opacity > 0.5

        Behavior on opacity { ContentFade { revealing: !root.open } }

        Repeater {
            model: Tray.items

            TrayIcon {
                required property var modelData
                required property int index

                item: modelData
                win: root.win
                size: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: index < root.restMax
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hiddenCount > 0
            text: "+" + root.hiddenCount
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Config.island.fontSize - 3
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }

    // ── Open: all of them, bigger ────────────────────────────

    Row {
        id: openRow
        anchors.centerIn: parent
        spacing: 11

        opacity: root.open ? 1 : 0
        visible: opacity > 0.01
        enabled: opacity > 0.5

        Behavior on opacity { ContentFade { revealing: root.open } }

        Repeater {
            model: Tray.items

            TrayIcon {
                required property var modelData

                item: modelData
                win: root.win
                size: 18
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
