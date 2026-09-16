import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Alt+Tab. A row of app icons, most-recently-focused first, with the
// selected window named beneath. Commits when tabbing stops.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    readonly property bool shown: island.isSwitcher

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Text {
        anchors.centerIn: parent
        visible: win.switchList.length === 0
        text: "No windows"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 8

        Repeater {
            model: win.switchList

            Rectangle {
                id: tile
                required property var modelData
                required property int index

                readonly property bool active: index === win.switchIndex

                width: Config.island.switcherTile
                height: Config.island.switcherTile
                radius: 14
                color: active ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                border.width: 1
                border.color: active ? Theme.primary : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.round(Config.island.switcherTile * 0.56)
                    source: Quickshell.iconPath(tile.modelData.cls.toLowerCase(),
                                                "application-x-executable")
                    opacity: tile.active ? 1 : 0.6

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    width: 16
                    height: 16
                    radius: 5
                    color: tile.modelData.workspaceId === Wm.activeId
                        ? Theme.primary : Qt.rgba(1, 1, 1, 0.16)

                    Text {
                        anchors.centerIn: parent
                        text: tile.modelData.workspaceId
                        color: tile.modelData.workspaceId === Wm.activeId
                            ? Theme.textOnPrimary : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall - 3
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.switchIndex = tile.index
                    onClicked: win.activateSwitch()
                }
            }
        }
    }

    Column {
        anchors.top: strip.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 1

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: win.switchTarget ? win.switchTarget.title : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: win.switchTarget
                ? win.switchTarget.cls + "  ·  workspace " + win.switchTarget.workspaceId
                : ""
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: win.cancelSwitch()
        Keys.onReturnPressed: win.activateSwitch()
    }
}
