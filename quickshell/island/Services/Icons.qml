pragma Singleton

import Quickshell
import QtQuick

// Every icon the shell draws, named once, and the font they come from.
//
// Tabler Icons (tabler.io, MIT), cut down to exactly this list by
// packages/tabler-icons/build.py and loaded from beside this file. No
// font has to be installed for them, and no other font is asked for
// one: one family, one 24-unit grid, one stroke.
//
// Each entry is a codepoint with Tabler's name beside it. The name is
// the part that is checked — build.py refuses to cut the font if a
// codepoint is not the one Tabler gives that name, so a mistyped one
// fails the build instead of quietly drawing some other picture. A
// name ending -filled comes from Tabler's filled set.
//
// Adding one: find it at tabler.io/icons, add a line here, and run
// packages/tabler-icons/build.py. A codepoint that is not listed
// here is not in the font, and draws nothing.
//
// Not in here: "×", "•", "❯", "↺", "⌄" — typography, from the text
// font, and not at risk when the icon set changes.

Singleton {
    id: root

    // The family every icon Text asks for; Theme.fontIcons is this.
    //
    // A stroke width is a separate file rather than a weight: build.py
    // strokes Tabler's paths at each width into its own regular-weight
    // font, so font.weight has nothing to select, and asking for Bold
    // only gets FreeType emboldening the outlines. Each file carries
    // its own family name, so switching loads the other one instead of
    // resolving to whichever was registered first.
    readonly property string family: loader.name

    FontLoader {
        id: loader
        source: Qt.resolvedUrl(Config.appearance.iconStroke === "2"
            ? "tabler-2.ttf" : "tabler-2.5.ttf")
    }

    // Codepoints rather than the characters: newer Tabler icons sit
    // past U+FFFF, which a QML string can only spell as a pair of
    // escapes, and a pair is neither readable nor searchable.
    function glyph(cp) { return String.fromCodePoint(cp); }

    // ── Sound ────────────────────────────────────────────────
    readonly property string volumeMuted:  glyph(0x0EB50)  // ti-volume-3
    readonly property string volumeHigh:   glyph(0x0EB51)  // ti-volume
    readonly property string volumeMedium: glyph(0x0EB4F)  // ti-volume-2
    readonly property string volumeLow:    glyph(0x1019D)  // ti-volume-4

    readonly property string micOn:        glyph(0x0EAF0)  // ti-microphone
    readonly property string micOff:       glyph(0x0ED16)  // ti-microphone-off

    readonly property string brightness:   glyph(0x0EB30)  // ti-sun

    // ── Media ────────────────────────────────────────────────
    //
    // Filled, where everything else is outline: a transport control
    // is a button you aim at, and an outlined triangle at 12px is
    // three hairlines rather than a shape.
    readonly property string music:    glyph(0x0EAFC)  // ti-music
    readonly property string play:     glyph(0x0F691)  // ti-player-play-filled
    readonly property string pause:    glyph(0x0F690)  // ti-player-pause-filled
    readonly property string previous: glyph(0x0F693)  // ti-player-skip-back-filled
    readonly property string next:     glyph(0x0F694)  // ti-player-skip-forward-filled

    // ── Battery ──────────────────────────────────────────────
    readonly property string batteryCharging: glyph(0x0EA38)  // ti-bolt
    readonly property string batteryFull:     glyph(0x0EA32)  // ti-battery-4
    readonly property string batteryHigh:     glyph(0x0EA31)  // ti-battery-3
    readonly property string batteryHalf:     glyph(0x0EA30)  // ti-battery-2
    readonly property string batteryLow:      glyph(0x0EA2F)  // ti-battery-1
    readonly property string batteryEmpty:    glyph(0x0EA34)  // ti-battery

    // ── Network ──────────────────────────────────────────────
    readonly property string wifi:     glyph(0x0EB52)  // ti-wifi
    readonly property string ethernet: glyph(0x0F09F)  // ti-network

    // Signal, counted in bars. Tabler counts arcs above the dot, so
    // its numbers run one behind these.
    readonly property string wifi1: glyph(0x0EBA3)  // ti-wifi-0
    readonly property string wifi2: glyph(0x0EBA4)  // ti-wifi-1
    readonly property string wifi3: glyph(0x0EBA5)  // ti-wifi-2
    readonly property string wifi4: glyph(0x0EB52)  // ti-wifi

    readonly property string secure: glyph(0x0EAE2)  // ti-lock

    // ── Bluetooth ────────────────────────────────────────────
    readonly property string bluetooth:          glyph(0x0EA37)  // ti-bluetooth
    readonly property string bluetoothConnected: glyph(0x0ECEA)  // ti-bluetooth-connected

    // ── Session ──────────────────────────────────────────────
    readonly property string lock:     glyph(0x0EAE2)  // ti-lock
    readonly property string logout:   glyph(0x0EBA8)  // ti-logout
    readonly property string suspend:  glyph(0x0EAF8)  // ti-moon
    readonly property string reboot:   glyph(0x0EB15)  // ti-rotate-clockwise
    readonly property string shutdown: glyph(0x0EB0D)  // ti-power

    // ── Lock ─────────────────────────────────────────────────
    //
    // Not Session: those are things you pick off the power menu, and
    // these two are states the lock screen reports back at you.
    readonly property string fingerprint: glyph(0x0EBD1)  // ti-fingerprint
    readonly property string capsLock:    glyph(0x0EFEE)  // ti-arrow-big-up-line

    // ── Content ──────────────────────────────────────────────
    readonly property string bell:      glyph(0x0EA35)  // ti-bell
    readonly property string bellOff:   glyph(0x0ECE9)  // ti-bell-off
    readonly property string clipboard: glyph(0x0EA6F)  // ti-clipboard
    readonly property string image:     glyph(0x0EB0A)  // ti-photo
    readonly property string file:      glyph(0x0EAA2)  // ti-file-text
    readonly property string calendar:  glyph(0x0EA53)  // ti-calendar
    readonly property string clock:     glyph(0x0EA70)  // ti-clock
    readonly property string coffee:    glyph(0x0EF0E)  // ti-coffee
    readonly property string settings:  glyph(0x0EB20)  // ti-settings

    readonly property string close:        glyph(0x0EB55)  // ti-x
    readonly property string chevronLeft:  glyph(0x0EA60)  // ti-chevron-left
    readonly property string chevronRight: glyph(0x0EA61)  // ti-chevron-right

    // ── Settings sidebar ─────────────────────────────────────
    //
    // One per page, each saying what its page is about. The island
    // is a pill, so its page is a capsule rather than a window bar.
    readonly property string tabIsland:     glyph(0x0FAE2)  // ti-capsule-horizontal
    readonly property string tabControl:    glyph(0x0EC38)  // ti-adjustments-horizontal
    readonly property string tabAppearance: glyph(0x0EB01)  // ti-palette
    readonly property string tabInput:      glyph(0x0EBD6)  // ti-keyboard
    readonly property string tabSystem:     glyph(0x0EB20)  // ti-settings
    readonly property string tabNetwork:    glyph(0x0EB52)  // ti-wifi
    readonly property string tabApps:       glyph(0x0EBB6)  // ti-apps
}
