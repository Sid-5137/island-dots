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
        font.family: Theme.fontIsland
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
                radius: Theme.radiusLarge
                color: active ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                border.width: 1
                border.color: active ? Theme.primary : "transparent"

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                // See Services/AppIcons.qml for why not the class itself.
                readonly property string iconSource: AppIcons.forClass(tile.modelData.cls)

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.round(Config.island.switcherTile * 0.56)
                    source: parent.iconSource
                    visible: parent.iconSource !== ""
                    opacity: tile.active ? 1 : 0.6

                    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
                }

                // Nothing in the theme for it: a window glyph of the
                // shell's own, never the missing-image checkerboard.
                Text {
                    anchors.centerIn: parent
                    visible: parent.iconSource === ""
                    text: Icons.tabApps
                    color: Theme.textDim
                    opacity: tile.active ? 1 : 0.6
                    font.family: Theme.fontIcons
                    font.pixelSize: Math.round(Config.island.switcherTile * 0.36 / 2) * 2
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    width: 16
                    height: 16
                    radius: Theme.radiusSmall
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
                        renderType: Text.NativeRendering
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
            font.family: Theme.fontIsland
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
            font.family: Theme.fontIsland
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
        // The second way a release gets here: once the switcher is on
        // screen it holds the keyboard, so Alt going up arrives as an
        // ordinary key event, whatever the compositor's binds made of it.
        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr)
                win.activateSwitch();
        }
    }
}
