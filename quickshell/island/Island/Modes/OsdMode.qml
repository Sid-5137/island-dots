import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Volume, brightness and mic readout. A bar, not a number: the level
// relative to full is what you're checking, and the value is there for
// when it isn't.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    readonly property bool shown: island.isOsd

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Text {
        id: osdIcon
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        text: Osd.icon
        color: Osd.muted ? Theme.outline : Theme.primary
        font.family: Theme.fontIcons
        font.pixelSize: 18
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
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
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.12)
        visible: Osd.kind !== "mic"

        Rectangle {
            // Never narrower than it is tall, so the fill stays a
            // capsule rather than collapsing to a lens at zero.
            width: Math.max(parent.height, parent.width * (Osd.value / 100))
            height: parent.height
            radius: height / 2
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
        font.family: Theme.fontIsland
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
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }
}
