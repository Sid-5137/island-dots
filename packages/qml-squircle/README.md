<div align="center">

# qml-squircle

**continuous corners for QML, on surfaces a compositor blurs**

Two files to copy — a QML component and a baked shader — or one, if
you take the Canvas fallback. No build step, no C++.

</div>

---

## What it is

`Squircle.qml` draws a rounded rectangle whose corners are superellipse
arcs rather than circular ones — the corner macOS draws, and the one
Hyprland draws for windows when `decoration:rounding_power` is above 2.

```qml
Squircle {
    anchors.fill: parent
    radius: 16
    smoothing: 4          // 2 is a circle; 4 is about macOS
    color: "#1c1c1e"
    borderWidth: 1
    borderColor: "#3a3a3c"
}
```

A circular corner meets the straight edge where curvature jumps from
zero to `1/r` all at once. The eye reads that discontinuity as a seam,
which is why a circularly rounded box looks faintly pinched at the
corners. Spending the same radius over a longer, flatter arc removes
it: the curve leaves the edge earlier and eases in.

| `smoothing` | corner |
|:--|:--|
| `2` | a circle — pixel-identical to `Rectangle` |
| `4` | about what macOS uses |
| `6`+ | visibly squared off |

The curve is `|x/r|^n + |y/r|^n = 1`, traced parametrically as
`x = r·cos(t)^(2/n)`, `y = r·sin(t)^(2/n)`. That is the same family
Hyprland's `rounding_power` names, so one number can describe a window
corner and a panel corner and have them match.

---

## Why it exists

Qt's `Rectangle` draws circular corners and has no corner smoothing. It
gained per-corner radii in 6.7 and stopped there. The obvious
alternative is `QtQuick.Shapes` — and on a translucent Wayland surface
that a compositor blurs, a `Shape` cannot be used at all.

**A `Shape` anywhere in such a window turns that window's whole
bounding rectangle opaque in the buffer.** The compositor then blurs
and dims a square behind the shape, hiding the very corner the `Shape`
was there to draw:

<div align="center">
<sub>the dark square is the bug, not a shadow</sub>
</div>

None of these fix it, and each was measured rather than assumed:

| attempt | result |
|:--|:--|
| `Shape.GeometryRenderer` instead of `Shape.CurveRenderer` | still opaque |
| `layer.enabled: true` on the `Shape` | still opaque |
| raising the layer rule's `ignore_alpha` from `0.03` to `0.5` | still opaque |
| `Shape` offscreen as a `visible: false` layer source, composited by `MultiEffect` | still opaque |
| the same geometry as a plain `Rectangle` | **clean** |

The last row is what makes it the `Shape` and not the path. That it
survives an `ignore_alpha` of `0.5` is the useful detail: the alpha
being written is not faint, so no threshold saves you.

Two things do not have the problem, and this package ships both.
A `ShaderEffect` is one quad with a fragment shader: the alpha it
writes is the alpha you get. `Canvas` rasterises with `QPainter` into a
texture of its own. Neither adds a `Shape` node to the scene, and that
is the whole trick.

---

## Which file

| | `Squircle.qml` | `SquircleCanvas.qml` |
|:--|:--|:--|
| draws with | a fragment shader (`squircle.frag.qsb`) | `QPainter`, via `Canvas` |
| needs | the `.qsb` beside it | nothing |
| on resize | free — it is one quad | a repaint |
| edge | exact to the pixel through the corner | polygon antialiasing, a touch softer |

The shader is the default. The `.qsb` is committed and carries SPIR-V,
GLSL 300 es and 330, HLSL and MSL, so nobody using the component needs
a shader compiler; only somebody changing `squircle.frag` runs
`build.sh`, which wants `qsb` from Qt's shader tools
(`qt6-qtshadertools-devel` on Fedora).

The shader is six lines of maths: the usual rounded-box SDF with the
`L^n` norm in place of `length()`, which turns a circular corner into a
superellipse of exponent `n`. Everything about *which* `n` and *which*
extent — the rules below — is decided in QML and handed to it.

Two things worth knowing if you touch the shader. Qt caches compiled
pipelines by URL for the life of the process, so after `build.sh` the
app has to be restarted — a QML hot-reload keeps drawing with the old
`.qsb`, which looks exactly like the edit having done nothing. And Qt hands a QML
`color` to a uniform already premultiplied, and the scene graph blends
premultiplied. Multiplying by alpha again in the shader is a fill a few
levels too dark and a 14%-alpha line reduced to 2% — a bezel that
disappears — which is how that line was found. Checked against
`Rectangle` at 50% alpha over a known grey: all three come out at the
same pixel value.

## Radius means how round it looks

A superellipse of the same nominal radius as a circle does not look as
round. At `n = 4` the curve reaches only 54% as deep into the corner,
so a 14px squircle reads as a 7px circle — very nearly a rectangle.
Apple's continuous corners and Figma's corner smoothing both extend
the curve along the edges to compensate, and so does this component:
`radius` is the roundness `Rectangle` would give you, and the extent of
the curve is scaled up so the corner keeps it.

The factor puts the 45° point of the curve where a circle's would be:

| `smoothing` | corner extent along each edge |
|:--|:--|
| `2` | `1.00 × radius` — a circle, unchanged |
| `3` | `1.42 × radius` |
| `4` | `1.84 × radius` |
| `6` | `2.69 × radius` |

Without this, turning smoothing up makes every shape *squarer*, which
is the opposite of what anyone turning it up wants — and it is an easy
mistake to ship, because the maths is right and the shape is wrong.

## The capsule rule

Smoothing tapers to `2` as the corner's extent approaches half the
shorter side, and is gone by the time it gets there. When the curve
already spans the whole half-height there is no straight edge left for
it to flatten towards, so the ends stop being semicircles and the shape
reads as a box with its corners taken off. A capsule has to stay a
capsule; macOS does not square off a pill-shaped button either.

The taper is `1 - t^8` where `t = extent / (min(w, h) / 2)`, which
keeps it out of the way until the curve is genuinely near the cap:

| shape | radius | extent at n=4 | `t` | effective smoothing |
|:--|--:|--:|--:|--:|
| 680px panel, radius 14 | 14 | 26 | 0.08 | 4.00 |
| 58px bar, radius 17 | 17 | 31 → 29 | 1.00 | 2.00 |
| 34px pod, radius 16 | 16 | 29 → 17 | 1.00 | 2.00 |

Without it a near-capsule draws as a dark squared-off box, which is
easy to mistake for a compositor bug — it is not, it is the maths
being applied where it should not be.

## The border is a ring, not a stroke

The border is drawn as a ring — the outline, with the outline moved in
by the border width cut out of it — and the fill sits inside the ring.
That is how `Rectangle` draws its own, and it is the difference between
polished and not.

A stroke laid along the fill's edge straddles the path: its inner half
lands on top of the fill and only its outer half is over the
background. A 30%-alpha border comes out invisible over a dark fill,
and the fill's own antialiased edge then leaks a pixel of dark past it.
The eye reads that as the fill bleeding out and the border no longer
being the edge of the thing. A ring is over the background only, so it
stays the outermost thing at full strength, and the fill's edge is
underneath it where the ring hides it.

## Concentric strokes

If you draw a second line inside a `Squircle` — an inner border, a
focus ring — it has to be a `Squircle` too, at the same `smoothing`. A
circular line inside a superellipse edge leaves a gap that is even
down the straights and wrong through the corners, and the eye reads
that as a dark box behind a properly rounded outline rather than as
two disagreeing curves.

---

## Properties

| property | default | meaning |
|:--|:--|:--|
| `radius` | `12` | how round the corner looks — the `Rectangle` radius it matches; the curve's extent is larger |
| `smoothing` | `4` | superellipse exponent; `2` is a circle |
| `color` | `transparent` | fill |
| `borderWidth` | `0` | stroke width, drawn inside the shape as `Rectangle` does |
| `borderColor` | `transparent` | stroke |
| `segments` | `14` | points per corner |
| `effectiveSmoothing` | — | read-only; `smoothing` after the capsule taper |
| `paintWhileResizing` | `true` | Canvas only: repaint per frame, or once on settle |

---

## Install

Copy `Squircle.qml` and `squircle.frag.qsb` next to your other QML
files. That is the whole installation. If you would rather not carry a
binary, copy `SquircleCanvas.qml` alone and use that.

## Licence

GPL-3.0, as part of [island-dots](https://github.com/Sid-5137/island-dots),
where it is the shell's own corner.
