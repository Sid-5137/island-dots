import Quickshell
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Workspaces, left of the island.
//
// At rest it answers one question in about forty pixels: where am I,
// and which others hold anything. Four styles say that differently —
// dashes, dots, numbers, or the icon of what is running there.
//
// Open — hovered, pinned, or briefly after a switch — every style
// becomes the same numbered chips you can aim at.

Pod {
    id: root

    side: "left"
    present: Config.island.showWorkspaces && Wm.workspaces.length > 0

    readonly property int pad: 16
    readonly property string style: Config.island.workspaceStyle

    // Only the row the style asks for holds any delegates; the other
    // two are given an empty model, so the icon style resolves no
    // icons while the dashes are the ones on screen.
    readonly property Item restRow: style === "numbers" ? numbers
                                  : style === "icons" ? icons
                                  : shapes

    restWidth: restRow.implicitWidth + pad
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

    // ── Rest ─────────────────────────────────────────────────
    //
    // One fade for all three rows rather than one each: they are the
    // same layer wearing different clothes, and only ever one of them
    // has anything in it.

    Item {
        id: rest
        anchors.fill: parent

        opacity: root.open ? 0 : 1
        visible: opacity > 0.01
        // Both layers overlap while they cross-fade, so the one on its
        // way out stops taking clicks well before it stops being
        // visible.
        enabled: opacity > 0.5

        Behavior on opacity { ContentFade { revealing: !root.open } }

        // Dashes and dots. One delegate, because the difference
        // between them is whether the shape is allowed to stretch.
        Row {
            id: shapes
            anchors.centerIn: parent
            spacing: root.style === "dots" ? 5 : 4

            Repeater {
                model: root.style === "dashes" || root.style === "dots"
                    ? Wm.workspaces : []

                Rectangle {
                    required property var modelData
                    readonly property bool active: modelData.id === Wm.activeId
                    readonly property bool busy: modelData.windows > 0
                    readonly property bool round: root.style === "dots"

                    anchors.verticalCenter: parent.verticalCenter
                    // A dash says where you are by growing sideways. A
                    // dot cannot do that without becoming a dash, so it
                    // says it by being the largest of three circles.
                    width: round ? (active ? 9 : busy ? 6 : 4)
                                 : (active ? 16 : busy ? 7 : 4)
                    height: round ? width : 3
                    radius: height / 2
                    color: active ? Theme.primary
                         : busy ? Theme.textDim : Theme.outline

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    // A 3px target is not a target. The margin makes
                    // the whole band clickable without changing the
                    // shape.
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wm.switchTo(modelData.id)
                    }
                }
            }
        }

        // The numbers, unboxed. The chips the pod opens into are the
        // same numbers in a shape you can aim at, so this style is the
        // one where opening the pod tells you nothing new — which is
        // the point of it.
        Row {
            id: numbers
            anchors.centerIn: parent
            spacing: 7

            Repeater {
                model: root.style === "numbers" ? Wm.workspaces : []

                Text {
                    required property var modelData
                    readonly property bool active: modelData.id === Wm.activeId
                    readonly property bool busy: modelData.windows > 0

                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.id
                    color: active ? Theme.primary
                         : busy ? Theme.textDim : Theme.outline
                    font.family: Theme.fontMono
                    font.pixelSize: Config.island.fontSize - 2
                    font.weight: active ? Font.Bold : Font.DemiBold
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wm.switchTo(modelData.id)
                    }
                }
            }
        }

        // What is running over there. The icon is the window you were
        // last in on that workspace, which is the one you mean when you
        // think of it as "the browser one".
        Row {
            id: icons
            anchors.centerIn: parent
            spacing: 7

            Repeater {
                model: root.style === "icons" ? Wm.workspaces : []

                Item {
                    required property var modelData
                    readonly property bool active: modelData.id === Wm.activeId
                    readonly property bool busy: modelData.windows > 0

                    anchors.verticalCenter: parent.verticalCenter
                    // Tall enough for the icon and the mark under it.
                    width: busy ? 16 : 6
                    height: 20

                    IconImage {
                        id: art
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        visible: parent.busy
                        implicitSize: 15
                        source: Quickshell.iconPath(
                            Wm.classFor(parent.modelData.id).toLowerCase(),
                            "application-x-executable")
                        // The rest are there to be recognised, not
                        // read.
                        opacity: parent.active ? 1 : 0.5

                        Behavior on opacity {
                            NumberAnimation { duration: Motion.fadeIn }
                        }
                    }

                    // An empty workspace has no icon to show, and a
                    // gap where one would be reads as an icon that
                    // failed to load rather than as an empty desk.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (art.implicitSize - height) / 2
                        visible: !parent.busy
                        width: 4; height: 4; radius: height / 2
                        color: Theme.outline
                    }

                    // Where you are, under the icon: opacity alone is
                    // not a mark when every icon is already a
                    // different colour and brightness to begin with.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        visible: parent.active
                        width: parent.busy ? 10 : 4
                        height: 2
                        radius: height / 2
                        color: Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wm.switchTo(modelData.id)
                    }
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
                radius: Theme.radiusSmall
                color: active
                    ? Theme.primary
                    : (modelData.windows > 0
                       ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                border.width: modelData.windows > 0 || active ? 0 : 1
                border.color: Theme.outline

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

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
