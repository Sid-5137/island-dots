import QtQuick

import "root:/Services"

// The card every control in the panel is drawn on.
//
// One shape, three states — resting, pointed at, and carrying
// something that is on. Shared rather than repeated because the panel
// is now a grid of cards of different kinds, and the moment each kind
// picks its own resting alpha the grid stops reading as one surface.
//
// The fills are white washes rather than palette colours on purpose.
// The panel underneath is already a themed surface at the island's
// opacity; a second themed colour on top of it lands somewhere between
// the two and looks like a mistake, whereas a wash just lifts whatever
// is behind it.

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
