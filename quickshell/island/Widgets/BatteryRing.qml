import QtQuick
import QtQuick.Shapes

import "root:/Services"

// A ring rather than a battery outline: the arc reads as a level
// without the number and stays legible when small.
//
// Shapes, not Canvas — a ShapePath binds like anything else and
// renders on the GPU, and the sweep being a plain number is what lets
// it have a Behavior, so the ring fills rather than jumps. (This is
// not in a blurred layer, where Shapes must not be used.)

Item {
    id: root

    property int level: 0
    property bool charging: false
    property bool low: false
    // Thin enough to read as a gauge rather than a donut.
    property int thickness: Math.max(2, Math.round(width * 0.075))

    implicitWidth: 38
    implicitHeight: 38

    readonly property color ringColor:
        charging ? Theme.tertiary
        : low ? Theme.error
        : Theme.primary

    // A small gap is left at the top even at 100%: a closed circle
    // reads as a plain outline rather than as a full gauge.
    readonly property real gap: 6

    readonly property real radius:
        Math.min(width, height) / 2 - thickness / 2

    // What the arc actually sweeps. Animated, so a level arriving from
    // a poll travels rather than teleports — and so the ring is worth
    // watching while something charges.
    property real sweep: (360 - gap * 2) * Math.max(0, Math.min(1, level / 100))

    Behavior on sweep {
        NumberAnimation {
            duration: Motion.expand
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.arrive
        }
    }

    Shape {
        anchors.fill: parent
        // The default renderer falls back to software triangulation on
        // some drivers; this keeps the arc on the GPU path and is the
        // reason for preferring Shapes over Canvas at all.
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.12)
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.ringColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            // Starts at twelve o'clock and runs clockwise, which is
            // what people expect a gauge to do. PathAngleArc measures
            // from three o'clock, hence the quarter turn.
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + root.gap
                sweepAngle: root.sweep
            }
        }
    }

    // Charging shows a bolt instead of the number: the exact
    // percentage matters less than the fact that it's going up.
    Text {
        anchors.centerIn: parent
        visible: root.charging
        text: ""
        color: root.ringColor
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.height * 0.40)
        renderType: Text.NativeRendering
    }

    Text {
        anchors.centerIn: parent
        visible: !root.charging
        text: root.level
        color: root.low ? Theme.error : Theme.text
        font.family: Theme.fontMono
        // 100 needs three digits in a 38px circle, so the type has to
        // stay small; two digits get the space they'd have had anyway.
        font.pixelSize: Math.round(root.height * (root.level >= 100 ? 0.28 : 0.34))
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }
}
