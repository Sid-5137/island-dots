import QtQuick

import "root:/Services"

// The inner half of an edge.
//
// Every rounded surface in the shell was drawn with one hairline
// around the outside. That is enough to separate it from the wallpaper
// and not enough to say how round it is: a single stroke gives the eye
// one arc and no scale to measure it against, so a 36px corner and a
// 20px corner read as the same soft corner. Which is why the cards
// inside never looked like they belonged — you cannot match a radius
// you cannot see.
//
// Two concentric strokes fix that, because a pair has a width. The gap
// between them stays constant the whole way round only if the arcs
// share a centre, so the corner is where the pair is read, and the
// radius stops being something you infer from the silhouette.
//
// It is also how a rounded edge catches light. The outer line is the
// shadow the edge casts onto what is behind it; the inner one is the
// lit face turned towards you. That order matters — a light line
// outside a dark one reads as embossed into the wallpaper rather than
// laid on top of it.
//
// Inert by construction: no fill, no input, nothing under it changes.
// Declare it last among a surface's children so the edge draws over
// whatever gets pushed against it.
//
// A Squircle rather than a Rectangle, because the surfaces it lines
// are Squircles now. A circular line inside a superellipse edge is the
// exact fault this widget exists to make visible — the gap between the
// two is even down the straights and wrong through the corners, which
// reads as a dark box behind a properly rounded outline rather than as
// what it is.

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

    // How far in the second line sits.
    //
    // Two pixels, and the gap is the point. At one the two strokes are
    // adjacent, and adjacent is the one spacing that defeats the whole
    // idea: they land as a single two-pixel edge, so the panel gets a
    // heavier outline and the eye still has one arc to read. Measured
    // off the running shell, an inset of 1 gives 71, 72, fill — a ramp
    // — and an inset of 2 gives 71, fill, 72, fill, which is a light
    // line, a dark gap and a light line. Only the second one has two
    // radii in it.
    //
    // It does not want to be larger than that. Past about three the
    // pair stops reading as an edge and starts reading as a frame
    // drawn inside the panel, which is a different and much louder
    // thing to say.
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
