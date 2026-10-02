import QtQuick

import "root:/Services"

// A round glyph, filled when whatever it stands for is on.
//
// This is the piece that makes a row of controls scannable: the state
// is a filled circle you can see from the far side of the screen, and
// the label underneath is there for the detail. It is also the whole
// of a control that has been squeezed down to one cell, which is why
// it knows how to size its own glyph rather than taking one.

Item {
    id: root

    property string glyph: ""
    property bool lit: false
    property color litColor: Theme.primary

    implicitWidth: 30
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.lit ? root.litColor : Qt.rgba(1, 1, 1, 0.09)

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }

    // Plain centerIn: the icon font's line box is the icon's frame.
    // See Widgets/Tile.qml.
    Text {
        id: icon
        anchors.centerIn: parent

        text: root.glyph
        color: root.lit ? Theme.textOnPrimary : Theme.text
        font.family: Theme.fontIcons
        font.pixelSize: Math.round(root.height * 0.46)
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }
}
