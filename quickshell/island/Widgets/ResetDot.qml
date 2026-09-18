import QtQuick
import "root:/Services"

// A revert control that appears only when a setting differs from the
// value the shell ships. Nothing to read when everything is default,
// and an obvious way back when it isn't.

Item {
    id: root

    // "section.key", e.g. "island.hoverGrace"
    property string configKey: ""

    readonly property var defaultValue: Config.defaultFor(configKey)
    readonly property bool known: defaultValue !== undefined

    // Compared loosely: JSON round-trips 1.0 as 1, and an int read
    // back from the file is not strictly equal to a real default.
    property var current: undefined
    readonly property bool modified:
        known && current !== undefined && String(current) !== String(defaultValue)

    implicitWidth: 18
    implicitHeight: 18

    visible: modified
    opacity: modified ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140 } }

    Text {
        anchors.centerIn: parent
        text: "\u21ba"
        color: hover.containsMouse ? Theme.primary : Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: 13
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -5
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Config.resetKey(root.configKey)
    }
}
