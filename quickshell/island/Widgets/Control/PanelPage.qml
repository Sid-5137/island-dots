import QtQuick

import "root:/Services"

// A sub-page of the control centre, over the grid.
//
// The alternative was a separate island mode for each list, which
// means the pill morphs to a different size, the grid fades out, a
// page fades in, and the whole panel appears to have been replaced —
// for what is really a drill-down inside one panel. So a page is drawn
// over the grid instead: the panel keeps its shape, the grid slides
// out a little to the left, the page slides in from the right, and the
// back chevron reverses it.
//
// The header is one row: chevron, title, switch. saneAspect spends
// half a minute on exactly this in the Dynamite V3 video — his had the
// three sitting at three different heights, and it looked wrong for
// five minutes before he could say why. He is right, and it is the
// sort of thing that is much cheaper to get right once, here, than in
// each page.

Item {
    id: root

    property string title: ""
    property string note: ""

    // Header switch. Absent unless `hasSwitch` is set, because not
    // every page is a thing that can be turned off.
    property bool hasSwitch: false
    property bool on: false

    signal back()
    signal toggled()

    // Everything declared inside a page lands in here, under the
    // header, rather than on top of it.
    default property alias content: body.data

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 30

        Text {
            id: chevron
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "‹"
            color: backHover.containsMouse ? Theme.text : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 19

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            MouseArea {
                id: backHover
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        Text {
            anchors.left: chevron.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }

        Text {
            anchors.right: toggle.visible ? toggle.left : parent.right
            anchors.rightMargin: toggle.visible ? 12 : 2
            anchors.verticalCenter: parent.verticalCenter
            text: root.note
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Switch {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasSwitch
            checked: root.on
            onToggled: root.toggled()
        }
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
    }
}
