import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Now playing, along the bottom of the control centre when
// something is playing.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 18
    anchors.rightMargin: 18
    anchors.bottomMargin: 14
    height: Config.island.mediaStripHeight - 14

    opacity: (island.isControl && island.media
              && pill.height > Config.island.controlHeight * 0.9) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.outlineVariant
    }

    Rectangle {
        id: stripArt
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 6
        width: 48; height: 48
        radius: 8
        color: Theme.surfaceHigh
        clip: true

        Image {
            id: stripImg
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !stripImg.visible
            text: "\u266a"
            color: Theme.outline
            font.pixelSize: 20
        }
    }

    Column {
        anchors.left: stripArt.right
        anchors.leftMargin: 12
        anchors.right: stripControls.left
        anchors.rightMargin: 12
        anchors.verticalCenter: stripArt.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: Player.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: Player.artist
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Row {
        id: stripControls
        anchors.right: parent.right
        anchors.verticalCenter: stripArt.verticalCenter
        spacing: 18

        Repeater {
            model: [
                { g: "\u23ee", act: "prev" },
                { g: "",        act: "toggle" },
                { g: "\u23ed", act: "next" }
            ]

            Text {
                required property var modelData
                text: modelData.act === "toggle"
                    ? (Player.playing ? "\u23f8" : "\u25b6")
                    : modelData.g
                color: modelData.act === "toggle" ? Theme.primary : Theme.textDim
                font.pixelSize: 17

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.act === "prev") Player.prev();
                        else if (modelData.act === "next") Player.next();
                        else Player.toggle();
                    }
                }
            }
        }
    }
}
