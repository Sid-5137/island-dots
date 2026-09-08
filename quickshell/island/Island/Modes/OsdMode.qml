import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"

// Volume, brightness and mic readout. A bar, not a number: the level
// relative to full is what you're checking, and the value is there for
// when it isn't.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    opacity: (island.isOsd && pill.width > Config.island.osdWidth * 0.8) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    Text {
        id: osdIcon
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        text: Osd.icon
        color: Osd.muted ? Theme.outline : Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        id: osdTrack
        anchors.left: osdIcon.right
        anchors.leftMargin: 16
        anchors.right: osdValue.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.12)
        visible: Osd.kind !== "mic"

        Rectangle {
            width: Math.max(8, parent.width * (Osd.value / 100))
            height: parent.height
            radius: 4
            color: Osd.muted ? Theme.outline : Theme.primary

            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    Text {
        anchors.left: osdIcon.right
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: Osd.kind === "mic"
        text: Osd.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    Text {
        id: osdValue
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        visible: Osd.kind !== "mic"
        text: Osd.muted ? "--" : Osd.value
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeNormal
        renderType: Text.NativeRendering
    }
}
