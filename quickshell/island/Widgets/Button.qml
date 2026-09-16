import QtQuick

import "root:/Services"

// A chip: one word, and something that happens when you press it.
//
// This shape was written out eleven times — Rescan, Disconnect, Join,
// Scan, Reapply, Lock, Reset all, Regenerate, Clear, Cancel,
// Authenticate — and each copy had its own idea of how tall a button
// is (24, 26, 28, 30, 32), which corner it gets (6, 7, 8) and how wide
// a word needs to be (62, 74, 84, 90, 96, 108, 118, all measured by
// eye). None of the eleven reacted to a press.
//
// Width is the interesting one. Every copy hard-coded a number that
// fitted the label it happened to have, which is why the reset button
// is 118px wide: not because "Reset all" needs 118, but because
// "Really? Click again" does. Sizing to the text means the confirm
// state just works, and means a translation does not have to be short
// enough for somebody else's guess.
//
// `kind` is the one axis worth keeping, and what it names is what the
// press costs:
//
//   plain    the default. A wash that lifts under the pointer.
//   primary  the thing the row is for. Filled with the accent.
//   danger   destructive, and armed. Filled with the error colour.

Rectangle {
    id: root

    property string text: ""
    property string kind: "plain"   // "plain" | "primary" | "danger"

    // Words to the edge. Its own number rather than padCard: a
    // button's edge is a target as well as a margin, and a chip that
    // is exactly as wide as its label is hard to hit and looks
    // cramped.
    property int padding: 16

    signal clicked()

    implicitWidth: label.implicitWidth + root.padding * 2
    implicitHeight: 30

    readonly property bool filled: kind !== "plain"

    radius: Theme.radiusSmall

    // The fills are white washes for plain buttons, at Surface's
    // alphas — see Widgets/Control/Surface.qml for why a wash rather
    // than a palette colour. A filled button is the exception: it is
    // saying something about consequence, and a wash cannot say that.
    color: {
        if (kind === "danger") return Theme.error;
        if (kind === "primary")
            return tap.containsMouse ? Qt.lighter(Theme.primary, 1.12)
                                     : Theme.primary;
        return Qt.rgba(1, 1, 1, tap.containsMouse ? 0.13 : 0.07);
    }

    border.width: 1
    border.color: filled
        ? color
        : Qt.rgba(1, 1, 1, tap.containsMouse ? 0.18 : 0.09)

    // `enabled` already gates the MouseArea, so dimming with it keeps
    // the two from disagreeing — a button that looks live and does
    // nothing is worse than one that looks dead.
    opacity: enabled ? 1 : 0.4

    // ConnRow gives way by 3%, which on a 200px card is six pixels and
    // on a 30px chip is one. The give-way is meant to be seen, so a
    // chip spends more of itself on it.
    scale: tap.pressed ? 0.94 : 1

    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }
    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

    Behavior on scale {
        NumberAnimation {
            duration: Motion.hover
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.arrive
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: {
            if (root.kind === "danger") return Theme.textOnError;
            if (root.kind === "primary") return Theme.textOnPrimary;
            return Theme.text;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
