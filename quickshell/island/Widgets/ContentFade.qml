import QtQuick

import "root:/Services"

// A content layer's cross-fade, choreographed against the shape.
//
//     Behavior on opacity { ContentFade { revealing: root.shown } }
//
// Content starts a beat after the shape and is fully in before it
// settles, so the two read as one movement. On the way out it leaves
// first and faster.
//
// The lead is baked into the easing curve rather than spent in a
// PauseAnimation, so this stays a single animation and a Behavior can
// pick its direction from one boolean.

NumberAnimation {
    // True while the content is arriving.
    required property bool revealing

    duration: revealing ? Motion.contentIn : Motion.contentOut
    easing.type: Easing.BezierSpline
    easing.bezierCurve: revealing ? Motion.reveal : Motion.ease
}
