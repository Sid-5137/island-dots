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
    readonly property alias lock: adapter.lock
    readonly property alias audio: adapter.audio
    readonly property alias apps: adapter.apps
    readonly property alias ui: adapter.ui

    // Force a write. Most changes save automatically via
    // onAdapterUpdated, but this is here for explicit saves.
    // Bump when a key changes meaning rather than merely appearing.
    // New keys need no migration — the merge on load handles those.
    readonly property int currentVersion: 4

    // Set once the startup merge has run, so the file watcher's reload
    // doesn't start writing in a loop.
    property bool merged: false

    function migrate(from) {
        // Nothing carries over in any of these: the old values have
        // no meaning under the new keys. Dropped keys leave the file
        // on the next write, since JsonAdapter writes only what it
        // declares.
        //
        //   1 -> 2  faces gone; tray and workspaces are pods now
        //   2 -> 3  motion is a spring: duration/overshoot replaced
        //   3 -> 4  controlHeight gone; the panel is a layout
        //
        // The next one goes here:
        //
        //   if (from < 5) { adapter.island.foo = adapter.island.oldFoo }
        adapter.version = currentVersion;
        persist();
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

        // Forces settings.json in synchronously. The return value is
        // discarded — the call is made purely for its timing, because
        // `preload` and `blockLoading` both leave the read async until
        // an explicit text()/data().
        //
        // Do not remove. Without it the first frames evaluate against
        // the declared defaults, and values that escape early cannot
        // be followed by a later change — the layer-shell exclusive
        // zone being the one that stuck.
        file.text();
    }

    readonly property var sections:
        ["island", "motion", "appearance", "input", "idle", "lock",
         "wallpaper", "audio", "apps", "ui"]

    // "island.hoverGrace" -> the shipped value, or undefined if the
    // path isn't one we declare.
    function defaultFor(path) {
        if (!path) return undefined;
        const parts = path.split(".");
        if (parts.length !== 2) return undefined;
        const section = defaults[parts[0]];
        return section ? section[parts[1]] : undefined;
    }

    // Three keys because three different things read them: the pill
    // (island.radius), every panel and card (appearance.panelRadius),
    // and Hyprland (appearance.windowRounding, another process).
    //
    // appearance.radiusLink moves them together and the settings page
    // collapses to one slider. They stay separate underneath, which is
    // what lets the link be turned off.
    readonly property var radii: [
        "island.radius", "appearance.panelRadius", "appearance.windowRounding"
    ]

    function setRadius(v) {
        const r = Math.round(v);
        adapter.appearance.panelRadius = r;
        if (!adapter.appearance.radiusLink) return;
        adapter.island.radius = r;
        adapter.appearance.windowRounding = r;
    }

    function setRadiusLink(on) {
        adapter.appearance.radiusLink = on;
        // Linking has to pick a winner among three numbers that may
        // already disagree, and it is the one the single slider was
        // showing while unlinked — anything else changes the value
        // under a control the user is looking at.
        if (on) setRadius(adapter.appearance.panelRadius);
    }

    function resetOne(path) {
        const parts = path.split(".");
        if (parts.length !== 2) return;
        const live = adapter[parts[0]];
        const shipped = defaults[parts[0]];
        if (!live || !shipped) return;
        if (shipped[parts[1]] === undefined) return;
        live[parts[1]] = shipped[parts[1]];
    }

    function resetKey(path) {
        // Reverting one radius while the three are linked has to
        // revert all three, or the dot silently breaks the link it is
        // sitting next to. All three ship at 8, so this lands level.
        if (adapter.appearance.radiusLink && radii.indexOf(path) !== -1)
            for (const key of radii) resetOne(key);
        else
            resetOne(path);

        persist();
    }

    function resetSection(name) {
        const live = adapter[name];
        const shipped = defaults[name];
        if (!live || !shipped) return;

        // Machine-specific keys are left alone: resetting Appearance
        // should not throw away an icon theme the user picked,
        // resetting Wallpaper should not point at a directory that
        // may not exist, and resetting Apps should not name a
        // terminal that is not installed here.
        const keep = ["iconTheme", "cursorTheme", "gtkTheme", "directory",
                      "terminal"];

        for (const key of Object.keys(shipped)) {
            if (keep.indexOf(key) !== -1) continue;
            if (typeof shipped[key] === "function") continue;
            live[key] = shipped[key];
        }
        persist();
    }

    function resetAll() {
        for (const name of sections) resetSection(name);
    }

    // One write per burst of changes, and no reload of our own work.
    //
    // A write per property plus a reload per file change is lossy for
    // anything setting several keys at once (a Tempo writes eleven): a
    // reload landing mid-burst puts the adapter back to what was on
    // disk. The zero-interval timer is not a delay — it fires on the
    // next turn of the event loop, after the burst has landed and
    // before anything observes the file. Keep it.
    function persist() {
        file.saving = true;
        file.writeAdapter();
    }

    Timer {
        id: flush
        interval: 0
        onTriggered: root.persist()
    }

    Timer {
        id: settle
        interval: 150
        onTriggered: file.saving = false
    }

    function save() {
        persist();
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

        // True from the moment a write is queued until the change it
        // makes on disk has finished coming back around to us.
        property bool saving: false

        onFileChanged: {
            // Our own write, returning. Reloading here is what used to
            // destroy data — see `persist` below.
            if (file.saving) return;
            reload();
        }

        // `saved` fires when the write lands; the watcher's notice
        // arrives some time after that, so the flag has to outlive the
        // write by a little. The cost of the window is that a change
        // somebody else makes to settings.json within it is not picked
        // up until the next one, which is a trade worth making against
        // losing a setting the user just made.
        onSaved: settle.restart()

        onAdapterUpdated: flush.restart()

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
            root.persist();
        }

        JsonAdapter {
            id: adapter

            property int version: 4

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

                // Whether the collapsed pill carries the track title
                // as well as the equaliser. Off: a title is as long as
                // whoever named the track decided, and it changes the
                // pill's width every few minutes.
                property bool pillTitle: false

                // Expand automatically when a new track starts.
                property bool expandOnTrackChange: false

                // Collapsed pill geometry.
                property int idleWidth: 152
                property int idleHeight: 34
                property int compactWidth: 200
                property int compactHeight: 40

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

                // ── Pods ──────────────────────────────────────
                //
                // The two capsules that flank the pill. Workspaces on
                // the left, the tray on the right. They are separate
                // shapes rather than more content crammed into the
                // pill, so a glance at the top of the screen answers
                // "where am I" and "what is running" without hovering,
                // scrolling or opening anything.
                property bool showWorkspaces: true

                // What the workspace pod draws at rest. Open it and
                // every style becomes numbered chips, since that is
                // what you aim at.
                //
                //   dashes   bar for current, dash for occupied, stub
                //            for empty
                //   dots     the same three, round
                //   numbers  the addresses, unboxed
                //   icons    the window last used on each workspace
                property string workspaceStyle: "dashes"

                property bool showTray: true

                // Space between a pod and the pill. Small enough that
                // the three read as one object, wide enough that they
                // are three shapes and not a broken one.
                property int podGap: 8

                // A pod opens itself for a moment when what it shows
                // changes — a workspace switch, a tray icon asking for
                // attention — then settles back to its resting size.
                property bool podPeek: true
                property int podPeekDuration: 1600

                // Icons the tray pod shows at rest. The rest arrive
                // when it opens, behind a "+n".
                property int trayRestMax: 4

                // What a scroll over the collapsed pill does.
                // "workspace" — move one workspace either way
                // "volume"    — adjust volume and show the OSD
                // "none"      — nothing
                // While an OSD is up the gesture always adjusts that
                // value instead, whatever this says.
                property string scrollAction: "workspace"

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

                // Control centre. Only the width is a number now: the
                // height is whatever the layout below reaches, so a
                // panel can never be shorter than the controls in it.
                property int controlWidth: 564

                // The grid the controls sit on. See
                // Services/ControlLayout.qml for what the layout
                // string means; the editor on the Control Centre
                // settings page is what normally writes it.
                property int controlColumns: 6
                property int controlCell: 48
                property int controlGap: 10
                property int controlPad: 18

                property string controlLayout: "calendar:0,0,3,5"
                    + ";wifi:3,0,3,1"
                    + ";bluetooth:3,1,3,1"
                    + ";media:3,2,3,2"
                    + ";display:3,4,3,1"
                    + ";sound:0,5,6,1"

                // How much of the accent is washed over album art, so
                // a media card belongs to the theme whatever the
                // record label chose. 0 leaves the artwork alone.
                property real artTint: 0.28

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

                // A ceiling, not a height. The centre is as tall as
                // the notifications in it — see
                // Modes/CentreMode.qml's contentHeight — and this is
                // where it stops growing and starts scrolling, which
                // at the shipped row height is four of them.
                //
                // No migration: the stored number carries over intact
                // and still means something true about the panel. It
                // governs fewer cases than it used to, which is not
                // the kind of change that can invalidate a value
                // somebody already chose.
                property int centreHeight: 440
                property int centreRowHeight: 88

                // How long after the last Tab the switcher commits.
                // Long enough to keep tabbing, short enough not to
                // feel like a wait once you have chosen.
                property int switcherCommitDelay: 650

                property int switcherWidth: 900
                property int switcherHeight: 176
                property int switcherTile: 84
                property int overviewCard: 220

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

            // Everything here is read through Services/Motion.qml,
            // which turns it into easing curves. The comments there
            // explain the model; these are the dials.
            property JsonObject motion: JsonObject {
                // These are the `fluid` tempo in Services/Motion.qml,
                // spelled out. The tempo tables are the place to argue
                // about them; this is only what a fresh install gets.
                //
                // The shape. Arrivals spring, departures do not — a
                // spring on the way out reads as the interface
                // arguing with you.
                property int expandDuration: 240
                property int collapseDuration: 200
                property int hoverDuration: 200
                property int popDuration: 300

                // How much the shape overshoots on the way in, as
                // Apple's damping fraction. 1.0 is no overshoot at
                // all, 0.8 is about one and a half percent, 0.6 is
                // visibly springy, 0.4 is a toy.
                property real arriveDamping: 0.78
                property real popDamping: 0.55

                // The content follows the shape rather than waiting
                // for it: it starts `contentLead` into the morph and
                // is fully in long before the shape has settled. On
                // the way out it leaves first, and faster.
                property int contentLead: 40
                property int contentInDuration: 150
                property int contentOutDuration: 90

                // Cross-fades that are not part of a morph: a colour
                // changing, an indicator appearing.
                property int fadeIn: 90
                property int fadeOut: 60

                // Takes the springs and the shape morphs away and
                // leaves the cross-fades, which are not a vestibular
                // trigger.
                property bool reduceMotion: false
            }

            property JsonObject appearance: JsonObject {
                // Shell panels
                property real panelOpacity: 0.85
                property int panelRadius: 8
                // How far the desktop dims behind the settings window.
                // Blur alone doesn't separate a panel from a busy
                // wallpaper; a little scrim does.
                property real panelScrim: 0.0

                // The three fonts the shell draws with, all on the
                // Appearance page.
                //
                // fontIcons is the only one that is not a free choice:
                // the shell's icons are codepoints rather than images,
                // so it has to be a font that carries them. Keeping it
                // separate is what lets fontFamily be any face at all
                // — an interface drawn entirely in a monospace patch
                // is the cost of tying the two together.
                property string fontFamily: "Adwaita Sans"
                property string fontMono: "JetBrainsMono Nerd Font Mono"
                property string fontIcons: "JetBrainsMono Nerd Font"

                // The pill draws a clock, and a clock in a
                // proportional face changes width as the digits change
                // — so the shape at rest would breathe every minute.
                // Monospace keeps it still. Windows and panels have no
                // such constraint and read better proportional.
                property string fontIsland: "JetBrainsMono Nerd Font"

                // Whether the three corner radii move as one. See the
                // `radii` block above; the settings page shows one
                // slider while this is on and three while it is off.
                property bool radiusLink: true

                // How square a corner is, as the exponent of the
                // superellipse it is drawn from. 2 is a circular arc
                // — what Qt's Rectangle draws — and 4 is roughly the
                // corner macOS draws.
                //
                // One number for the compositor and the shell both. It
                // goes to Hyprland as decoration:rounding_power for
                // windows, and packages/qml-squircle draws the shell's
                // own surfaces from it, so a window corner and a panel
                // corner are the same curve.
                property real cornerSmoothing: 4.0

                // Applied to GTK, Qt and the shell together.
                property string iconTheme: "Adwaita"
                property string cursorTheme: "Bibata-Modern-Ice"
                property int cursorSize: 24
                property string gtkTheme: "adw-gtk3"

                // Hyprland — applied live with hyprctl keyword
                property int blurSize: 8
                property int blurPasses: 3
                // Hyprland's blur cache. Off, a blurred surface is
                // recomputed every frame whether or not anything
                // behind it moved.
                property bool blurOptimize: true
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

            // The lock surface. Separate from `idle`, which decides
            // WHEN the screen locks — these are what it looks like and
            // how it behaves once it has.
            property JsonObject lock: JsonObject {
                // How much of the wallpaper survives behind the lock.
                // The scrim is the palette's darkest surface rather
                // than black, so the lock belongs to the same theme as
                // the rest of the shell instead of being the one
                // surface that ignores it.
                property real scrimOpacity: 0.60

                // Qt's Gaussian over the wallpaper, 0 to 1.
                //
                // Deliberately not appearance.blurSize. That one is
                // Hyprland resampling whatever sits behind a panel;
                // this is one full-screen image blurred in our own
                // scene graph, and it is static — it costs a frame
                // when the lock engages and nothing after. Sharing a
                // number would tie two unrelated costs together.
                property real blur: 0.50

                // Wrong passwords before the field stops taking them,
                // and for how long. 0 attempts turns the wait off.
                //
                // Deliberately small. This is a delay that costs a
                // stranger their patience, not a lockout that costs
                // you your session — anyone holding the keyboard can
                // already reach a TTY, so a long one only ever
                // punishes the person who mistyped.
                property int attemptsBeforeDelay: 5
                property int delaySeconds: 30

                // The battery at the foot of the surface. Worth having
                // on a laptop, noise on a desktop, and Battery.present
                // already hides it where there is nothing to report.
                property bool showBattery: true
            }

            // How the volume the shell shows relates to the volume
            // PipeWire applies. See Services/Audio.qml, which is
            // where the two scales are spelled out.
            property JsonObject audio: JsonObject {
                // "system"     — the scale wpctl, pactl and
                //                pavucontrol all use, so the numbers
                //                agree with every other tool
                // "perceptual" — remapped so half way along the
                //                slider sounds half as loud, at the
                //                cost of that agreement
                property string volumeCurve: "system"
            }

            // Default applications.
            //
            // Only the terminal lives here. Everything else on the
            // Apps page is a MIME handler, and those belong to the
            // desktop rather than to this shell — they go in
            // mimeapps.list, where every other application can read
            // them. A terminal emulator is the handler of no type at
            // all, so there is nowhere else for the choice to go.
            property JsonObject apps: JsonObject {
                // A desktop entry id, such as "kitty.desktop". Empty
                // means the one hypr/env.lua ships with.
                property string terminal: ""
            }

            // How the settings window is being looked at, rather than
            // anything about the shell. It lives in the file because
            // the answer should survive closing the window — somebody
            // who has turned the numbers on is not asking to be shown
            // the short version again tomorrow.
            property JsonObject ui: JsonObject {
                // Most of what is in Settings is a number you set once
                // and never think about again, and a page that opens
                // with thirty of them is a page nobody reads. Off,
                // every row marked `advanced` is hidden.
                property bool advanced: false
            }
        }
    }
}
