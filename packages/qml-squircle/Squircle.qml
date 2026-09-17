import QtQuick

// A rounded rectangle whose corners are superellipse arcs rather than
// circular ones — the corner macOS draws, and the one Hyprland draws
// for windows when `decoration:rounding_power` is above 2.
//
// Drawn by a fragment shader: one quad and six lines of maths per
// pixel. SquircleCanvas.qml is the same shape rasterised by QPainter
// and needs no shader file; use it if you cannot ship the .qsb. It
// repaints every time the item resizes, which for a surface that
// animates its own geometry is a repaint per frame, and its edge is
// QPainter's polygon antialiasing rather than exact to the pixel.
//
// Neither is QtQuick.Shapes, and that is deliberate: a Shape in a
// translucent Wayland surface a compositor blurs turns the surface's
// bounding rectangle opaque. SquircleCanvas.qml has the measurements.
//
// The three rules the README lays out are all here, in QML, the same
// as in the Canvas version: `radius` means how round the corner looks
// (so the curve's extent is scaled up), a capsule stays a capsule (so
// smoothing tapers to 2 at the cap), and the border is a ring outside
// the fill. The shader is handed the results and draws them.
//
// The cost is squircle.frag.qsb, which has to sit beside this file.
// It is committed, so copying the two files is the whole install; only
// changing the shader itself needs qsb (see build.sh).

ShaderEffect {
    id: root

    property real radius: 12
    property real smoothing: 4

    property color color: "transparent"
    property real borderWidth: 0
    property color borderColor: "transparent"

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

    readonly property real half: Math.min(width, height) / 2

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
    readonly property color line: borderColor

    fragmentShader: Qt.resolvedUrl("squircle.frag.qsb")
    blending: true
}
