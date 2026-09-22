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

    // anchors.centerIn centres the text's LINE BOX, not the glyph.
    // The box runs from ascent above the baseline to descent below,
    // so its middle sits at (ascent + descent) / 2 from the top.
    // An icon's ink is centred near the baseline instead — roughly
    // 0.36em above it for this font family.
    //
    // Offset = where the ink actually sits, minus where the box
    // centre is:  (ascent - descent) / 2 - 0.36em
    //
    // Metrics differ between icon fonts, so tileIconOffset is there
    // to nudge the remainder rather than requiring an edit here.
    FontMetrics {
        id: fm
        font: icon.font
    }

    Text {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset:
            Math.round((fm.ascent - fm.descent) / 2 - font.pixelSize * 0.36)
            + Config.island.tileIconOffset

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
