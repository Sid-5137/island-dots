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
    // the declarations below — they are snapshotted at startup, in
    // Component.onCompleted before settings.json is read over them.
    property var defaults: ({})

    Component.onCompleted: {
        // Order matters. The snapshot has to happen before the forced
        // read below, or it captures the stored values and "Reset"
        // resets to whatever the user already had.
        for (const name of sections) {
            const src = adapter[name];
            if (!src) continue;
            const copy = {};
            for (const key of Object.keys(src)) {
                if (typeof src[key] !== "function") copy[key] = src[key];
            }
            defaults[name] = copy;
        }

        // Force settings.json in synchronously, before the first
        // binding reads a setting.
        //
        // `preload` alone starts an ASYNC read, and `blockLoading` on
        // its own does not change that — FileView only applies it on
        // an explicit text()/data() call. So the return value is
        // discarded here and the call is made purely for its timing.
        //
        // Without this, every binding evaluates against the DECLARED
        // defaults for the first frames, and some of those first
        // values escape where a later change cannot follow them.
        //
        // The visible one was smart hiding. Island.qml derives the
        // layer-shell exclusive zone from island.visibility, so the
        // panel committed the "always" zone — reserving the top strip
        // — before settings.json arrived. Hyprland then tiled every
        // window below the island, so nothing ever reached it, so it
        // never hid. The stored "smart" never got to the compositor,
        // and re-picking it in Settings was the only way to push it
        // through: exactly the "have to set it again every time"
        // symptom.
        file.text();
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
        path: Paths.settings

        // Create it with the defaults below if it doesn't exist.
        preload: true
        printErrors: false

        // Makes the text() call in Component.onCompleted a blocking
        // read rather than a no-op. See the comment there.
        blockLoading: true

        watchChanges: true
        onFileChanged: reload()

        // Persist whenever any property changes.
        onAdapterUpdated: writeAdapter()

        onLoaded: {
            // Deliberately does NOT write the adapter back out.
            //
            // It used to, to fold newly declared keys into the file.
            // But a write here runs on whatever the adapter holds at
            // that moment, and if anything has gone wrong with the
            // parse — or a second instance is running — that is the
            // defaults, written straight over the user's settings.
            //
            // The merge still works without it: JsonAdapter keeps a
            // declared default for any key the file omits, and the
            // first change to any setting writes the complete set.
            if (!root.merged) {
                root.merged = true;
                if (adapter.version < root.currentVersion)
                    root.migrate(adapter.version);
            }
        }

        onLoadFailed: function(error) {
            // Genuinely absent, so there is nothing to overwrite —
            // this is the one place writing defaults is correct.
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
                // 0 disables closing on hover-out, which is the
                // default: the control centre holds a calendar and
                // sliders whose own hover areas make the pill's hover
                // state unreliable, and a panel that closes because
                // the pointer grazed the wrong pixel is worse than one
                // you dismiss deliberately. Escape or a second click
                // on the pill closes it.
                property int collapseDelay: 0

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
                property real opacity: 0.85

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
                property int controlWidth: 564
                property int controlHeight: 369
                // Added to the expanded height when media is playing.
                property int mediaStripHeight: 60

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
                // Extra room for the inline reply field, on the
                // notifications that carry one.
                property int notifyReplyHeight: 38
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
                property real panelOpacity: 0.85
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

                // Give each monitor its own wallpaper. The palette
                // still comes from one of them — the focused one —
                // because there is one GTK theme and one set of
                // window borders to drive.
                property bool perMonitor: false
            }
        }
    }
}
