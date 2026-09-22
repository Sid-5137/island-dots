pragma Singleton

import Quickshell
import QtQuick

// The island's motion, in one place.
//
// Every shape in the shell moves on a spring described the way Apple
// describes one: a **response**, which is the spring's natural period
// and reads as the speed of the thing, and a **bounce**, which is one
// minus the damping fraction. That is the pair SwiftUI's
// `Spring(duration:bounce:)` takes, so a figure read off Apple's
// documentation means here what it means there:
//
//     .smooth   bounce 0      settles without overshoot
//     .snappy   bounce 0.15   a lift you feel
//     .bouncy   bounce 0.30   one you watch
//
// The bounces below are those three exactly. The responses are not:
// SwiftUI's named springs all run at half a second, which is a phone
// animation and reads as slow on a shell you drive with a pointer.
// macOS's own chrome runs nearer a quarter second — a menu, a
// popover, Control Centre — and so does this, which is also where the
// island already was when it was measured against Dynamite V3.
//
// Two engines, and the split is deliberate:
//
//   Widgets/Spring.qml   the shapes. Integrated per frame from the
//                        response and bounce below, so a reversal
//                        carries its velocity through instead of
//                        restarting from a standstill.
//
//   the curves below     everything small enough that interrupting
//                        it is not a thing you can see: a toggle
//                        knob, a row highlight, a button's press.
//                        Sampled from the same spring, so the
//                        character matches, and a great deal cheaper
//                        than a physics step per frame per control.
//
// Fades are easings in both cases. A cross-fade has no velocity to
// carry and no overshoot to spend, and Apple eases those too.

Singleton {
    id: root

    // ── Sampling a spring into a bezier ──────────────────────
    //
    // Qt has no spring easing, so the step response is sampled into a
    // bezier spline here. Only the curves below use this; Spring.qml
    // solves the same system in closed form instead.

    // Qt segfaults on a bezier spline whose segments differ in width
    // or whose endpoints step back down in y — no warning, no
    // validation. Uniform segments, endpoints clamped non-decreasing,
    // overshoot carried by the control points. Do not "simplify".
    readonly property int segments: 8

    function sample(fn) {
        const n = segments;
        const h = 1 / n;

        const knots = [0];
        for (let i = 1; i <= n; i++)
            knots.push(Math.max(knots[i - 1], Math.min(1, fn(i * h))));
        knots[n] = 1;

        const out = [];
        for (let i = 0; i < n; i++) {
            const x = i * h, p0 = knots[i], p3 = knots[i + 1];
            const a = 27 * fn(x + h / 3) - 8 * p0 - p3;
            const b = 27 * fn(x + 2 * h / 3) - p0 - 8 * p3;
            out.push(x + h / 3, (2 * a - b) / 18,
                     x + 2 * h / 3, (2 * b - a) / 18,
                     x + h, p3);
        }

        // Qt insists the spline ends exactly at (1, 1). Float drift
        // otherwise leaves the property a fraction short of its
        // target, permanently.
        out[out.length - 2] = 1;
        out[out.length - 1] = 1;
        return out;
    }

    // Unit step response of a damped second-order system. zeta < 1
    // overshoots then rings down; >= 1 approaches without overshoot.
    // The same system Spring.qml solves — this one only has to be
    // evaluated at fixed points rather than at an arbitrary dt.
    function step(t, zeta, w0) {
        const decay = Math.exp(-zeta * w0 * t);

        if (zeta < 0.999) {
            const wd = w0 * Math.sqrt(1 - zeta * zeta);
            return 1 - decay * (Math.cos(wd * t)
                                + (zeta * w0 / wd) * Math.sin(wd * t));
        }
        if (zeta < 1.001)
            return 1 - decay * (1 + w0 * t);

        const a = w0 * Math.sqrt(zeta * zeta - 1);
        return 1 - decay * (Math.cosh(a * t)
                            + (zeta * w0 / a) * Math.sinh(a * t));
    }

    // An easing curve shaped like a spring of the given bounce.
    // sample()'s clamp costs the ring-down; the peak survives, which
    // is the part you can see.
    function springCurve(bounce) {
        const w0 = 2 * Math.PI;    // response of 1, so t is in periods
        const zeta = Math.max(0.0001, Math.min(1, 1 - bounce));
        return sample(u => step(u * tail, zeta, w0));
    }

    // A curve that holds at zero for `lead` of its duration, then eases
    // in over what is left.
    //
    // The content's head start, baked into the easing rather than
    // spent in a PauseAnimation — which keeps a fade one animation, so
    // a Behavior can pick its direction by binding to one boolean.
    function leadCurve(lead, total) {
        const f = Math.max(0, Math.min(0.8, total > 0 ? lead / total : 0));

        return sample(function(u) {
            if (u <= f) return 0;
            const v = (u - f) / (1 - f);
            return 1 - Math.pow(1 - v, 3);
        });
    }

    // ── The spring ───────────────────────────────────────────
    //
    // What Widgets/Spring.qml reads. Milliseconds and a fraction.

    readonly property int expandResponse: Config.motion.expandResponse
    readonly property int collapseResponse: Config.motion.collapseResponse
    readonly property int hoverResponse: Config.motion.hoverResponse
    readonly property int popResponse: Config.motion.popResponse

    // Arrivals get Apple's `.snappy`. Departures spring too — macOS
    // never simply stops a shape — but with most of the bounce taken
    // out of them, because half of what the island dismisses is
    // collapsing to nothing and an overshoot past nothing is a
    // negative width. Spring.qml clamps the rest; this keeps it from
    // needing to.
    readonly property real arriveBounce: Config.motion.arriveBounce
    readonly property real departBounce: Config.motion.departBounce

    // A pop that wants to be noticed. For a pod peeking at you, and
    // for nothing that carries text you are meant to read while it
    // moves.
    readonly property real popBounce: Config.motion.popBounce

    // ── The curves ───────────────────────────────────────────
    //
    // The same springs, sampled, for the small controls. `tail` is how
    // many natural periods the sample runs for: the spring is
    // normalised to its own duration, so this only decides how much of
    // the settle a curve keeps, and the duration a call site asks for
    // is the response with that tail on it.

    readonly property real tail: 1.15

    readonly property var arrive: springCurve(arriveBounce)
    readonly property var settle: springCurve(departBounce)

    // Fast out, slow in, one segment. For anything that is a
    // cross-fade rather than a shape.
    readonly property var ease: [0.22, 0.0, 0.36, 1.0, 1.0, 1.0]

    // The content's arrival, with its lead in front of it.
    readonly property var reveal: leadCurve(Config.motion.contentLead,
                                            contentIn)

    // ── Tempo ────────────────────────────────────────────────
    //
    // Twelve sliders describe motion exactly and answer the wrong
    // question, so they are grouped into three — Apple's three, by
    // name, because the bounce in each is Apple's number for it. The
    // sliders stay underneath.
    readonly property var tempos: ({
        smooth: {
            expandResponse: 280, collapseResponse: 230,
            hoverResponse: 210,  popResponse: 300,
            arriveBounce: 0.0, departBounce: 0.0, popBounce: 0.25,
            contentLead: 40, contentInDuration: 150,
            contentOutDuration: 90,
            fadeIn: 90, fadeOut: 60
        },
        snappy: {
            expandResponse: 240, collapseResponse: 190,
            hoverResponse: 180,  popResponse: 280,
            arriveBounce: 0.15, departBounce: 0.05, popBounce: 0.40,
            contentLead: 40, contentInDuration: 150,
            contentOutDuration: 90,
            fadeIn: 90, fadeOut: 60
        },
        bouncy: {
            expandResponse: 260, collapseResponse: 200,
            hoverResponse: 190,  popResponse: 300,
            arriveBounce: 0.30, departBounce: 0.10, popBounce: 0.50,
            contentLead: 40, contentInDuration: 160,
            contentOutDuration: 90,
            fadeIn: 90, fadeOut: 60
        }
    })

    // Which tempo the current numbers are, or "custom" once a slider
    // has been moved. Derived rather than stored: a stored name and a
    // set of numbers are two sources of truth for one fact, and they
    // disagree the moment settings.json is edited by hand.
    readonly property string tempo: {
        for (const name of Object.keys(tempos)) {
            const t = tempos[name];
            let match = true;
            for (const key of Object.keys(t)) {
                const a = t[key], b = Config.motion[key];
                // Reals need a tolerance; ints do not, and comparing
                // them loosely would call 240 and 241 the same tempo.
                if (Math.abs(a - b) > (Number.isInteger(a) ? 0 : 0.001)) {
                    match = false;
                    break;
                }
            }
            if (match) return name;
        }
        return "custom";
    }

    function setTempo(name) {
        const t = tempos[name];
        if (!t) return;
        for (const key of Object.keys(t))
            Config.motion[key] = t[key];
    }

    // ── The clock ────────────────────────────────────────────
    //
    // Reduce Motion takes the springs and the shape morphs away and
    // leaves the cross-fades, which are not a vestibular trigger. It
    // is the one preference here that is not a matter of taste.
    //
    // Spring.qml reads this itself and snaps rather than solving; the
    // durations below are for the curve call sites, which have no
    // other way to be told.

    readonly property bool reduced: Config.motion.reduceMotion

    readonly property int expand:
        reduced ? 0 : Math.round(expandResponse * tail)
    readonly property int collapse:
        reduced ? 0 : Math.round(collapseResponse * tail)
    readonly property int hover:
        reduced ? 0 : Math.round(hoverResponse * tail)

    // Lead plus reveal: the content is fully in well before the shape
    // has finished, which is what makes the two read as one movement
    // rather than as a resize and then a screen.
    readonly property int contentIn:
        Config.motion.contentLead + Config.motion.contentInDuration

    // Quicker than the way in, and never delayed. Content that is
    // still fading while the shape closes over it looks like a
    // mistake.
    readonly property int contentOut: Config.motion.contentOutDuration

    // Small cross-fades that are not part of a morph: a colour
    // changing, an indicator appearing.
    readonly property int fadeIn: Config.motion.fadeIn
    readonly property int fadeOut: Config.motion.fadeOut

    // ── Presentation ─────────────────────────────────────────
    //
    // A surface arriving does not only fade in: it grows the last
    // fraction of the way, anchored at the edge it came from, so it
    // reads as emerging from the shape rather than being laid over
    // it. That is the macOS presentation everywhere from a popover to
    // Notification Centre, and the number is small on purpose —
    // enough to feel, not enough to be a zoom.
    //
    // Reduce Motion flattens it, per the note above.
    readonly property real emergeScale:
        reduced ? 1.0 : Config.motion.emergeScale

    // How far a pod leans out of the way while it is absent.
    readonly property real absentScale: reduced ? 1.0 : 0.82
}
