import QtQuick

import "root:/Services"

// The card every control in the panel is drawn on: one shape, three
// states — resting, pointed at, and carrying something that is on.
// Shared, because the moment each kind of card picks its own resting
// alpha the grid stops reading as one surface.
//
// The fills are white washes, not palette colours: the panel is
// already a themed surface, and a second themed colour over it lands
// between the two and looks like a mistake.

Rectangle {
    id: root

    // Carrying an on state — a toggle that is on, a connection that
    // is up. Not the same as being pointed at.
    property bool lit: false
    property bool hovered: false

    // Slightly rounder than the panel, which reads as right when the
    // card is a fraction of the panel's size. Theme derives all three
    // radii from the one the user sets, so this follows that slider.
    radius: Theme.radiusLarge

    color: lit
        ? Theme.primary
        : Qt.rgba(1, 1, 1, hovered ? 0.13 : 0.07)

    border.width: 1
    border.color: lit
        ? Theme.primary
        : Qt.rgba(1, 1, 1, hovered ? 0.18 : 0.09)

    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
    Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }
}
