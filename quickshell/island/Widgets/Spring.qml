import QtQuick

import "root:/Services"

// A spring, described the way Apple describes one, integrated per
// frame.
//
//     width: pillWidth.value
//     Spring { id: pillWidth; shape: island
//              target: island.isControl ? panel : rest }
//
// Two numbers describe it. `response` is the spring's natural period
// and reads as the speed of the thing; `bounce` is one minus the
// damping fraction — 0 settles without overshoot, 0.15 is a lift you
// feel, 0.3 is one you watch. They are the pair SwiftUI's
// `Spring(duration:bounce:)` takes, so a figure read off Apple's
// documentation means here what it means there.
//
// Why a spring and not an easing curve. A curve is a function of one
// variable — how far through it is — and so it cannot know that the
// property was already moving when it started, or how fast. Reverse a
// Behavior mid-flight and Qt restarts it from a standstill at
// whatever value it had reached, which is the hitch you see when you
// brush the pill and leave again, or open the control centre and shut
// it before it has arrived. A spring carries its velocity through the
// reversal. That continuity is most of what makes motion feel
// attached to the pointer rather than played at it, and it is the
// reason this is not a `Behavior`: a Behavior owns a start and an
// end, and a spring has neither.
//
// The step below is the closed-form solution of the damped
// oscillator, evaluated at the frame's own dt, not an integrator
// stepping toward one. So the motion is identical at 60Hz and at
// 240Hz, and a dropped frame costs a frame rather than changing the
// curve. Qt's own SpringAnimation exists but steps a fixed 16ms
// Euler — measured against it, every morph on this 120Hz panel would
// run at 62.5.

QtObject {
    id: root

    // Whatever declares `springResponse` and `springBounce`: the
    // island, a pod, the settings window. The shape being moved is
    // the only thing that knows which way it is going — opening and
    // closing are different events, not one curve run backwards — so
    // it says, and every spring on it reads the same pair. Optional:
    // set response and bounce directly for a one-off.
    property var shape: null

    // Where it is going.
    property real target: 0

    // Milliseconds and a fraction, as everything else here is.
    property real response: shape ? shape.springResponse : Motion.expandResponse
    property real bounce: shape ? shape.springBounce : Motion.arriveBounce

    // A shape that collapses to nothing must not overshoot past it: a
    // negative width anchored to the pill's edge draws backwards over
    // the pill. Only the value read out is clamped — the oscillator
    // keeps its true state, so it still settles from where it really
    // is rather than from where it was allowed to be seen.
    property real minimum: -Infinity
    property real maximum: Infinity

    // Reduce Motion takes the springs and leaves the cross-fades. See
    // Services/Motion.qml for why that division is the one that
    // matters.
    property bool enabled: !Motion.reduced

    // The oscillator's true state.
    property real position: 0
    property real velocity: 0

    // What the animated property binds to.
    readonly property real value:
        Math.max(minimum, Math.min(maximum, position))

    readonly property bool moving: driver !== null && driver.running

    // A Behavior does not animate the binding it was created with,
    // and neither does this. Without it every shape in the shell
    // springs up out of zero on the first frame after launch.
    property bool ready: false

    // The distance the current move covers, for the settle threshold
    // below: a width crossing four hundred pixels and a scale
    // crossing a fifth of one cannot share a single epsilon.
    property real span: 0

    onTargetChanged: {
        if (!ready || !enabled) {
            settle();
            return;
        }
        span = Math.max(span, Math.abs(target - position));
        if (driver && !driver.running) driver.start();
    }

    onEnabledChanged: if (!enabled) settle()

    function settle() {
        if (driver) driver.stop();
        velocity = 0;
        span = 0;
        position = target;
    }

    function advance(dt) {
        const w0 = 2 * Math.PI / Math.max(0.001, response / 1000);
        const zeta = Math.max(0.0001, Math.min(1, 1 - bounce));

        // Solved about the target, so `e` is the error and the target
        // may move under it without the solution having to restart.
        let e = position - target;
        let v = velocity;
        const decay = Math.exp(-zeta * w0 * dt);

        if (zeta < 0.9999) {
            const wd = w0 * Math.sqrt(1 - zeta * zeta);
            const a = e;
            const b = (v + zeta * w0 * e) / wd;
            const c = Math.cos(wd * dt);
            const s = Math.sin(wd * dt);

            e = decay * (a * c + b * s);
            v = decay * ((wd * b - zeta * w0 * a) * c
                         - (zeta * w0 * b + wd * a) * s);
        } else {
            // Critically damped: the oscillatory pair collapses to a
            // repeated root, and cos/sin would divide by a zero wd.
            const a = e;
            const b = v + w0 * e;

            e = decay * (a + b * dt);
            v = decay * (b - w0 * (a + b * dt));
        }

        const eps = Math.max(0.0001, span * 0.002);
        if (Math.abs(e) < eps && Math.abs(v) < eps * 10) {
            settle();
            return;
        }

        velocity = v;
        position = target + e;
    }

    property FrameAnimation driver: FrameAnimation {
        running: false
        // A stall — the screen locked, the compositor suspended, a
        // wallpaper being decoded — must not arrive as one enormous
        // step that flings the shape across the screen.
        onTriggered: root.advance(Math.min(frameTime, 0.05))
    }

    Component.onCompleted: {
        position = target;
        ready = true;
    }
}
