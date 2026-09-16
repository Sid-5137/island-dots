import QtQuick

import "root:/Services"

// Wi-Fi and Bluetooth: what it is, what it is attached to, and a way
// into the list.
//
// A glyph on its own can say that Wi-Fi is on. It cannot say which
// network, and "which network" is most of the reason anyone opens a
// control centre at all. So the card carries the answer, and the two
// things you might want to do with it are separated by where you
// click: the badge is the power switch, the rest of the row is the
// way in to the list. That split is why the badge is a circle and the
// row is not — they are different targets and they should look it.
//
// Squeezed to a single cell there is no room for any of that, so it
// becomes the badge alone and keeps only the toggle. A control that
// silently drops half its behaviour when it is made small would be
// worse than one that refuses to be made small, but a power switch is
// the half worth keeping.

Item {
    id: root

    property string glyph: ""
    property string name: ""
    property string sub: ""
    property bool on: false
    property bool busy: false

    // Whether the card is allowed words at all. Off, it is the badge
    // alone at any size — which is the whole point: somebody who knows
    // their own panel does not need it read back to them.
    property bool showText: true

    // False once the card is one cell wide, or once the words have
    // been turned off.
    // Roomy enough for words is a question about the column left over
    // after the badge, not about the card's aspect: a 72px card is
    // wider than it is tall and still leaves thirty pixels for a name,
    // which is how "Keep awake" ends up rendering as "K…".
    readonly property bool roomy:
        showText && width - height > 70

    signal toggled()
    signal opened()

    Surface {
        anchors.fill: parent
        lit: false
        hovered: rowHover.containsMouse && root.roomy
    }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.roomy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    // Positioned, not anchored. The badge sits against the left edge
    // when there is a label beside it and in the middle when there is
    // not, and the obvious way to write that — an anchor bound to
    // `undefined` for the case that does not apply — does not work:
    // assigning undefined to an anchor does not clear it, so the item
    // ends up anchored by both `left` and `horizontalCenter` at once,
    // and Qt quietly derives the width from the pair. The symptom is a
    // 30px circle rendering as a 108px capsule.
    Badge {
        id: badge

        readonly property int size:
            Math.max(20, Math.min(30, root.height - 18))

        width: size
        height: size

        x: root.roomy ? 9 : Math.round((root.width - size) / 2)
        y: Math.round((root.height - size) / 2)

        glyph: root.glyph
        lit: root.on

        MouseArea {
            anchors.fill: parent
            // A 30px circle is a small target, and the row behind it
            // does something different — so it is widened past its
            // own edges rather than left exactly the size of the ink.
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: chevron.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        visible: root.roomy

        Text {
            width: parent.width
            text: root.name
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.Bold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            // "Scanning…" while a scan is running, because a list that
            // is about to change should say so rather than showing a
            // stale answer with no explanation.
            text: root.busy ? "Scanning…" : root.sub
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: root.roomy
        text: "›"
        color: rowHover.containsMouse ? Theme.text : Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: 15

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }
}
