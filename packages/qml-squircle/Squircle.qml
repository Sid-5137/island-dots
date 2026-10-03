import QtQuick

// A rounded rectangle with superellipse corners, drawn by a fragment
// shader. SquircleCanvas.qml is the same shape via QPainter for when
// the .qsb cannot ship.
//
// Deliberately not QtQuick.Shapes: a Shape in a translucent Wayland
// surface a compositor blurs turns the surface opaque.
// SquircleCanvas.qml has the measurements.
//
// Three rules, as in the Canvas version and the README: `radius` is
// how round the corner LOOKS, a capsule stays a capsule (smoothing
// tapers to 2 at the cap), and the border is a ring outside the fill.
//
// squircle.frag.qsb must sit beside this file. It is committed; only
// editing the shader needs qsb (see build.sh).

ShaderEffect {
    id: root

    property real radius: 12
    property real smoothing: 4

    property color color: "transparent"
    property real borderWidth: 0
    property color borderColor: "transparent"

    // Optional, and off unless set: the colour at the bottom of the
    // shape, for a fill or border that shades from top to bottom. A
    // surface lit from above reads as having volume; a flat one reads
    // as cut out of paper.
    property color colorEnd: color
    property color borderColorEnd: borderColor

    // Also optional: draw the shape `inset` px inside the item and
    // feather its edge across `softness` px either side — the room
    // the inset leaves is where the falloff goes. Dark, offset and
    // behind something, that is its shadow. 0 is the crisp edge.
    property real inset: 0
    property real softness: 0

    // ── Radius means how round it looks ──────────────────────
    //
    // A superellipse of the same radius as a circle does not look as
    // round: at n = 4 the curve reaches only 54% as deep into the
    // corner, so a 14px squircle reads as a 7px circle. The corner's
    // extent along each edge is scaled so its 45° point lands where a
    // circle's would — 1.42x at n = 3, 1.84x at n = 4, 2.69x at n = 6.
    function extentFor(n) {
        return (1 - Math.pow(2, -0.5)) / (1 - Math.pow(2, -1 / n));
    }

    // The shape, not the item: an inset shape is smaller than its item.
    readonly property real half: Math.max(0, Math.min(width, height) / 2 - inset)

    // ── A capsule stays a capsule ────────────────────────────
    //
    // When the curve already spans the whole half-height there is no
    // straight edge left for it to flatten towards, so the ends stop
    // being semicircles and the shape reads as a box with its corners
    // taken off. Smoothing tapers to 2 as the extent nears the cap.
    readonly property real effectiveSmoothing: {
        if (half <= 0) return 2;
        const n = Math.max(2, smoothing);
        const t = Math.min(1, radius * extentFor(n) / half);
        return 2 + (n - 2) * (1 - Math.pow(t, 8));
    }

    readonly property real effectiveRadius:
        Math.max(0, Math.min(radius * extentFor(effectiveSmoothing), half))

    // ── What the shader is handed ────────────────────────────
    //
    // Names match the uniform block in squircle.frag; Qt binds them
    // by name. They are deliberately not `radius` and `smoothing`,
    // which are the numbers you set, not the numbers drawn.
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real extent: effectiveRadius
    readonly property real power: effectiveSmoothing
    readonly property real edge: Math.max(0, borderWidth)
    readonly property color fill: color
    readonly property color fillEnd: colorEnd
    readonly property color line: borderColor
    readonly property color lineEnd: borderColorEnd
    readonly property real soft: Math.max(0, softness)

    fragmentShader: Qt.resolvedUrl("squircle.frag.qsb")
    blending: true
}
