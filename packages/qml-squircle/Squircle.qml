import QtQuick

// A rounded rectangle whose corners are superellipse arcs rather than
// circular ones — the corner macOS draws, and the one Hyprland draws
// for windows when `decoration:rounding_power` is above 2.
//
// A circular corner meets the straight edge where curvature jumps from
// zero to 1/r all at once. The eye reads that discontinuity as a seam,
// which is why a circularly rounded box looks faintly pinched at the
// corners. Spending the same radius over a longer, flatter arc removes
// it: the curve leaves the edge earlier and eases in.
//
//   smoothing = 2   a circle, exactly what Rectangle draws
//   smoothing = 4   about what macOS uses, and the default here
//   smoothing = 6+  visibly squared off
//
// ── Why this is a Canvas and not a Shape ─────────────────────
//
// QtQuick.Shapes is the obvious tool and it cannot be used on a
// translucent Wayland surface that a compositor blurs. A Shape
// anywhere in such a window turns that window's whole bounding
// rectangle opaque in the buffer, so the compositor blurs and dims a
// square behind the shape — hiding the very corner the Shape was
// there to draw.
//
// Measured, not assumed. None of these help:
//
//   Shape.GeometryRenderer instead of Shape.CurveRenderer
//   layer.enabled on the Shape
//   raising the layer rule's ignore_alpha from 0.03 to 0.5
//   keeping the Shape offscreen as a visible:false layer source
//     composited by a MultiEffect
//
// Swapping the same geometry for a plain Rectangle clears it every
// time, which is what makes it the Shape and not the path.
//
// Canvas rasterises with QPainter into a texture of its own and adds
// no Shape node to the scene, so the surface's alpha is whatever the
// texture says — which is the whole point. A fragment shader would be
// faster still and has the same property; it needs `qsb` at build
// time, which a drop-in QML file should not.
//
// The cost is that it repaints on resize rather than being re-rasterised
// by the GPU, so `paintWhileResizing` exists: a surface that animates
// its own geometry every frame can leave it off and get a corner that
// settles a frame late rather than a repaint per frame.

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

    // ── Radius means how round it looks ──────────────────────
    //
    // A superellipse of the same radius as a circle does not look as
    // round. At n = 4 the curve reaches only 54% as deep into the
    // corner, so a 14px squircle reads as a 7px circle — very nearly a
    // rectangle. Apple and Figma both extend the corner region along
    // the edges to compensate, and so does this: `radius` is the
    // roundness you would get from Rectangle, and the extent of the
    // curve along each edge is scaled up so the corner keeps it. The
    // factor is what makes the 45° point of the curve land where a
    // circle's would:
    //
    //     n = 2   1.00x   (a circle: unchanged)
    //     n = 3   1.42x
    //     n = 4   1.84x
    //     n = 6   2.69x
    //
    // Without it, turning smoothing up makes every shape squarer,
    // which is the opposite of what anyone turning it up wants.
    function extent(n) {
        return (1 - Math.pow(2, -0.5)) / (1 - Math.pow(2, -1 / n));
    }

    readonly property real half: Math.min(width, height) / 2

    // Smoothing tapers off as the corner approaches half the shorter
    // side, and is gone by the time it gets there.
    //
    // This is the one place the naive reading of "higher is rounder"
    // inverts. When the curve already spans the whole half-height there
    // is no straight edge left for it to flatten towards, so the ends
    // stop being semicircles and the shape reads as a box with its
    // corners taken off. A capsule has to stay a capsule; macOS does
    // not square off a pill-shaped button either.
    //
    // Measured against the extended extent, not the nominal radius —
    // a 14px corner at n = 4 wants 26px of edge, and it is that 26px
    // that has to fit.
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

            // The border is a ring and the fill sits inside it, which
            // is how Rectangle draws its own — never a stroke laid
            // along the fill's edge. A stroke straddles the path, so
            // its inner half lands on top of the fill and its outer
            // half is the only part over the background: a 30%-alpha
            // border comes out invisible over a dark fill, and the
            // fill's own antialiased edge then leaks a pixel of dark
            // past it. The eye reads that as the fill bleeding out and
            // the border no longer being the edge. A ring is drawn
            // over the background only, so it stays the outermost
            // thing at full strength, and the fill's edge is
            // underneath it where the ring hides it.
            //
            // Concentric: the inner outline is the outer one moved in
            // by the border width, radius included, so the ring keeps
            // one thickness the whole way round.
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
