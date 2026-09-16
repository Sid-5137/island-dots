pragma Singleton

import Quickshell
import QtQuick

// The island's motion, in one place.
//
// Everything used to animate with `Easing.OutBack, overshoot 0.6` over
// 250ms, in both directions, while the content inside waited for the
// pill to reach 97% of its final width before fading in. That is why
// it read as a resize followed by a screen rather than as one object
// changing shape: OutBack's overshoot is a single hard kick with an
// abrupt settle, closing bounced exactly as much as opening did, and
// the content never moved with the shape — it arrived after the shape
// had stopped.
//
// What the real Dynamic Island does instead, and what this implements:
//
//   · Springs, not eases. A damped second-order step response: one
//     small overshoot, then it settles.
//   · Asymmetry. Opening springs; closing does not. A spring on
//     dismissal reads as the interface arguing with you.
//   · Choreography. The shape leads by a beat and the content follows
//     into it; on the way out the content leaves first, and faster
//     than it arrived.
//
// The numbers come from Apple's spring parameterisation, which
// describes a spring as `response` (its natural period) and
// `dampingFraction` (zeta, how far it overshoots), and from the motion
// spec NotchKit publishes for its Dynamic Island reimplementation:
//
//   expand   spring(response 0.42, damping 0.80)
//   collapse smooth  0.30s, no overshoot
//   hover    spring(response 0.38, damping 0.80)
//   peek     spring(response 0.30, damping 0.50)
//   content  0.08s lead, 0.22s in, 0.12s out
//
//   https://github.com/duongductrong/NotchKit/blob/master/docs/motion.md
//
// Qt has no spring easing, and SpringAnimation is a toy model with a
// "useful range 0-5" dial rather than a physical one — so the step
// response is sampled here and handed to Qt as a bezier spline. The
// physics stays in the source rather than becoming a wall of baked
// control points, which means the numbers worth arguing about — zeta,
// and how long you let it settle — are the ones you can see.

Singleton {
    id: root

    // ── Sampling a curve Qt will actually take ───────────────
    //
    // Two rules, both learned by crashing the shell rather than by
    // reading anything. Qt does not reject a bezier spline that breaks
    // them, and it does not warn: it takes the whole process down the
    // first time something animates.
    //
    //   1. Every segment must be the same width in x. A spline of
    //      twelve narrow segments and one wide one is fatal.
    //   2. Segment endpoints must never step back down in y. Control
    //      points may go anywhere they like — above 1, below the
    //      endpoints either side of them — and that is where the whole
    //      overshoot has to live.
    //
    // So: uniform segments, endpoints clamped to the target and to
    // whatever came before them, and each segment fitted exactly
    // through the curve at its own third points. Two interior points
    // is precisely the freedom a cubic has once its ends are fixed,
    // so the fit is a 2x2 solve rather than a search.
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

    // ── The spring ───────────────────────────────────────────

    // Unit step response of a damped second-order system.
    //
    //   zeta < 1  underdamped: overshoots, then rings down
    //   zeta = 1  critically damped: the fastest approach with no
    //             overshoot at all
    //   zeta > 1  overdamped: slower, and still no overshoot
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

    // An easing curve shaped like a spring.
    //
    //   zeta  the damping fraction, as Apple defines it
    //   span  how many natural periods the animation runs for. The
    //         curve is normalised to its own duration, so this only
    //         decides how much of the settle you keep — enough that
    //         the tail is imperceptible, no more.
    //
    // The clamp in sample() costs the ring-down: between the first
    // overshoot and the target the curve returns to 1 rather than
    // tracking the oscillation home. The peak survives, which is the
    // part you can see, and a UI is better off without the rest.
    function springCurve(zeta, span) {
        const w0 = 2 * Math.PI;    // response of 1, so t is in periods
        return sample(u => step(u * span, zeta, w0));
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

    // ── The curves ───────────────────────────────────────────

    // Arrivals: one overshoot of about one and a half percent, then it
    // settles. Small enough that you feel it rather than watch it.
    readonly property var arrive:
        springCurve(Config.motion.arriveDamping, 1.10)

    // Departures: critically damped, so a shape on its way out never
    // springs back toward where it came from.
    readonly property var settle: springCurve(1.0, 1.15)

    // A pop that wants to be noticed. For a pod peeking at you, and
    // for nothing that carries text you are meant to read while it
    // moves.
    readonly property var pop: springCurve(Config.motion.popDamping, 1.40)

    // Fast out, slow in, one segment. For anything that is a
    // cross-fade rather than a shape.
    readonly property var ease: [0.22, 0.0, 0.36, 1.0, 1.0, 1.0]

    // The content's arrival, with its lead in front of it.
    readonly property var reveal: leadCurve(Config.motion.contentLead,
                                            contentIn)

    // ── Tempo ────────────────────────────────────────────────
    //
    // Eleven sliders describe motion exactly and answer the wrong
    // question. Nobody wants to set a content lead; they want the
    // thing to feel quicker. So the eleven are grouped into three
    // tempos, and the sliders stay underneath for whoever does want
    // to set a content lead.
    //
    // `fluid` is measured rather than invented. Sampling saneAspect's
    // Dynamite V3 at 60fps — the panel's height in a column of pixels,
    // frame by frame — its control centre opens in about 180ms and
    // overshoots its final height by 1.4%, which is a damping fraction
    // of roughly 0.8. That is the same spring this already used. The
    // only thing that differed was the clock: 460ms against his 180.
    // Two and a half times slower is the whole of the difference
    // between motion you feel and motion you wait for.
    //
    //   https://www.youtube.com/watch?v=Ob98KFByTec
    //
    // `calm` is what shipped before, kept because a large panel
    // crossing a large screen is a different proposition from a phone
    // notch and some people will want the extra beat. `springy` keeps
    // the tempo and spends the damping instead: 0.62 is an overshoot
    // you watch rather than feel.
    readonly property var tempos: ({
        fluid: {
            expandDuration: 240, collapseDuration: 200,
            hoverDuration: 200,  popDuration: 300,
            arriveDamping: 0.78, popDamping: 0.55,
            contentLead: 40, contentInDuration: 150,
            contentOutDuration: 90,
            fadeIn: 90, fadeOut: 60
        },
        calm: {
            expandDuration: 460, collapseDuration: 300,
            hoverDuration: 380,  popDuration: 420,
            arriveDamping: 0.80, popDamping: 0.50,
            contentLead: 80, contentInDuration: 220,
            contentOutDuration: 120,
            fadeIn: 120, fadeOut: 70
        },
        springy: {
            expandDuration: 300, collapseDuration: 220,
            hoverDuration: 240,  popDuration: 340,
            arriveDamping: 0.62, popDamping: 0.42,
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

    readonly property bool reduced: Config.motion.reduceMotion

    readonly property int expand:
        reduced ? 0 : Config.motion.expandDuration
    readonly property int collapse:
        reduced ? 0 : Config.motion.collapseDuration
    readonly property int hover:
        reduced ? 0 : Config.motion.hoverDuration
    readonly property int peek:
        reduced ? 0 : Config.motion.popDuration

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

    // How far a pod leans out of the way while it is absent. Reduce
    // Motion flattens it, per the note above.
    readonly property real absentScale: reduced ? 1.0 : 0.82
}
