pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var palette: ({})

    // Prints once at startup. Remove when you're done debugging.
    Component.onCompleted: {
        console.log("[Theme] keys:", Object.keys(root.palette).length,
                    "onSurface:", root.text,
                    "onSurfaceVariant:", root.textDim,
                    "primary:", root.primary)
    }

    readonly property string background:       palette.background       ?? "#0e0e11"
    readonly property string fgOnBackground:     palette.onBackground     ?? "#e4e4e8"

    readonly property string surface:          palette.surface          ?? "#0e0e11"
    readonly property string surfaceLowest:    palette.surfaceLowest    ?? "#08080a"
    readonly property string surfaceLow:       palette.surfaceLow       ?? "#141418"
    readonly property string surfaceContainer: palette.surfaceContainer ?? "#1a1a1f"
    readonly property string surfaceHigh:      palette.surfaceHigh      ?? "#24242a"
    readonly property string surfaceHighest:   palette.surfaceHighest   ?? "#2e2e35"
    readonly property string text:        palette.onSurface        ?? "#e4e4e8"
    readonly property string textDim: palette.onSurfaceVariant ?? "#c2c2ca"

    readonly property string primary:          palette.primary          ?? "#e8e8ec"
    readonly property string textOnPrimary:        palette.onPrimary        ?? "#111114"
    readonly property string secondary:        palette.secondary        ?? "#b8b8c0"
    readonly property string tertiary:         palette.tertiary         ?? "#9a9aa4"
    readonly property string error:            palette.error            ?? "#ffb4ab"
    readonly property string textOnError:          palette.onError          ?? "#690005"
    readonly property string outline:          palette.outline          ?? "#55555e"
    readonly property string outlineVariant:   palette.outlineVariant   ?? "#2a2a30"

    // The lit half of an edge — see Widgets/Bezel.qml, which draws it.
    // Deliberately not a palette entry: it is a highlight rather than
    // a hue, and matugen has no opinion about how much light lands on
    // a corner. A wash also survives a light palette, where an
    // outlineVariant scaled down would go muddy rather than bright.
    // Bright enough to clear the fill by about thirty levels, which is
    // what it takes for the gap between it and the outer hairline to
    // register as a gap rather than as antialiasing.
    readonly property color bezel: Qt.rgba(1, 1, 1, 0.14)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontMono:   "JetBrainsMono Nerd Font Mono"

    readonly property int fontSizeSmall:  11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge:  16
    readonly property int fontSizeTitle:  22

    // ── Shape ────────────────────────────────────────────────
    //
    // Derived from the one radius the user actually sets, so moving
    // that slider moves everything together. They used to be three
    // constants that nothing referenced — 8, 14 and 24, sitting beside
    // twenty-one literal `radius: 8`s in the files that needed one.
    //
    // Which of the three a shape gets is a question about what kind of
    // thing it is, not about how big it is. Size is already in the
    // answer, because Qt clamps a radius to half the shorter side: at a
    // large setting a 28px button quietly becomes a capsule while the
    // panel behind it stays a rounded rectangle, which is exactly the
    // right outcome and costs nothing to arrange.
    //
    //   radiusLarge   a card — something that holds other things and
    //                 sits on a surface. Control-centre cards, a
    //                 selected row in a list, overview and picker
    //                 cards, an icon tile, a popup.
    //   radiusNormal  a panel, or a field you type into. The settings
    //                 window and its sidebar, a segmented control, a
    //                 password box.
    //   radiusSmall   a chip — a small control holding one word or one
    //                 glyph. Buttons, tabs, a thumbnail inside a card.
    //
    // None of the three applies to a shape that sits in a container's
    // corner — a row at either end of a list, a field along the bottom
    // of a popup. That shape's radius is not a question of what kind
    // of thing it is at all; it is fixed by the corner it is sitting
    // in and how far inside it sits. See `inner` below.
    //
    // There is a fifth case, and it is deliberately not a token: a
    // shape whose roundness is a fact about the shape rather than a
    // preference. A toggle knob, a slider handle, a workspace dash, the
    // cap on a 3px tick — those are `height / 2` written where they are
    // drawn. `radius: 1.5` beside `width: 3` is the same number with
    // the reason taken out of it, and it stops being a capsule the
    // moment somebody changes the 3.
    readonly property int radiusSmall:
        Math.round(Config.appearance.panelRadius * 0.6)
    readonly property int radiusNormal: Config.appearance.panelRadius
    readonly property int radiusLarge:
        Math.round(Config.appearance.panelRadius * 1.2)

    readonly property int spacingSmall:  6
    readonly property int spacingNormal: 12
    readonly property int spacingLarge:  20

    // ── Inset ────────────────────────────────────────────────
    //
    // Two numbers, because there are two kinds of edge. A card in the
    // control centre sits on the panel and holds its contents in by
    // `padCard`; a row inside a card or a page is already inset by its
    // container and needs less, `padRow`.
    //
    // Named because they were 7, 8, 9, 10, 11 and 12 depending on who
    // wrote the file — which is invisible on any one card and very
    // visible down a column of them, where a badge starting at 9 sits
    // beside a label starting at 12.
    readonly property int padCard: 12
    readonly property int padRow:  10

    // Badge to the words beside it. Its own number: it is a gap
    // between two things rather than a margin against an edge, and
    // they should not have to change together.
    readonly property int gapBadge: 10

    // The corner a shape of this height should have.
    //
    // One number cannot serve both ends of a shape that morphs from a
    // 34px pill to a 374px panel. At 14 the pill is three pixels short
    // of a capsule — close enough to look like a mistake rather than a
    // decision — and the panel gets the same 14, which on something
    // ten times taller reads as a hard corner with a chamfer.
    //
    // So the radius grows with the shape and stops at a capsule. The
    // pill's height is already spring-animated, which means the corner
    // opens up as the shape does, for free.
    //
    //   34px  ->  16   (a capsule, near enough)
    //   40px  ->  16
    //   374px ->  36   (generous, and it matches the cards inside)
    function corner(h) {
        return Math.min(h / 2, Config.island.radius + h * 0.06);
    }

    // The corner a shape inset by `pad` inside a corner of `outer`
    // should have, so that the two curves stay concentric.
    //
    // Two rounded rectangles only look nested if their arcs share a
    // centre. Give the inner one the same radius as the outer and the
    // gap between them is `pad` down the straights but `pad * 1.41`
    // through the corner, so the inner shape appears to slide out of
    // the corner diagonally. Give it a radius picked by eye and it is
    // the same fault with a different number — which is what the shell
    // was doing: the launcher drew radius-17 rows twelve pixels inside
    // a panel whose corner is 36, and the notification centre drew the
    // same 17 sixteen pixels inside a corner of 40. Both read as cards
    // borrowed from a squarer window and dropped into a round one,
    // because that is exactly what they were.
    //
    // The rule is the subtraction and nothing else: inner = outer -
    // pad. Apple shipped it as ConcentricRectangle in iOS 26 and as
    // the reason Spotlight's rows look carved out of Spotlight rather
    // than laid on it; it was a drafting convention long before that,
    // because it is what concentric means.
    //
    // Clamped at zero, because a shape further from the edge than the
    // corner is round is square there. That is not a degenerate case
    // to be papered over with a minimum — it is why one result in the
    // launcher gets a nearly square card and eight results get a
    // visibly round one. Same panel corner, read from two distances.
    function inner(outer, pad) {
        return Math.max(0, outer - pad);
    }

    // Durations and easings used to live here too. Motion is a spring
    // now and the whole vocabulary is in Services/Motion.qml, which is
    // where anything animating should look — these were four constants
    // describing a model the shell no longer uses.

    FileView {
        id: colorFile
        path: Paths.colors

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                root.palette = JSON.parse(colorFile.text());
                console.log("[Theme] loaded", Object.keys(root.palette).length, "colors");
            } catch (e) {
                console.warn("[Theme] colors.json is not valid JSON —", e);
            }
        }

        onLoadFailed: {
            console.log("[Theme] no colors.json yet, using fallbacks");
        }
    }
}
