import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick

import "root:/Services"
import "root:/Island/Modes"
import "root:/Widgets"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData

        screen: modelData

        // One island per screen is right for the pill. It is wrong for
        // everything below that can only exist once — the IPC handlers,
        // the notification popup and the exclusive keyboard grab. Those
        // are gated on this, so they belong to the monitor you are
        // actually looking at and move with it. See Services/Screens.qml.
        readonly property bool primary:
            modelData && modelData.name === Screens.activeName

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island-bar"
        // Only the collapsed height, and only in "always" mode. A zone
        // that tracked the pill would shove every window down each time
        // it expanded.
        // "always" reserves the strip so windows start below the
        // island. Only the collapsed height is ever reserved —
        // reserving the expanded height would shove every window on
        // screen down each time the pill opens.
        exclusiveZone: Config.island.visibility === "always"
            ? Config.island.idleHeight + Config.island.topMargin * 2
            : 0

        // Only grab the keyboard while searching. Holding exclusive
        // focus the rest of the time would swallow every keystroke
        // meant for the focused app.
        WlrLayershell.keyboardFocus: (root.primary
                                      && (searching || sessionOpen || centreOpen
                                          || picker !== "" || Polkit.active || clipOpen
                                          || switcherOpen || overviewOpen
                                          || root.expanded))
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        property bool searching: false
        property bool sessionOpen: false
        property bool expanded: false

        property string picker: ""          // "" | wallpaper | theme | icon

        readonly property var faces: ["clock", "media", "tray"]
        // Falls back if the stored value names a face that no longer
        // exists — a settings.json written by an older version can.
        readonly property string face:
            faces.indexOf(Config.island.face) !== -1
                ? Config.island.face : "clock"

        // Touchpads deliver a burst of small deltas per gesture, so a
        // threshold and a cooldown turn one flick into one step rather
        // than four.
        property int scrollAccum: 0

        // The indicator is a confirmation of a change, not a permanent
        // fixture: shown on every hover it reads as a second row of
        // workspace dashes.
        property bool faceHint: false

        // ── Switcher and overview ────────────────────────────

        property bool switcherOpen: false
        property int switchIndex: 0
        property bool overviewOpen: false

        // The switcher renders and indexes this snapshot rather than
        // Wm.allWindows directly.
        //
        // Wm re-sorts allWindows by focus history on every compositor
        // event, and the refresh that openSwitcher kicks off is async —
        // so the list could be re-ordered underneath a gesture already
        // in progress, and the second Tab landed somewhere unrelated to
        // what the first one had selected.
        property var switchList: []

        readonly property var switchTarget:
            switchList.length > switchIndex ? switchList[switchIndex] : null

        // Windows opening and closing mid-gesture still have to show
        // up, but re-sorting is what breaks the selection. So the
        // opening order is kept, closed windows drop out, new ones
        // append — and the selected window is tracked by address, so
        // it only moves if it actually went away.
        function syncSwitchList() {
            if (!switcherOpen) return;

            const live = Wm.allWindows;
            const byAddr = {};
            for (const w of live) byAddr[w.address] = w;

            const selected = switchTarget ? switchTarget.address : "";

            const kept = switchList
                .filter(w => byAddr[w.address])
                .map(w => byAddr[w.address]);

            const known = {};
            for (const w of kept) known[w.address] = true;
            for (const w of live) if (!known[w.address]) kept.push(w);

            switchList = kept;

            const i = kept.findIndex(w => w.address === selected);
            switchIndex = i >= 0
                ? i
                : Math.min(switchIndex, Math.max(0, kept.length - 1));
        }

        Connections {
            target: Wm
            function onAllWindowsChanged() { root.syncSwitchList() }
        }

        function openSwitcher(step) {
            if (!switcherOpen) {
                switcherOpen = true;
                switchList = Wm.allWindows.slice();
                // Start on the previously focused window, which is what
                // a single Alt+Tab is asking for.
                switchIndex = switchList.length > 1 ? 1 : 0;
                // Anything that arrived since the last event is folded
                // in by syncSwitchList, which preserves the selection.
                Wm.refresh();
            } else {
                const n = switchList.length;
                if (n > 0) switchIndex = (switchIndex + step + n) % n;
            }
            // Commits itself once tabbing stops. Detecting the Alt
            // release would need a bind on the bare modifier, which
            // makes the compositor swallow every other Alt shortcut.
            switchCommit.restart();
        }

        Timer {
            id: switchCommit
            interval: Config.island.switcherCommitDelay
            onTriggered: root.activateSwitch()
        }

        function activateSwitch() {
            if (!switcherOpen) return;
            switchCommit.stop();
            const target = switchTarget;
            switcherOpen = false;
            if (target) {
                const addr = target.address;
                afterSurfaceDown(() => Wm.focusWindow(addr));
            }
        }

        function cancelSwitch() {
            switchCommit.stop();
            switcherOpen = false;
        }

        // Run something once this surface has actually released its
        // exclusive keyboard grab.
        //
        // This used to be Qt.callLater, and that is what made Alt+Tab
        // look broken. callLater runs before the event loop returns to
        // Wayland, so the focus dispatch reached Hyprland while the
        // island still held WlrKeyboardFocus.Exclusive — and when the
        // grab was released a moment later, the compositor restored
        // focus to whatever had it before, silently undoing ours.
        //
        // It appeared to work across workspaces only by accident:
        // focusing a window elsewhere also switches workspace, which
        // leaves the restore nothing on screen to put focus back onto.
        //
        // Measured against the real compositor: issued once the surface
        // is down, the identical dispatch lands every time.
        property var deferred: null

        function afterSurfaceDown(fn) {
            deferred = fn;
            surfaceDown.restart();
        }

        Timer {
            id: surfaceDown
            interval: 90
            onTriggered: {
                const fn = root.deferred;
                root.deferred = null;
                if (fn) fn();
            }
        }

        // Moving to the other monitor leaves whatever was open here
        // with no keyboard grab and no IPC handlers, so it would sit
        // there until clicked. Hand the shape back instead.
        onPrimaryChanged: {
            if (root.primary) return;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            clipOpen = false;
            overviewOpen = false;
            picker = "";
            expanded = false;
            notice = null;
            cancelSwitch();
        }

        function openOverview() {
            Wm.refresh();
            overviewOpen = true;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            clipOpen = false;
            picker = "";
            expanded = false;
        }

        function closeOverview() { overviewOpen = false }

        function cycleFace(delta) {
            if (scrollCooldown.running) return;

            scrollAccum += delta;
            if (Math.abs(scrollAccum) < 120) return;

            const step = scrollAccum > 0 ? -1 : 1;
            scrollAccum = 0;
            scrollCooldown.restart();

            const n = faces.length;
            const i = faces.indexOf(Config.island.face);
            Config.island.face = faces[((i < 0 ? 0 : i) + step + n) % n];

            faceHint = true;
            hintTimer.restart();
        }

        Timer {
            id: hintTimer
            interval: 1400
            onTriggered: root.faceHint = false
        }

        Timer {
            id: scrollCooldown
            interval: 220
        }

        // The mode's own filtered list isn't reachable from the
        // geometry table, so the count is computed here too.
        readonly property int clipRows: {
            const q = clipQuery.trim().toLowerCase();
            if (q === "") return Clipboard.entries.length;
            return Clipboard.entries.filter(
                e => e.preview.toLowerCase().includes(q)).length;
        }

        property bool clipOpen: false
        property string clipQuery: ""
        property Item clipInput: null
        property Item clipList: null

        function openClipboard() {
            clipOpen = true;
            searching = false;
            sessionOpen = false;
            centreOpen = false;
            picker = "";
            expanded = false;
            clipQuery = "";
            Clipboard.refresh();
            if (clipInput) {
                clipInput.text = "";
                clipInput.forceActiveFocus();
            }
            if (clipList) clipList.currentIndex = 0;
        }

        function closeClipboard() {
            clipOpen = false;
            clipQuery = "";
        }

        function copySelected() {
            if (!clipList) return;
            const q = clipQuery.trim().toLowerCase();
            const list = q === ""
                ? Clipboard.entries
                : Clipboard.entries.filter(e => e.preview.toLowerCase().includes(q));
            const e = list[clipList.currentIndex];
            if (e) {
                Clipboard.copy(e.id);
                closeClipboard();
            }
        }

        property var notice: null
        property bool centreOpen: false

        function openCentre() {
            centreOpen = true;
            picker = "";
            searching = false;
            sessionOpen = false;
            expanded = false;
            notice = null;
            Notifications.markRead();
        }

        function closeCentre() { centreOpen = false }

        function dismissNotice() {
            notice = null;
            noticeTimer.stop();
        }

        function openPicker(kind) {
            picker = kind;
            searching = false;
            sessionOpen = false;
            expanded = false;
            if (kind === "wallpaper") Wallpaper.refresh();
        }

        function closePicker() { picker = "" }

        // The control centre is what "expanded" means. Clicking the
        // pill opens it; there's no separate mode to get lost in.
        function openControl() {
            searching = false;
            sessionOpen = false;
            root.expanded = true;
        }

        function closeControl() { root.expanded = false }
        property string armed: ""
        property int sessionIndex: 0

        function openSession() {
            sessionOpen = true;
            searching = false;
            root.expanded = false;
            armed = "";
            sessionIndex = 0;
        }

        function moveSession(delta) {
            const n = Session.actions.length;
            sessionIndex = (sessionIndex + delta + n) % n;
            // Moving off an armed action disarms it, so you can't
            // arrow onto shutdown and hit Enter by reflex.
            armed = "";
        }

        function activateSession() {
            const a = Session.actions[sessionIndex];
            if (a) runAction(a.id);
        }

        function closeSession() {
            sessionOpen = false;
            armed = "";
        }

        function runAction(id) {
            // Destructive actions want a second press. Anything else
            // runs straight away.
            if (Session.isDestructive(id) && armed !== id) {
                armed = id;
                armTimer.restart();
                return;
            }
            closeSession();
            Session.run(id);
        }

        // Held rather than looked up by id: these live inside the pill,
        // and inside a Variants delegate that nesting doesn't resolve
        // from functions declared out here.
        property Item searchInput: null
        property Item searchList: null

        function openSearch() {
            searching = true;
            root.expanded = false;
            Search.query = "";
            if (searchInput) {
                searchInput.text = "";
                searchInput.forceActiveFocus();
            }
            if (searchList) searchList.currentIndex = 0;
        }

        function closeSearch() {
            searching = false;
            Search.query = "";
            if (searchInput) searchInput.text = "";
        }

        function runSelected() {
            const i = searchList ? searchList.currentIndex : 0;
            const e = Search.results[i];
            if (e) {
                Search.launch(e);
                closeSearch();
            }
        }

        anchors {
            top: true
            left: true
            right: true
        }
        // Headroom for the largest state the pill can reach. The
        // surface never resizes — it's a fixed strip the pill morphs
        // inside — so this has to clear the tallest content plus its
        // margin, or the bottom edge gets clipped by the window.
        //
        //   control centre + media strip + top margin + slack
        implicitHeight: Math.max(
                            Config.island.controlHeight + Config.island.mediaStripHeight,
                            Config.island.pickerHeight,
                            Config.island.centreHeight,
                            Config.island.authHeight,
                            Config.island.switcherHeight,
                            Config.island.searchFieldHeight
                              + Config.island.clipMaxRows * Config.island.clipRowHeight,
                            Config.island.searchFieldHeight
                              + Config.island.searchMaxRows * Config.island.searchRowHeight)
                      + Config.island.topMargin
                      + 60
        color: "transparent"

        readonly property int morphDuration: Config.motion.morphDuration
        readonly property real morphOvershoot: Config.motion.morphOvershoot
        readonly property int fadeOut: Config.motion.fadeOut
        readonly property int fadeIn: Config.motion.fadeIn

        readonly property string visibilityMode: Config.island.visibility
        readonly property int revealZone: Config.island.revealZone
        property bool demandsAttention: false

        readonly property rect islandRect: Qt.rect(
            (screen.width - pill.width) / 2,
            Config.island.topMargin,
            pill.width,
            pill.height)

        readonly property bool overlapped: {
            const r = islandRect;
            for (const w of Wm.windows) {
                if (w.x < r.x + r.width && w.x + w.w > r.x
                    && w.y < r.y + r.height && w.y + w.h > r.y)
                    return true;
            }
            return false;
        }

        readonly property bool occluded: Wm.fullscreen || overlapped

        property bool hoverLatch: false

        Timer {
            id: unlatch
            interval: Config.island.hoverGrace
            onTriggered: root.hoverLatch = false
        }

        function touch(inside) {
            if (inside) {
                hoverLatch = true;
                unlatch.stop();
            } else {
                unlatch.restart();
            }
        }

        // Depends only on plain booleans. Referencing island.mode here
        // would be circular, since state reads `revealed`.
        readonly property bool revealed:
            visibilityMode === "always"
            || !occluded
            || demandsAttention
            || hoverLatch
            || root.expanded
            || searching
            || sessionOpen
            || picker !== ""
            || notice !== null
            || centreOpen

        mask: Region {
            item: root.revealed ? island : revealStrip
        }

        property bool autoExpanded: false

        Connections {
            target: Player
            function onTrackChanged() {
                root.demandsAttention = true;
                if (Config.island.expandOnTrackChange) {
                    root.autoExpanded = true;
                    root.expanded = true;
                }
                attentionTimer.restart();
            }
        }

        // An armed action disarms itself if you hesitate, so a stray
        // click can't leave the shutdown button primed.
        Timer {
            id: armTimer
            interval: 3000
            onTriggered: root.armed = ""
        }

        Connections {
            target: Notifications
            function onArrived(entry) {
                // One popup, on the screen you are looking at. Without
                // this every monitor grows the same notification.
                if (!root.primary) return;
                root.notice = entry;

                // Coerced and floored. An undefined duration makes the
                // interval NaN, the timer never fires, and the popup
                // stays up forever — which pins the island in `notify`
                // and makes every other mode, smart hiding included,
                // look broken.
                const want = entry && entry.critical
                    ? Config.island.notifyCriticalDuration
                    : Config.island.notifyDuration;

                noticeTimer.interval = Math.max(1000, Number(want) || 5000);
                noticeTimer.restart();
            }
        }

        Timer {
            id: noticeTimer
            interval: 5000
            onTriggered: root.notice = null
        }

        // A popup that outlives its timer holds the island hostage, so
        // this clears one that has been up far longer than any
        // configured duration regardless of why the timer missed.
        Timer {
            running: root.notice !== null
            interval: 30000
            onTriggered: root.notice = null
        }

        Timer {
            id: attentionTimer
            interval: Config.island.attentionDuration
            onTriggered: {
                root.demandsAttention = false;
                if (root.autoExpanded) {
                    root.expanded = false;
                    root.autoExpanded = false;
                }
            }
        }

        // Collapse shortly after the cursor leaves. The grace period
        // stops a brush past the edge snapping it shut mid-interaction.
        Timer {
            id: collapseTimer
            interval: Config.island.collapseDelay
            onTriggered: {
                if (!pillHover.hovered && !root.autoExpanded)
                    root.expanded = false;
            }
        }

        Item {
            id: revealStrip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: root.revealZone

            MouseArea {
                id: revealArea
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.touch(containsMouse)
            }
        }

        Item {
            id: island

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            width: pill.width
            height: pill.height

            // A plain property, not QML's `state`. States exist to
            // batch PropertyChanges; everything here is a binding
            // instead, so the machinery bought nothing and cost a
            // binding-replacement bug on every transition.
            readonly property string mode: {
                if (Polkit.active) return "auth";
                if (Osd.active && !root.searching && !root.sessionOpen
                    && !root.centreOpen && root.picker === "")
                    return "osd";
                // A popup outranks everything except an interaction
                // already in progress — it's brief and it's news.
                if (root.notice !== null && !root.searching && !root.sessionOpen
                    && !root.centreOpen && root.picker === "")
                    return "notify";
                if (root.switcherOpen) return "switcher";
                if (root.overviewOpen) return "overview";
                if (root.clipOpen) return "clipboard";
                if (root.centreOpen) return "centre";
                if (root.picker !== "") return "picker";
                if (root.sessionOpen) return "session";
                if (root.searching) return "search";
                // Fullscreen wins over everything except an explicit
                // interaction — video and games shouldn't get a pill
                // hovering over them.
                if (Config.island.hideOnFullscreen && Wm.fullscreen
                    && !pillHover.hovered && !revealArea.containsMouse
                    && !root.expanded)
                    return "hidden";
                if (!root.revealed) return "hidden";
                if (root.expanded) return "expanded";
                if (pillHover.hovered) return "compact";
                return "idle";
            }

            anchors.topMargin: mode === "hidden"
                ? -pill.height - 4
                : (mode === "idle" || mode === "compact"
                   ? Config.island.topMargin
                   : Config.island.topMargin + 2)

            opacity: mode === "hidden" ? 0 : 1

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: root.morphDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: root.morphDuration }
            }

            readonly property bool media: Player.available && Player.title !== ""
            readonly property bool isExpanded: mode === "expanded"

            readonly property bool isSearching: mode === "search"
            readonly property bool isSession: mode === "session"
            readonly property bool isPicker: mode === "picker"
            readonly property bool isNotify: mode === "notify"
            readonly property bool isCentre: mode === "centre"
            readonly property bool isOsd: mode === "osd"
            readonly property bool isAuth: mode === "auth"
            readonly property bool isClipboard: mode === "clipboard"
            readonly property bool isSwitcher: mode === "switcher"
            readonly property bool isOverview: mode === "overview"
            // Expanded and control are the same thing.
            readonly property bool isControl: mode === "expanded"

            Rectangle {
                id: pill

                anchors.left: parent.left

                MouseArea {
                    id: pillClick
                    anchors.fill: parent

                    // Modes with their own interactive content take
                    // their own clicks entirely.
                    enabled: island.mode === "idle"
                             || island.mode === "compact"
                             || island.mode === "hidden"

                    onClicked: {
                        root.expanded = !root.expanded;
                        root.autoExpanded = false;
                        collapseTimer.stop();
                    }
                }

                readonly property int collapsedWidth:
                    Math.max(Config.island.idleWidth,
                             idleMode.implicitWidth + Config.island.padding * 2)

                // One table, not two parallel switches. Adding a mode
                // means one entry here plus its content block — the
                // geometry no longer has to be kept in sync across
                // separate width and height expressions.
                readonly property var geometry: ({
                    hidden:   { w: collapsedWidth, h: Config.island.idleHeight },
                    idle:     { w: collapsedWidth, h: Config.island.idleHeight },
                    compact:  { w: Math.max(Config.island.compactWidth, collapsedWidth),
                                h: Config.island.compactHeight },
                    // Every term is coerced and defaulted. One
                    // undefined value here makes the whole sum NaN,
                    // which leaves the pill with no height at all —
                    // and with clip off in this mode, the content then
                    // renders outside the shape instead of vanishing.
                    //
                    // The tray no longer lives in the control centre,
                    // so its term is gone.
                    expanded: { w: Config.island.controlWidth,
                                h: Config.island.controlHeight
                                   + ((Calendar.currentRows || 5) - 5) * 32
                                   + (island.media ? Config.island.mediaStripHeight : 0)
                                   + (Calendar.available && Calendar.today
                                      && Calendar.today.length > 0
                                      ? Math.min(Calendar.today.length, 3) * 20 + 12
                                      : 0) },
                    search:   { w: Config.island.searchWidth,
                                h: Config.island.searchFieldHeight
                                   + Math.min(Search.results.length, Config.island.searchMaxRows)
                                     * Config.island.searchRowHeight
                                   + (Search.results.length > 0 ? 10 : 0) },
                    session:  { w: Config.island.sessionWidth, h: Config.island.sessionHeight },
                    picker:   { w: Config.island.pickerWidth,  h: Config.island.pickerHeight },
                    notify:   { w: Config.island.notifyWidth,
                                h: Config.island.notifyHeight
                                   + ((root.notice && root.notice.actions.length > 0)
                                      ? Config.island.notifyActionHeight : 0) },
                    centre:   { w: Config.island.centreWidth,  h: Config.island.centreHeight },
                    osd:      { w: Config.island.osdWidth,     h: Config.island.osdHeight },
                    auth:     { w: Config.island.authWidth,    h: Config.island.authHeight },
                    switcher: { w: Math.min(Config.island.switcherWidth,
                                            Math.max(260,
                                                     root.switchList.length
                                                     * (Config.island.switcherTile + 8) + 32)),
                                h: Config.island.switcherHeight },
                    overview: { w: Math.max(260,
                                            Wm.workspaces.length
                                            * (Config.island.overviewCard + 12) + 24),
                                h: Config.island.overviewCard * 0.68 + 36 },
                    clipboard: { w: Config.island.clipWidth,
                                 h: Config.island.searchFieldHeight
                                    + Math.min(root.clipRows, Config.island.clipMaxRows)
                                      * Config.island.clipRowHeight
                                    + (root.clipRows > 0 ? 10 : 0) }
                })

                width:  (geometry[island.mode] || geometry.idle).w
                height: (geometry[island.mode] || geometry.idle).h

                // Theme colours carry no alpha, so it's applied here.
                // The island-bar layer rule blurs whatever shows through.
                function tint(c) {
                    const col = Qt.color(c);
                    return Qt.rgba(col.r, col.g, col.b, Config.island.opacity);
                }

                // Transparent when expanded: the control centre draws
                // its own cards, and a panel behind them would put a
                // seam back around the gaps between them.
                color: island.mode === "expanded"
                    ? "transparent"
                    : tint(island.mode === "idle" || island.mode === "hidden"
                        ? Theme.surfaceLowest
                        : Theme.surfaceContainer)

                radius: Config.island.radius
                // Clipping reveals content by the growing shape, which
                // is right for every mode whose content sits inside the
                // pill. The control centre's cards deliberately extend
                // past it, so a growing clip rectangle sweeps across
                // their edges and cuts them frame by frame — which is
                // the flicker around the outline. Off for that mode.
                clip: true

                // The border fades rather than switching off. Toggling
                // width mid-morph snaps a 1px outline away partway
                // through the animation, which is the flicker around
                // the edge on the way into the control centre.
                border.width: 1
                border.color: Qt.rgba(
                    Qt.color(Theme.outlineVariant).r,
                    Qt.color(Theme.outlineVariant).g,
                    Qt.color(Theme.outlineVariant).b,
                    island.mode === "expanded" ? 0 : 1)

                Behavior on border.color {
                    // `win` is what the Modes/ components call this
                    // window, because Island.qml passes it to them as
                    // `win: root`. Inside Island.qml itself the id is
                    // `root`, so this threw a ReferenceError on every
                    // evaluation and the animation silently fell back
                    // to the 250ms default — the border snapped
                    // instead of fading, which is the flicker the
                    // comment above is about.
                    ColorAnimation { duration: root.fadeOut }
                }

                // Declared first, so it sits beneath the content. The
                // toggles and sliders above it get their clicks; this
                // only catches presses on empty pill.

                Behavior on width {
                    NumberAnimation {
                        duration: root.morphDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: root.morphOvershoot
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: root.morphDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: root.morphOvershoot
                    }
                }
                // The pill's colour is deliberately not animated. In
                // the expanded state it goes transparent so the cards
                // read as separate surfaces, and fading a full-width
                // background in and out underneath a morph and a
                // content fade is three transitions at once.

                IdleMode    { id: idleMode; win: root; island: island; pill: pill }
                SearchMode  { win: root; island: island; pill: pill }
                SessionMode { win: root; island: island; pill: pill }
                PickerMode  { win: root; island: island; pill: pill }
                NotifyMode  { win: root; island: island; pill: pill }
                CentreMode  { win: root; island: island; pill: pill }
                ControlMode { win: root; island: island; pill: pill }
                MediaStrip  { win: root; island: island; pill: pill }
                OsdMode     { win: root; island: island; pill: pill }
                AuthMode    { win: root; island: island; pill: pill }
                ClipboardMode { win: root; island: island; pill: pill }
                SwitcherMode  { win: root; island: island; pill: pill }
                OverviewMode  { win: root; island: island; pill: pill }

                // Scroll over the collapsed pill cycles the face. While
                // an OSD is up it adjusts that value instead, which is
                // what the gesture already means in that moment.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: function(event) {
                        const dy = event.angleDelta.y;

                        if (Osd.active) {
                            const step = dy > 0 ? 5 : -5;
                            if (Osd.kind === "brightness") {
                                Audio.setBrightness(
                                    Math.max(0, Math.min(100, Audio.brightness + step)));
                                Osd.show("brightness", Audio.brightness, false);
                            } else {
                                Audio.setVolume(
                                    Math.max(0, Math.min(100, Audio.volume + step)));
                                Osd.show("volume", Audio.volume, Audio.muted);
                            }
                            return;
                        }

                        if (island.mode === "idle" || island.mode === "compact")
                            root.cycleFace(dy);
                    }
                }

                // A MouseArea rather than a HoverHandler, and declared
                // last so it sits above every control.
                //
                // A child MouseArea with hoverEnabled consumes hover,
                // so a HoverHandler on the pill stopped reporting
                // hovered whenever the cursor was over a calendar day
                // cell or a tile — and the collapse timer started as
                // if the cursor had left the island entirely.
                //
                // acceptedButtons: NoButton means this sees hover but
                // never takes a click, so everything underneath still
                // gets its own presses.
                MouseArea {
                    id: pillHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true

                    readonly property bool hovered: containsMouse

                    onContainsMouseChanged: {
                        root.touch(containsMouse);
                        if (containsMouse) collapseTimer.stop();
                        else if (root.expanded && Config.island.collapseDelay > 0)
                            collapseTimer.restart();
                    }
                }
            }

        }

        function openSettings(page) {
            settingsProc.command = ["qs", "-c", "island", "ipc", "call",
                                    "settings", "page", page];
            settingsProc.running = true;
        }

        Process { id: settingsProc; running: false }

        IpcHandler {
            enabled: root.primary
            target: "island"

            function toggle(): void { root.expanded = !root.expanded }
            function expand(): void { root.expanded = true }
            function collapse(): void { root.expanded = false }

            function setVisibility(mode: string): void {
                if (mode === "always" || mode === "smart")
                    Config.island.visibility = mode;
            }
            function search(): void { root.openSearch() }
            function attention(on: bool): void { root.demandsAttention = on }
            function state(): string { return island.mode }

            // Everything the collapse decision reads. A closing control
            // centre is one of: the hover flag dropping, the collapse
            // timer running, or expanded being cleared elsewhere.
            function hover(): string {
                return "expanded=" + root.expanded
                    + " autoExpanded=" + root.autoExpanded
                    + " pillHover=" + pillHover.containsMouse
                    + " revealArea=" + revealArea.containsMouse
                    + " latch=" + root.hoverLatch
                    + " revealed=" + root.revealed
                    + " collapseTimer=" + collapseTimer.running
                    + " collapseDelay=" + Config.island.collapseDelay
                    + " mode=" + island.mode;
            }

            // Every term the media strip's visibility reads, so a
            // missing strip does not need guessing at.
            function media(): string {
                return "available=" + Player.available
                    + " title='" + Player.title + "'"
                    + " islandMedia=" + island.media
                    + " isControl=" + island.isControl
                    + " mode=" + island.mode
                    + " pillH=" + Math.round(pill.height)
                    + " needH=" + Math.round(Config.island.controlHeight * 0.9)
                    + " controlH=" + Config.island.controlHeight
                    + " stripH=" + Config.island.mediaStripHeight
                    + " expectedPillH="
                    + (Config.island.controlHeight
                       + (island.media ? Config.island.mediaStripHeight : 0));
            }

            function why(): string {
                const r = root.islandRect;
                return "mode=" + island.mode
                    + " visibility=" + root.visibilityMode
                    + " revealed=" + root.revealed
                    + " occluded=" + root.occluded
                    + " overlapped=" + root.overlapped
                    + " fullscreen=" + Wm.fullscreen
                    + " empty=" + Wm.empty
                    + " windows=" + Wm.windows.length
                    + " latch=" + root.hoverLatch
                    + " islandRect=" + Math.round(r.x) + "," + Math.round(r.y)
                    + " " + Math.round(r.width) + "x" + Math.round(r.height)
                    + " screen=" + root.screen.width + "x" + root.screen.height;
            }

            function windows(): string {
                if (Wm.windows.length === 0) return "none";
                return Wm.windows.map(w =>
                    w.x + "," + w.y + " " + w.w + "x" + w.h).join("  |  ");
            }
        }

        IpcHandler {
            enabled: root.primary
            target: "notifications-ui"

            function toggle(): void {
                if (root.centreOpen) root.closeCentre();
                else root.openCentre();
            }
            function show(): void { root.openCentre() }
            function hide(): void { root.closeCentre() }
        }

        IpcHandler {
            enabled: root.primary
            target: "switcher"

            function next(): void { root.openSwitcher(1) }
            function previous(): void { root.openSwitcher(-1) }
            function confirm(): void { root.activateSwitch() }
            function cancel(): void { root.cancelSwitch() }
        }

        IpcHandler {
            enabled: root.primary
            target: "overview"

            function toggle(): void {
                if (root.overviewOpen) root.closeOverview();
                else root.openOverview();
            }
            function show(): void { root.openOverview() }
            function hide(): void { root.closeOverview() }
        }

        IpcHandler {
            enabled: root.primary
            target: "clipboard-ui"

            function toggle(): void {
                if (root.clipOpen) root.closeClipboard();
                else root.openClipboard();
            }
            function show(): void { root.openClipboard() }
            function hide(): void { root.closeClipboard() }
        }

        IpcHandler {
            enabled: root.primary
            target: "picker"

            function toggle(kind: string): void {
                const k = kind === "" ? "wallpaper" : kind;
                if (root.picker === k) root.closePicker();
                else root.openPicker(k);
            }
            function wallpapers(): void { root.openPicker("wallpaper") }
            function palettes(): void { root.openPicker("theme") }
            function icons(): void { root.openPicker("icon") }
            function hide(): void { root.closePicker() }
        }

        IpcHandler {
            enabled: root.primary
            target: "control"

            function toggle(): void {
                if (root.expanded) root.closeControl();
                else root.openControl();
            }
            function show(): void { root.openControl() }
            function hide(): void { root.closeControl() }
        }

        IpcHandler {
            enabled: root.primary
            target: "session"

            function toggle(): void {
                if (root.sessionOpen) root.closeSession();
                else root.openSession();
            }
            function show(): void { root.openSession() }
            function hide(): void { root.closeSession() }
            function run(action: string): void { Session.run(action) }
        }

        // SUPER+R and ALT+Space are bound to launcher toggle.
        IpcHandler {
            enabled: root.primary
            target: "launcher"

            function toggle(): void {
                if (root.searching) root.closeSearch();
                else root.openSearch();
            }
            function show(): void { root.openSearch() }
            function hide(): void { root.closeSearch() }
        }
    }
}
