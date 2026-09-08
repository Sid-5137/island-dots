import QtQuick
import "root:/Services"

// A small caps heading that separates groups of rows.

Item {
    id: root
    property string text: ""

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
}
