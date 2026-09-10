import QtQuick
import "root:/Services"

// A small caps heading that separates groups of rows.

Item {
    id: root
    property string text: ""

    // Name of the Config section this header covers. Set it and a
    // reset control appears; leave it empty for a plain heading.
    property string section: ""

    readonly property color tintLine: Qt.rgba(1, 1, 1, 0.10)

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 40

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: root.text.toUpperCase()
        // Headers were set in outline grey at 10px — legible in a
        // mockup, invisible in use. Bright and bold, since a header
        // is the thing you scan for.
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        font.letterSpacing: 2.4
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.tintLine
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5

        visible: root.section !== ""
        text: confirming ? "Sure?" : "Reset"
        color: confirming ? Theme.error
            : (resetHover.containsMouse ? Theme.text : Theme.outline)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall - 1
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering

        // Two presses, because a reset is not undoable and the button
        // sits next to controls people are already clicking.
        property bool confirming: false

        Behavior on color { ColorAnimation { duration: 120 } }

        Timer {
            id: armed
            interval: 2500
            onTriggered: parent.confirming = false
        }

        MouseArea {
            id: resetHover
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (!parent.confirming) {
                    parent.confirming = true;
                    armed.restart();
                    return;
                }
                parent.confirming = false;
                armed.stop();
                Config.resetSection(root.section);
            }
        }
    }
}
