#version 440

// A superellipse-cornered box as a signed distance field.
//
// The usual rounded-box SDF measures the corner with the Euclidean
// norm, which is what makes the corner a circular arc. Swap in the
// L^n norm — (|x|^n + |y|^n)^(1/n) — and the same six lines draw a
// superellipse of exponent n instead. n = 2 is the circle Rectangle
// draws; n = 4 is about the corner macOS draws.
//
// `extent` is the corner's reach along each edge, already scaled by
// the QML side so that `radius` there means how round the corner
// looks (see Squircle.qml). `power` is the exponent after the capsule
// taper. Nothing about those rules lives here: this is the drawing,
// and the drawing is deliberately small.
//
// The border is a ring. `edge` is the ring's width, and the fill is
// clipped to the inside of it — the way Rectangle does it, and not a
// stroke along the fill's edge, which would put half the stroke on
// top of the fill and let the fill's antialiasing leak past it.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the item, in pixels
    float extent;   // corner reach along each edge, in pixels
    float power;    // superellipse exponent, >= 2
    float edge;     // border width, in pixels; 0 for none
    float inset;    // the shape's distance in from the item's edge, px
    float soft;     // feather, px: 0 is a crisp antialiased edge
    vec4 fill;      // fill colour at the top, premultiplied (Qt does it)
    vec4 fillEnd;   // ... and at the bottom; the same for a flat fill
    vec4 line;      // border colour at the top, premultiplied
    vec4 lineEnd;   // ... and at the bottom
};

float lnorm(vec2 v, float n) {
    return pow(pow(v.x, n) + pow(v.y, n), 1.0 / n);
}

// Negative inside, zero on the outline, positive outside. Exact to a
// pixel along the straights and through a corner of any exponent.
float sdSuperBox(vec2 p, vec2 b, float r, float n) {
    vec2 q = abs(p) - b + r;
    return lnorm(max(q, 0.0), n) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    vec2 halfSize = size * 0.5 - inset;
    float d = sdSuperBox(p, halfSize, extent, power);

    // Top of the shape to its bottom, so a gradient spans the shape
    // rather than the item around it.
    float t = clamp((p.y + halfSize.y) / max(2.0 * halfSize.y, 1e-4), 0.0, 1.0);
    vec4 f = mix(fill, fillEnd, t);
    vec4 l = mix(line, lineEnd, t);

    // Feathered: the shape's falloff spread `soft` either side of its
    // edge. A shadow is this, offset and dark.
    if (soft > 0.0) {
        fragColor = f * (1.0 - smoothstep(-soft, soft, d)) * qt_Opacity;
        return;
    }

    // A pixel and a half of falloff, not one. The distance here is a
    // superellipse's, not a circle's, and a one-pixel ramp along a
    // curve that dark against something that light lands as visible
    // steps; spread a little wider it reads as a curve.
    float aa = max(fwidth(d), 1e-4) * 1.5;
    float outer = clamp(0.5 - d / aa, 0.0, 1.0);
    float inner = clamp(0.5 - (d + edge) / aa, 0.0, 1.0);
    fragColor = (f * inner + l * (outer - inner)) * qt_Opacity;
}
