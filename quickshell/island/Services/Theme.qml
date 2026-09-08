pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Theme
//
// Watches colors.json, which matugen regenerates on every wallpaper
// change. Everything the shell draws binds to these properties, so
// a new wallpaper retints the whole UI without anything else
// knowing matugen exists.
//
// Colors are declared as `string`, not `color`. QML accepts a hex
// string anywhere a color is expected, and this avoids type
// coercion surprises when a value arrives from JSON.
//
// The `?? fallback` on each keeps the shell rendering before the
// first matugen run, and survives a malformed or half-written file.
// ─────────────────────────────────────────────────────────────

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

    // ── Colors ───────────────────────────────────────────────

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

    // ── Type ─────────────────────────────────────────────────

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontMono:   "JetBrainsMono Nerd Font Mono"

    readonly property int fontSizeSmall:  11
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeLarge:  16
    readonly property int fontSizeTitle:  22

    // ── Geometry ─────────────────────────────────────────────

    readonly property int radiusSmall:  8
    readonly property int radiusNormal: 14
    readonly property int radiusLarge:  24

    readonly property int spacingSmall:  6
    readonly property int spacingNormal: 12
    readonly property int spacingLarge:  20

    // ── Motion ───────────────────────────────────────────────

    readonly property int durationFast:   150
    readonly property int durationNormal: 300
    readonly property int durationSlow:   450

    readonly property int easingIsland:   Easing.OutBack
    readonly property int easingStandard: Easing.OutCubic

    // ── Source ───────────────────────────────────────────────

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/island-dots/quickshell/island/colors.json"

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
