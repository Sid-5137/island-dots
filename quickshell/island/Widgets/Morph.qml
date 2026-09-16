import QtQuick

// The island's shape morph, as one line at the call site.
//
//     Behavior on width { Morph { shape: island } }
//
// Direction is what an easing curve cannot work out for itself, and
// it is the whole difference between a shape that springs open and
// one that bounces shut. So the item being morphed declares where it
// is going — `morphTime` and `morphCurve` — and every Behavior on it
// reads the same pair. See Services/Motion.qml for the curves, and
// Island.qml and Pods/Pod.qml for the two places that decide.

NumberAnimation {
    // Whatever declares morphTime and morphCurve: the island, or a pod.
    required property var shape

    duration: shape.morphTime
    easing.type: Easing.BezierSpline
    easing.bezierCurve: shape.morphCurve
}
