import QtQuick

import "root:/Services"

// One network, or one Bluetooth device.
//
// A badge, what it is called, what it is doing, and the one action
// available on it. The action is a button rather than a click on the
// row because on these lists the verb changes — connect, disconnect,
// pair — and a row whose meaning depends on state it is also
// displaying is a row you have to read before you dare click.

Item {
    id: root

    property string glyph: ""
    property string name: ""
    property string sub: ""
    property string action: ""
    property bool lit: false

    // Drawn but not actionable, for a network that is mid-connect.
    property bool waiting: false

    signal triggered()

    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        radius: Math.round(Config.appearance.panelRadius * 0.9)
        color: hover.containsMouse || root.lit
            ? Qt.rgba(1, 1, 1, root.lit ? 0.07 : 0.05)
            : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Badge {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        glyph: root.glyph
        lit: root.lit
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 9
        anchors.right: act.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            width: parent.width
            text: root.name
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: root.lit ? Font.Bold : Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.sub !== ""
            text: root.sub
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        id: act
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.action !== ""

        width: label.implicitWidth + 18
        height: 24
        radius: 12

        color: tap.containsMouse && !root.waiting
            ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
        opacity: root.waiting ? 0.5 : 1

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.waiting ? "…" : root.action
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.waiting
            cursorShape: Qt.PointingHandCursor
            onClicked: root.triggered()
        }
    }
}
