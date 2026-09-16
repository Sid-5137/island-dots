import QtQuick

import "root:/Services"
import "root:/Widgets"

// Workspaces, left of the island.
//
// At rest they are dashes: one long one for where you are, a short one
// for every workspace holding windows, a stub for the empty ones. That
// is the whole answer to "where am I" at a glance, in about forty
// pixels.
//
// Open — hovered, pinned, or for a moment after a switch — the dashes
// become numbered chips you can aim at. Same information, addressable.

Pod {
    id: root

    side: "left"
    present: Config.island.showWorkspaces && Wm.workspaces.length > 0

    readonly property int pad: 16

    restWidth: dashes.implicitWidth + pad
    openWidth: chips.implicitWidth + pad

    // A switch you made yourself is worth confirming — the chip for
    // the workspace you landed on is legible in a way a dash is not.
    Connections {
        target: Wm
        function onActiveIdChanged() { root.peek() }
    }

    // The pod answers the same gesture the pill does, which is the one
    // you would try first with the cursor already over the dashes.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) { root.win.scrollWorkspace(event.angleDelta.y) }
    }

    // ── Rest: dashes ─────────────────────────────────────────

    Row {
        id: dashes
        anchors.centerIn: parent
        spacing: 4

        opacity: root.open ? 0 : 1
        visible: opacity > 0.01
        // Both layers overlap while they cross-fade, so the one on its
        // way out stops taking clicks well before it stops being
        // visible.
        enabled: opacity > 0.5

        Behavior on opacity { ContentFade { revealing: !root.open } }

        Repeater {
            model: Wm.workspaces

            Rectangle {
                required property var modelData
                readonly property bool active: modelData.id === Wm.activeId

                anchors.verticalCenter: parent.verticalCenter
                width: active ? 16 : (modelData.windows > 0 ? 7 : 4)
                height: 3
                radius: 1.5
                color: active
                    ? Theme.primary
                    : (modelData.windows > 0 ? Theme.textDim : Theme.outline)

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 200 } }

                // A 3px target is not a target. The margin makes the
                // whole band clickable without changing the shape.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.switchTo(modelData.id)
                }
            }
        }
    }

    // ── Open: numbered chips ─────────────────────────────────

    Row {
        id: chips
        anchors.centerIn: parent
        spacing: 5

        opacity: root.open ? 1 : 0
        visible: opacity > 0.01
        enabled: opacity > 0.5

        Behavior on opacity { ContentFade { revealing: root.open } }

        Repeater {
            model: Wm.workspaces

            Rectangle {
                required property var modelData
                readonly property bool active: modelData.id === Wm.activeId

                anchors.verticalCenter: parent.verticalCenter
                width: active ? 24 : 18
                height: 18
                radius: 5
                color: active
                    ? Theme.primary
                    : (modelData.windows > 0
                       ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                border.width: modelData.windows > 0 || active ? 0 : 1
                border.color: Theme.outline

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: parent.active ? Theme.textOnPrimary : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Config.island.fontSize - 3
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.switchTo(modelData.id)
                }
            }
        }
    }
}
