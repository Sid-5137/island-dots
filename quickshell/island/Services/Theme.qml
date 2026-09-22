pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var palette: ({})

    readonly property string background:       palette.background       ?? "#0e0e11"
    readonly property string fgOnBackground:     palette.onBackground     ?? "#e4e4e8"

    readonly property string surface:          palette.surface          ?? "#0e0e11"
    readonly property string surfaceLowest:    palette.surfaceLowest    ?? "#08080a"
    readonly property string surfaceLow:       palette.surfaceLow       ?? "#141418"
    readonly property string surfaceContainer: palette.surfaceContainer ?? "#1a1a1f"
    readonly property string surfaceHigh:      palette.surfaceHigh      ?? "#24242a"
    readonly property string surfaceHighest:   palette.surfaceHighest   ?? "#2e2e35"
    readonly property string text: {
        const c = Qt.color(palette.surface ?? "#0e0e11");
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return lum < 0.5 ? "#ffffff" : "#0b0b0d";
    }
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

    // Set on the Appearance page. The shipped names are the fallback
    // rather than the default, and they are doing real work: a font
    // that gets uninstalled after it was picked leaves the key
    // pointing at a family fontconfig cannot resolve, and a shell
    // silently drawing in Qt's default sans — with every icon a box,
    // because that font has none of them — is a much harder thing to
    // diagnose than a shell that went back to what it came with.
    readonly property string fontFamily:
        Config.appearance.fontFamily || "JetBrainsMono Nerd Font"
    readonly property string fontMono:
        Config.appearance.fontMono || "JetBrainsMono Nerd Font Mono"

    // Icons only. Every glyph in Services/Icons.qml is a codepoint in
    // this font, so anything drawing one asks for it by name instead
    // of inheriting fontFamily — which is what frees fontFamily to be
    // a proportional face.
    readonly property string fontIcons:
        Config.appearance.fontIcons || "JetBrainsMono Nerd Font"

    // The pill and what it holds. Monospace by default so the clock
    // does not change width with the time — see Config.fontIsland.
    readonly property string fontIsland:
        Config.appearance.fontIsland || "JetBrainsMono Nerd Font"

    readonly property int fontSizeSmall:  11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge:  16
    readonly property int fontSizeTitle:  22

    // The lock screen clock: display type, not text at any of the four
    // sizes above. Large enough to read from across the room, which is
    // the whole job of a clock nobody is sitting in front of.
    readonly property int fontSizeClock:  104

    // All derived from the one radius the user sets. Pick by what the
    // thing IS, not its size — Qt clamps to half the shorter side, so
    // a small control becomes a capsule on its own.
    //
    //   radiusLarge   a card: holds other things, sits on a surface
    //   radiusNormal  a panel, or a field you type into
    //   radiusSmall   a chip: one word or one glyph
    //
    // A shape in a container's corner uses none of them — see `inner`.
    // A shape that is round as a fact rather than a preference (knob,
    // slider handle, dash) is `height / 2` where it is drawn.
    readonly property int radiusSmall:
        Math.round(Config.appearance.panelRadius * 0.6)
    readonly property int radiusNormal: Config.appearance.panelRadius
    readonly property int radiusLarge:
        Math.round(Config.appearance.panelRadius * 1.2)

    readonly property int spacingSmall:  6
    readonly property int spacingNormal: 12
    readonly property int spacingLarge:  20

    // Two kinds of edge: a card sitting on the panel holds its
    // contents in by `padCard`; a row already inset by its container
    // needs less, `padRow`. Named rather than written per file, where
    // they drifted between 7 and 12 — invisible on one card, very
    // visible down a column of them.
    readonly property int padCard: 12
    readonly property int padRow:  10

    // Badge to the words beside it. Its own number: it is a gap
    // between two things rather than a margin against an edge, and
    // they should not have to change together.
    readonly property int gapBadge: 10

    // The icon column in a list row, and the box the field's caret
    // sits in above it.
    //
    // It lived in SearchMode as a local, "read by the row delegate and
    // by the field's glyph box so the two cannot drift" — which held
    // only while both were in one file. The field and the list are two
    // surfaces now, in two files, so the one number that keeps their
    // left edges on the same column has to be somewhere they both
    // already look.
    readonly property int iconRow: 22

    // The corner a shape of this height should have. One number cannot
    // serve both a 34px pill and a 374px panel, so the radius grows
    // with the shape and stops at a capsule — and since the pill's
    // height is spring-animated, the corner opens up with it for free.
    //
    //   34px -> 16 (a capsule)   374px -> 36 (matches the cards)
    function corner(h) {
        return Math.min(h / 2, Config.island.radius + h * 0.06);
    }

    // The radius a shape inset by `pad` needs to stay concentric with
    // a corner of `outer`. The rule is the subtraction and nothing
    // else: inner = outer - pad. Matching the outer radius instead
    // leaves a gap of `pad` down the straights but `pad * 1.41`
    // through the corner, which reads as the inner shape sliding out
    // diagonally.
    //
    // Clamped at zero: a shape further from the edge than the corner
    // is round is genuinely square there.
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
