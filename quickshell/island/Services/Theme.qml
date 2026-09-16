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
