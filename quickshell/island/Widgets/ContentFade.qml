import QtQuick

import "root:/Services"

// A content layer's cross-fade, choreographed against the shape.
//
//     Behavior on opacity { ContentFade { revealing: root.shown } }
//
// Content used to wait for the pill to reach 97% of its final width
// and only then fade in, which is why opening the control centre read
// as a resize followed by a screen. Here the content starts a beat
// after the shape does and is fully in well before the shape has
// settled, so the two are one movement. On the way out it leaves
// first and faster: content that is still fading while the shape
// closes over it looks like a mistake.
//
// The lead is baked into the easing curve rather than spent in a
// PauseAnimation, which keeps this a single animation — so a Behavior
// can pick its direction by binding to one boolean.

NumberAnimation {
    // True while the content is arriving.
    required property bool revealing

    duration: revealing ? Motion.contentIn : Motion.contentOut
    easing.type: Easing.BezierSpline
    easing.bezierCurve: revealing ? Motion.reveal : Motion.ease
}
