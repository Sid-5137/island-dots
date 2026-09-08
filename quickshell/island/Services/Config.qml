pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property alias island: adapter.island
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias motion: adapter.motion
    readonly property alias appearance: adapter.appearance
    readonly property alias input: adapter.input

    // Force a write. Most changes save automatically via
    // onAdapterUpdated, but this is here for explicit saves.
    function save() {
        file.writeAdapter();
    }

    function reload() {
        file.reload();
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/island/settings.json"

        // Create it with the defaults below if it doesn't exist.
        preload: true
        printErrors: false

        watchChanges: true
        onFileChanged: reload()

        // Persist whenever any property changes.
        onAdapterUpdated: writeAdapter()

        onLoadFailed: function(error) {
            // First run — write the defaults out so there's a file to edit.
            console.log("[Config] no settings.json, writing defaults");
            file.writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property JsonObject island: JsonObject {
                // "always" — on screen at all times
                // "always" — on screen at all times
                // "smart"  — hidden only when a window actually reaches
                //            the strip the island sits in
                // "auto"   — hidden whenever any window is open
                property string visibility: "always"

                // How long the island stays revealed after the cursor
                // leaves. Without a grace period hover and geometry
                // fight each other: the pill moves out from under the
                // cursor, hover drops, the pill hides, hover returns.
                property int hoverGrace: 400

                // Height in px of the hover strip at the top edge
                // that brings the island back in "auto" mode.
                property int revealZone: 12

                // Hide while a window is fullscreen.
                property bool hideOnFullscreen: true

                // Collapse this long after the cursor leaves. 0 keeps
                // it open until clicked again.
                property int collapseDelay: 400

                // How long a track change pops the island open.
                property int attentionDuration: 2500

                // Expand automatically when a new track starts.
                property bool expandOnTrackChange: true

                // Collapsed pill geometry.
                property int idleWidth: 150
                property int idleHeight: 34
                property int compactWidth: 200
                property int compactHeight: 40

                // Expanded geometry, with and without media.
                property int expandedWidth: 320
                property int expandedHeight: 120
                property int mediaWidth: 400
                property int mediaHeight: 156

                // Pill typography. The clock is what you read at a
                // glance, so it gets its own size rather than
                // inheriting the generic small one.
                // Horizontal breathing room inside the pill. The
                // collapsed widths below are minimums; the pill grows
                // past them when content needs it, so this padding
                // always holds.
                property int padding: 20

                property int fontSize: 13
                property int fontWeight: 700
                property bool showWorkspaces: true

                property int radius: 12
                property int topMargin: 8

                // Search / launcher, drawn inside the island itself
                // rather than as a separate window.
                property int searchWidth: 560
                property int searchFieldHeight: 46
                property int searchRowHeight: 40
                property int searchMaxRows: 8

                // Power menu, also drawn inside the island.
                // Picker strip: wallpapers, palettes and icon sets.
                property int pickerWidth: 620
                property int pickerHeight: 190

                property int sessionWidth: 460
                property int sessionHeight: 128

                // Control centre: calendar plus quick toggles.
                property int controlWidth: 962
                property int controlHeight: 556
                // Added to the expanded height when media is playing.
                property int mediaStripHeight: 88

                // Quick toggles with no daemon behind them yet. Kept
                // here so the tiles have somewhere to persist, and so
                // a notification server can read `dnd` when it lands.
                // Nudge for control-centre glyphs. The metrics-based
                // correction handles most icon fonts; this is here for
                // the ones it doesn't, so it's a slider rather than a
                // recompile.
                property int tileIconOffset: 0

                // Notification popup and history panel.
                property int notifyWidth: 460
                property int notifyHeight: 104
                property int notifyDuration: 5000
                property int notifyCriticalDuration: 12000
                property int centreWidth: 480
                property int centreHeight: 440
                property int centreRowHeight: 88

                property bool dnd: false
                property bool caffeine: false
            }

            property JsonObject motion: JsonObject {
                property int morphDuration: 250
                property real morphOvershoot: 0.6
                property int fadeIn: 120
                property int fadeOut: 70

                // Fraction of target height the pill must reach
                // before expanded content appears.
                property real contentThreshold: 0.75
            }

            property JsonObject appearance: JsonObject {
                // Shell panels
                property real panelOpacity: 1.0
                property int panelRadius: 16
                // How far the desktop dims behind the settings window.
                // Blur alone doesn't separate a panel from a busy
                // wallpaper; a little scrim does.
                property real panelScrim: 0.30
                property int fontScale: 100      // percent

                // Applied to GTK, Qt and the shell together.
                property string iconTheme: "Adwaita"
                property string cursorTheme: "Bibata-Modern-Ice"
                property int cursorSize: 24
                property string gtkTheme: "adw-gtk3"

                // Hyprland — applied live with hyprctl keyword
                property int blurSize: 8
                property int blurPasses: 3
                property real blurBrightness: 0.85
                property real blurContrast: 0.9
                property int gapsIn: 4
                property int gapsOut: 8
                property int borderSize: 1
                property int windowRounding: 0
                property real inactiveOpacity: 0.94
                property bool shadows: true
            }

            property JsonObject input: JsonObject {
                // "adaptive" accelerates with speed; "flat" is 1:1.
                property string mouseAccel: "flat"
                property real mouseSensitivity: 0.0
                property bool naturalScrollMouse: false

                property bool touchpadEnabled: true
                property bool tapToClick: true
                property bool naturalScroll: true
                property bool dragLock: true
                property bool disableWhileTyping: true
                property real scrollFactor: 0.6
                property string touchpadAccel: "adaptive"
                property real touchpadSensitivity: 0.0

                property int repeatRate: 25
                property int repeatDelay: 600
            }

            property JsonObject wallpaper: JsonObject {
                property string directory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
                property int crossfadeDuration: 450

                // matugen scheme: scheme-monochrome, scheme-tonal-spot,
                // scheme-vibrant, scheme-content, scheme-expressive…
                property string scheme: "scheme-monochrome"

                // Cycle wallpapers on a timer. 0 disables.
                property int rotateMinutes: 0
            }
        }
    }
}
