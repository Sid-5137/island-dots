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

    // For content that arrives as something else leaves the same
    // space — the pill's clock after a panel. Waits for the other to
    // go before it starts. See Motion.revealLate.
    property bool late: false

    duration: revealing ? (late ? Motion.contentInLate : Motion.contentIn)
                        : Motion.contentOut
    easing.type: Easing.BezierSpline
    easing.bezierCurve: revealing ? (late ? Motion.revealLate : Motion.reveal)
                                  : Motion.ease
}
