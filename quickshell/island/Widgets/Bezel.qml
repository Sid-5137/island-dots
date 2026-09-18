import QtQuick

import "root:/Services"

// The inner half of an edge: the second of two concentric strokes.
//
// One hairline separates a surface from the wallpaper but gives no
// scale, so every corner radius reads the same. A pair has a width,
// and the eye reads the radius off it. Dark outside, light inside —
// the other order reads as laid on top rather than embossed.
//
// Inert: no fill, no input. Declare it last among a surface's children.
// A Squircle, not a Rectangle — a circular line inside a superellipse
// edge is the exact fault this exists to make visible.

Squircle {
    id: root

    // The radius of the shape this lines.
    //
    // Passed in rather than read off `parent.radius`, because the
    // surfaces worth lining are the ones whose radius is a function of
    // their own height — the pill, the pods — and a binding one
    // indirection removed from the thing that actually moves is a
    // binding that eventually stops moving with it.
    required property real outer

    // How far in the second line sits. Two pixels, and the gap is the
    // point: at 1 the strokes land as a single heavier edge with one
    // arc to read, and past about 3 the pair stops reading as an edge
    // and starts reading as a frame inside the panel.
    property int inset: 2

    anchors.fill: parent
    anchors.margins: inset

    // The concentric rule, applied to the one case where it is not a
    // judgement call — an edge lining another edge. Get this wrong and
    // the gap between the two strokes is even down the straights and
    // wider through the corners, which is the exact fault the pair is
    // there to make visible.
    radius: Theme.inner(outer, inset)
    smoothing: Config.appearance.cornerSmoothing

    color: "transparent"
    borderWidth: 1
    borderColor: Theme.bezel
}
