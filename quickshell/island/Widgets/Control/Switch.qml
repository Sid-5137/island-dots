import QtQuick

import "root:/Services"

// A bare on/off switch, for the header of a sub-page.
//
// Settings has ToggleRow, which is this plus a label, a description
// and a revert dot — all of which a page that already says "Bluetooth"
// at the top in bold does not need repeating.

Item {
    id: root

    property bool checked: false

    signal toggled()

    implicitWidth: 38
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Qt.rgba(1, 1, 1, 0.13)

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.textOnPrimary : Theme.text

            // The one place a spring belongs on something this small:
            // a switch that slides linearly reads as a progress bar.
            Behavior on x {
                NumberAnimation {
                    duration: Motion.hover
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.arrive
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
