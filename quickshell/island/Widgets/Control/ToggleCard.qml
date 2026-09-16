import QtQuick

import "root:/Services"

// A quick toggle: badge, and a name once there is room for one.
//
// The panel used to be six of these and nothing else, glyph-only, in a
// fixed 3x2 block. Glyph-only is the right answer at one cell and the
// wrong one at three — a card wide enough to say "Keep awake" and
// choosing not to is just a card you have to hover to understand.

Item {
    id: root

    property string glyph: ""
    property string name: ""
    property string sub: ""
    property bool on: false

    // See ConnRow: the words are optional, per control.
    property bool showText: true

    // Roomy enough for words is a question about the column left over
    // after the badge, not about the card's aspect: a 72px card is
    // wider than it is tall and still leaves thirty pixels for a name,
    // which is how "Keep awake" ends up rendering as "K…".
    readonly property bool roomy:
        showText && width - height > 70

    signal triggered()

    Surface {
        anchors.fill: parent
        // The badge already carries the on state. Lighting the card as
        // well is the same fact twice, and at three cells wide it is a
        // lot of accent for a microphone.
        hovered: hover.containsMouse
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }

    // See ConnRow: the press is the half of the feedback that says it
    // was hit rather than merely pointed at.
    scale: hover.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Motion.hover
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.arrive
        }
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

        x: root.roomy ? Theme.padCard
                      : Math.round((root.width - size) / 2)
        y: Math.round((root.height - size) / 2)

        glyph: root.glyph
        lit: root.on
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Theme.gapBadge
        anchors.right: parent.right
        anchors.rightMargin: Theme.padCard
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
            visible: root.sub !== ""
            text: root.sub
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }
}
