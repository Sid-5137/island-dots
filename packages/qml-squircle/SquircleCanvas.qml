import QtQuick

// Squircle.qml rasterised by QPainter — the no-binary fallback for
// when squircle.frag.qsb cannot sit beside the QML. Softer edge, and a
// repaint per resize, which is why the shader is the default.
//
// Superellipse corners: smoothing 2 is a circle, 4 is about macOS,
// 6+ reads squared off.
//
// NOT a QtQuick.Shape. A Shape anywhere in a translucent Wayland
// surface turns the whole window opaque in the buffer, so a blurring
// compositor dims a square behind it. GeometryRenderer, layer.enabled,
// a higher ignore_alpha and an offscreen MultiEffect were all measured
// and none help. Canvas adds no Shape node, so alpha survives.
//
// paintWhileResizing: a surface animating its own geometry can leave
// it off and take a corner that settles a frame late.

Item {
    id: root

    property real radius: 12
    property real smoothing: 4

    property color color: "transparent"
    property real borderWidth: 0
    property color borderColor: "transparent"

    // Points per corner. Past twelve nothing changes on screen at the
    // radii the shell uses, and each one is a lineTo.
    property int segments: 14

    // Whether to redraw on every frame of a resize. Off, the shape is
    // still correct the moment it settles; the frames in between are
    // drawn with the last outline stretched, which on a morph of a few
    // hundred milliseconds is not something the eye catches.
    property bool paintWhileResizing: true

    // `radius` means how round it LOOKS, not the raw parameter. A
    // superellipse reaches less deep into the corner than a circle of
    // the same radius, so the curve's extent along each edge is scaled
    // up to put its 45° point where a circle's would be:
    //
    //     n = 2  1.00x (a circle)   n = 4  1.84x
    //     n = 3  1.42x              n = 6  2.69x
    //
    // Without it, raising smoothing makes every shape squarer.
    function extent(n) {
        return (1 - Math.pow(2, -0.5)) / (1 - Math.pow(2, -1 / n));
    }

    readonly property real half: Math.min(width, height) / 2

    // Smoothing tapers off as the corner approaches half the shorter
    // side, and is gone by the time it gets there: with no straight
    // edge left to flatten towards, the ends stop being semicircles
    // and a capsule reads as a box with its corners taken off.
    //
    // Measured against the EXTENDED extent, not the nominal radius —
    // a 14px corner at n = 4 wants 26px of edge, and that is what has
    // to fit.
    readonly property real effectiveSmoothing: {
        if (half <= 0) return 2;
        const n = Math.max(2, smoothing);
        const t = Math.min(1, radius * extent(n) / half);
        return 2 + (n - 2) * (1 - Math.pow(t, 8));
    }

    readonly property real effectiveRadius:
        Math.max(0, Math.min(radius * extent(effectiveSmoothing), half))

    onWidthChanged: schedule()
    onHeightChanged: schedule()
    onRadiusChanged: schedule()
    onEffectiveSmoothingChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onBorderColorChanged: canvas.requestPaint()
    onBorderWidthChanged: canvas.requestPaint()

    function schedule() {
        if (paintWhileResizing) canvas.requestPaint();
        else settle.restart();
    }

    Timer {
        id: settle
        interval: 16
        onTriggered: canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        // Into an FBO rather than an image, so the raster lands on the
        // GPU without a round trip through main memory on every paint.
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            const r = root.effectiveRadius;
            if (w <= 0 || h <= 0) return;

            const bw = Math.max(0, root.borderWidth);
            const hasBorder = bw > 0 && root.borderColor.a > 0;

            // The border is a ring with the fill inside it, never a
            // stroke along the fill's edge. A stroke straddles the
            // path, so half of it lands on the fill and a low-alpha
            // border goes invisible while the fill's antialiased edge
            // leaks past it.
            //
            // Concentric: the inner outline is the outer one moved in
            // by the border width, radius included.
            if (hasBorder) {
                ctx.beginPath();
                trace(ctx, 0, 0, w, h, r);
                trace(ctx, bw, bw, w - 2 * bw, h - 2 * bw, Math.max(0, r - bw));
                ctx.fillStyle = root.borderColor;
                ctx.fillRule = Qt.OddEvenFill;
                ctx.fill();
            }

            if (root.color.a > 0) {
                ctx.beginPath();
                if (hasBorder)
                    trace(ctx, bw, bw, w - 2 * bw, h - 2 * bw, Math.max(0, r - bw));
                else
                    trace(ctx, 0, 0, w, h, r);
                ctx.fillStyle = root.color;
                ctx.fillRule = Qt.WindingFill;
                ctx.fill();
            }
        }

        // x = r·cos(t)^k, y = r·sin(t)^k traces a quarter circle at
        // k = 1 and a quarter squircle as k falls. k = 2/n is the
        // superellipse |x/r|^n + |y/r|^n = 1 written parametrically,
        // which is the same curve Hyprland's rounding_power names — so
        // one number describes a window corner and a panel corner.
        function trace(ctx, x, y, w, h, r) {
            if (w <= 0 || h <= 0) return;

            if (r <= 0) {
                ctx.moveTo(x, y);
                ctx.lineTo(x + w, y);
                ctx.lineTo(x + w, y + h);
                ctx.lineTo(x, y + h);
                ctx.closePath();
                return;
            }

            const k = 2 / root.effectiveSmoothing;
            const n = root.segments;
            let first = true;

            function arc(cx, cy, xs, ys, swap) {
                for (let s = 0; s <= n; s++) {
                    const t = (s / n) * (Math.PI / 2);
                    const a = Math.pow(Math.cos(t), k) * r;
                    const b = Math.pow(Math.sin(t), k) * r;
                    const px = cx + xs * (swap ? b : a);
                    const py = cy + ys * (swap ? a : b);
                    if (first) { ctx.moveTo(px, py); first = false; }
                    else ctx.lineTo(px, py);
                }
            }

            arc(x + r,     y + r,     -1, -1, false);  // top left
            arc(x + w - r, y + r,      1, -1, true);   // top right
            arc(x + w - r, y + h - r,  1,  1, false);  // bottom right
            arc(x + r,     y + h - r, -1,  1, true);   // bottom left
            ctx.closePath();
        }
    }
}
