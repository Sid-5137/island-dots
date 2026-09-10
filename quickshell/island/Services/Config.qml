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
    readonly property alias idle: adapter.idle

    // Force a write. Most changes save automatically via
    // onAdapterUpdated, but this is here for explicit saves.
    // Bump when a key changes meaning rather than merely appearing.
    // New keys need no migration — the merge on load handles those.
    readonly property int currentVersion: 1

    // Set once the startup merge has run, so the file watcher's reload
    // doesn't start writing in a loop.
    property bool merged: false

    function migrate(from) {
        // No migrations yet. When one is needed:
        //
        //   if (from < 2) { adapter.island.foo = adapter.island.oldFoo }
        //
        // then set adapter.version and write.
        adapter.version = currentVersion;
        file.writeAdapter();
    }

    // Reset needs the shipped values, but JsonAdapter holds only the
    // live ones once settings.json has been read over them.
    //
    // Rather than duplicating every default — which would drift from
    // the declarations below — they are snapshotted here at startup.
    // Component.onCompleted runs before the FileView's async load
    // completes, so what is captured is what the code declares.
    property var defaults: ({})

    Component.onCompleted: {
        for (const name of sections) {
            const src = adapter[name];
            if (!src) continue;
            const copy = {};
            for (const key of Object.keys(src)) {
                if (typeof src[key] !== "function") copy[key] = src[key];
            }
            defaults[name] = copy;
        }
    }

    readonly property var sections:
        ["island", "motion", "appearance", "input", "idle", "wallpaper"]

    // "island.hoverGrace" -> the shipped value, or undefined if the
    // path isn't one we declare.
    function defaultFor(path) {
        if (!path) return undefined;
        const parts = path.split(".");
        if (parts.length !== 2) return undefined;
        const section = defaults[parts[0]];
        return section ? section[parts[1]] : undefined;
    }

    function resetKey(path) {
        const parts = path.split(".");
        if (parts.length !== 2) return;
        const live = adapter[parts[0]];
        const shipped = defaults[parts[0]];
        if (!live || !shipped) return;
        if (shipped[parts[1]] === undefined) return;
        live[parts[1]] = shipped[parts[1]];
        file.writeAdapter();
    }

    function resetSection(name) {
        const live = adapter[name];
        const shipped = defaults[name];
        if (!live || !shipped) return;

        // Machine-specific keys are left alone: resetting Appearance
        // should not throw away an icon theme the user picked, and
        // resetting Wallpaper should not point at a directory that
        // may not exist.
        const keep = ["iconTheme", "cursorTheme", "gtkTheme", "directory"];

        for (const key of Object.keys(shipped)) {
            if (keep.indexOf(key) !== -1) continue;
            if (typeof shipped[key] === "function") continue;
            live[key] = shipped[key];
        }
        file.writeAdapter();
    }

    function resetAll() {
        for (const name of sections) resetSection(name);
    }

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

        onLoaded: {
            // Write the adapter straight back out once, at startup.
            // Properties the file didn't contain are still at their
            // declared defaults, so this merges new keys in — which is
            // what stops an added setting from requiring the file to be
            // deleted. Keys the adapter no longer declares are dropped
            // by the same write.
            //
            // Guarded: the write trips the file watcher, which reloads,
            // which would write again.
            if (!root.merged) {
                root.merged = true;
                if (adapter.version < root.currentVersion)
                    root.migrate(adapter.version);
                else
                    file.writeAdapter();
            }
        }

        onLoadFailed: function(error) {
            root.merged = true;
            file.writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property int version: 1

            property JsonObject island: JsonObject {
                // "always" — on screen at all times, with the strip
                //            reserved so windows start below it
                // "smart"  — hidden until a window reaches the strip
                //            it sits in, then out of the way
                property string visibility: "always"

                // How long the island stays revealed after the cursor
                // leaves. Without a grace period hover and geometry
                // fight each other: the pill moves out from under the
                // cursor, hover drops, the pill hides, hover returns.
                property int hoverGrace: 600

                // Height in px of the hover strip at the top edge
                // that brings the island back once hidden.
                property int revealZone: 12

                // Hide while a window is fullscreen.
                property bool hideOnFullscreen: true

                // Collapse this long after the cursor leaves. 0 keeps
                // it open until clicked again.
                property int collapseDelay: 400

                // How long a track change pops the island open.
                property int attentionDuration: 2500

                // Expand automatically when a new track starts.
                property bool expandOnTrackChange: false

                // Collapsed pill geometry.
                property int idleWidth: 152
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

                // Which face the collapsed pill shows. Scrolling over
                // the pill cycles it; the choice persists.
                property string face: "clock"
                property bool faceIndicator: false

                // Below 1.0 the wallpaper shows through and the
                // island-bar layer rule blurs it. At 1.0 the pill is
                // solid and the blur costs nothing but does nothing.
                property real opacity: 0.88

                property int radius: 8
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
                property int controlWidth: 528
                property int controlHeight: 396
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
                property int notifyActionHeight: 36
                property int notifyDuration: 5000
                property int notifyCriticalDuration: 12000
                property int centreWidth: 480
                property int centreHeight: 440
                property int centreRowHeight: 88

                // How long after the last Tab the switcher commits.
                // Long enough to keep tabbing, short enough not to
                // feel like a wait once you have chosen.
                property int switcherCommitDelay: 650

                property int switcherWidth: 900
                property int switcherHeight: 176
                property int switcherTile: 84
                property int overviewWidth: 640
                property int overviewCard: 220
                property real backdropDim: 0.45

                property int clipWidth: 620
                property int clipRowHeight: 40
                property int clipMaxRows: 9

                property int authWidth: 460
                property int authHeight: 176

                property int osdWidth: 300
                property int osdHeight: 56
                property int osdDuration: 1600
                property int osdStep: 5

                // A file under /etc/pam.d. "login" exists everywhere;
                // a dedicated one would let a fingerprint reader work
                // here without enabling it for tty logins too.
                property string pamConfig: "login"

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
                property real panelOpacity: 0.78
                property int panelRadius: 8
                // How far the desktop dims behind the settings window.
                // Blur alone doesn't separate a panel from a busy
                // wallpaper; a little scrim does.
                property real panelScrim: 0.0
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
                property int windowRounding: 8
                property real inactiveOpacity: 0.94
                property bool shadows: true
            }

            // Mouse and touchpad are configured per device, not
            // globally: every input option except force_no_accel can go
            // in an hl.device() block, so the two need not share a
            // sensitivity or an acceleration profile.
            property JsonObject input: JsonObject {
                // "adaptive" accelerates with speed; "flat" is 1:1.
                property string mouseAccel: "flat"
                property real mouseSensitivity: 1.0
                property bool naturalScrollMouse: false

                property bool touchpadEnabled: true
                property string touchpadAccel: "flat"
                property real touchpadSensitivity: 1.0
                property bool tapToClick: true
                property bool naturalScroll: true
                property bool dragLock: true
                property bool disableWhileTyping: true
                property real scrollFactor: 0.6

                property int repeatRate: 25
                property int repeatDelay: 600
            }

            // Timeouts in seconds. Services/Idle.qml turns these into
            // hypridle.conf, so this is the only place they live.
            property JsonObject idle: JsonObject {
                property bool enabled: true
                property int dimTimeout: 240
                property int dimLevel: 10          // percent
                property int lockTimeout: 300
                property int screenOffTimeout: 360
                property int suspendTimeout: 1800
            }

            property JsonObject wallpaper: JsonObject {
                property string directory: Quickshell.env("HOME") + "/Pictures/Wallpapers"
                property int crossfadeDuration: 450

                // matugen scheme: scheme-monochrome, scheme-tonal-spot,
                // scheme-vibrant, scheme-content, scheme-expressive…
                property string scheme: "scheme-tonal-spot"

                // Cycle wallpapers on a timer. 0 disables.
                property int rotateMinutes: 0
            }
        }
    }
}
