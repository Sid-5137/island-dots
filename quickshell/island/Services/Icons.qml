pragma Singleton

import Quickshell
import QtQuick

// Every glyph the shell draws from the patched font, named once.
//
// These were 46 raw escapes spread across fifteen files, and three
// separate things were wrong with them at the same time — which is one
// thing, really: nobody could see them.
//
//   The mute icon was U+F6A9 and the wired-network icon U+F6FF. Both
//   are Nerd Fonts v2 codepoints for Material Design Icons, a range
//   that v3 moved wholesale into U+F0000 and up. Neither is in the
//   font any more, so both drew nothing.
//
//   The Wi-Fi bars and the settings tabs were transcribed by hand and
//   a nibble slipped: U+F09A8 for U+F0928, U+F133E for U+F033E. The
//   damage is that the wrong codepoints are also real glyphs, so
//   instead of the boxes that would have sent somebody looking, the
//   network list drew a shower head, a square-root box, a star face
//   and a text icon for its four signal strengths, and the settings
//   sidebar offered a webcam for Theme and an open padlock for
//   Control. Wrong, quietly, for as long as anyone had been reading
//   past them.
//
//   And nothing anywhere said what a glyph was meant to be. An escape
//   is not reviewable: U+F133E and U+F033E look the same in a diff,
//   render as something either way, and there is no line to check the
//   claim against.
//
// So a name, a codepoint, and the font's own glyph name beside it.
// That last part is the one that does the work — it is what makes
// `md-lock` checkable against the cheat sheet, and it is how all of
// the above was found.
//
// Deliberately not in here: "×", "•", "❯", "↺", "⌄". Those are
// typography, not iconography — they come from the text font, they
// cannot go missing when an icon font is patched differently, and
// folding them in would mean this file no longer answers one question.
//
// Noctalia keeps the same register for the same reason and calls it
// GlyphRegistry, though it draws from Tabler rather than from a Nerd
// Font. Swapping families is a rewrite of this file and of nothing
// else, which is the other thing a register buys.

Singleton {
    id: root

    // Codepoints rather than the characters.
    //
    // Everything past U+FFFF has to be written as a pair of UTF-16
    // escapes in a QML string, and a pair is unreadable, unsearchable
    // and exactly where the transcription errors above came from. The
    // two escapes for md-lock and the two for the glyph that was drawn
    // instead of it differ in one hex digit, in the second escape, and
    // neither half is the codepoint you would look up. A plain
    // 0xF033E can be pasted straight into the Nerd Fonts search box.
    function glyph(cp) { return String.fromCodePoint(cp); }

    // ── Sound ────────────────────────────────────────────────
    //
    // One family for the whole ramp. Muted used to be the odd one out,
    // a Material glyph among three Font Awesome ones, which is how it
    // came to be the only one that broke.
    readonly property string volumeMuted:  glyph(0x0EEE8)  // fa-volume_xmark
    readonly property string volumeHigh:   glyph(0x0F028)  // fa-volume_up
    readonly property string volumeMedium: glyph(0x0F027)  // fa-volume_low
    readonly property string volumeLow:    glyph(0x0F026)  // fa-volume_off

    readonly property string micOn:        glyph(0x0F130)  // fa-microphone
    readonly property string micOff:       glyph(0x0F131)  // fa-microphone_slash

    readonly property string brightness:   glyph(0x0F185)  // fa-sun_o

    // ── Battery ──────────────────────────────────────────────
    readonly property string batteryCharging: glyph(0x0F0E7)  // fa-flash
    readonly property string batteryFull:     glyph(0x0F240)  // fa-battery_full
    readonly property string batteryHigh:     glyph(0x0F241)  // fa-battery_three_quarters
    readonly property string batteryHalf:     glyph(0x0F242)  // fa-battery_half
    readonly property string batteryLow:      glyph(0x0F243)  // fa-battery_quarter
    readonly property string batteryEmpty:    glyph(0x0F244)  // fa-battery_empty

    // ── Network ──────────────────────────────────────────────
    readonly property string wifi:     glyph(0x0F1EB)  // fa-wifi
    readonly property string ethernet: glyph(0x0EF44)  // fa-ethernet

    // The four bars, which are a set and so are consecutive in the
    // font: 1 is F091F and each step up is +3.
    readonly property string wifi1: glyph(0xF091F)  // md-wifi_strength_1
    readonly property string wifi2: glyph(0xF0922)  // md-wifi_strength_2
    readonly property string wifi3: glyph(0xF0925)  // md-wifi_strength_3
    readonly property string wifi4: glyph(0xF0928)  // md-wifi_strength_4

    readonly property string secure: glyph(0xF033E)  // md-lock

    // ── Bluetooth ────────────────────────────────────────────
    readonly property string bluetooth:          glyph(0x0F293)  // fa-bluetooth
    readonly property string bluetoothConnected: glyph(0x0F294)  // fa-bluetooth_b
    readonly property string bluetoothDevice:    glyph(0xF00AF)  // md-bluetooth

    // ── Session ──────────────────────────────────────────────
    readonly property string lock:     glyph(0x0F023)  // fa-lock
    readonly property string logout:   glyph(0x0F2F5)  // fa-right_from_bracket
    readonly property string suspend:  glyph(0x0F186)  // fa-moon_o
    readonly property string reboot:   glyph(0x0F021)  // fa-refresh
    readonly property string shutdown: glyph(0x0F011)  // fa-power_off

    // ── Content ──────────────────────────────────────────────
    readonly property string bell:      glyph(0x0F0F3)  // fa-bell
    readonly property string clipboard: glyph(0x0F0EA)  // fa-paste
    readonly property string image:     glyph(0x0F03E)  // fa-picture_o
    readonly property string file:      glyph(0x0F15C)  // fa-file_text

    // ── Settings sidebar ─────────────────────────────────────
    //
    // One per page, and each one now says what its page is about
    // rather than what a mistyped codepoint happened to land on.
    readonly property string tabIsland:  glyph(0xF1513)  // md-dock_top
    readonly property string tabControl: glyph(0xF062E)  // md-tune
    readonly property string tabTheme:   glyph(0xF03D8)  // md-palette
    readonly property string tabInput:   glyph(0xF030C)  // md-keyboard
    readonly property string tabSystem:  glyph(0xF0493)  // md-cog
    readonly property string tabNetwork: glyph(0xF05A9)  // md-wifi
}
