import QtQuick
import "root:/Services"

// A square quick-toggle: one glyph, centred, nothing else.

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property bool hasSecondary: false

    signal triggered()
    signal secondary()

    signal hoverChanged(bool inside)

    // A card's corner. This was `panelRadius * 0.9` — a fourth
    // multiplier, alongside Theme's three, that existed only here and
    // was never going to be kept in step with them.
    radius: Theme.radiusLarge

    color: active ? Theme.primary : Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: active ? Theme.primary
        : (hover.containsMouse ? Theme.outlineVariant
                               : Theme.fade(Theme.outlineVariant))

    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

    // anchors.centerIn centres a text's line box, not its ink — and
    // the icon font's line box is the icon's own 24-unit frame, so
    // here the two are the same thing. See packages/tabler-icons.
    Text {
        id: icon
        anchors.centerIn: parent

        text: root.glyph
        color: root.active ? Theme.textOnPrimary : Theme.text
        font.family: Theme.fontIcons
        font.pixelSize: Math.round(root.height * 0.34)
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.hasSecondary ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.secondary();
            else root.triggered();
        }

        onContainsMouseChanged: root.hoverChanged(containsMouse)
    }

}
