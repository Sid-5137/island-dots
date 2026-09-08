import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
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

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island-bar"
        exclusiveZone: 0

        // Only grab the keyboard while searching. Holding exclusive
        // focus the rest of the time would swallow every keystroke
        // meant for the focused app.
        WlrLayershell.keyboardFocus: (searching || sessionOpen || centreOpen
                                      || picker !== "" || Polkit.active || clipOpen
                                      || root.expanded)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        property bool searching: false
        property bool sessionOpen: false
        property bool expanded: false

        property string picker: ""          // "" | wallpaper | theme | icon

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

        readonly property bool occluded:
            Wm.fullscreen
            || (visibilityMode === "smart" ? overlapped : !Wm.empty)

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
                root.notice = entry;
                noticeTimer.interval = entry.critical
                    ? Config.island.notifyCriticalDuration
                    : Config.island.notifyDuration;
                noticeTimer.restart();
            }
        }

        Timer {
            id: noticeTimer
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
            // Expanded and control are the same thing.
            readonly property bool isControl: mode === "expanded"

            Rectangle {
                id: pill

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
                    expanded: { w: Config.island.controlWidth,
                                h: Config.island.controlHeight
                                   + (island.media ? Config.island.mediaStripHeight : 0) },
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

                color: tint(island.mode === "idle" || island.mode === "hidden"
                    ? Theme.surfaceLowest
                    : Theme.surfaceContainer)

                radius: Config.island.radius
                // Confines content to the pill's bounds, so the album
                // art and text are revealed BY the growing shape rather
                // than drawing outside it while it's still small.
                clip: true

                border.width: 1
                border.color: Theme.outlineVariant

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
                Behavior on color {
                    ColorAnimation { duration: root.morphDuration }
                }

                // The old expanded view (large clock, media card)
                // lived here. The control centre replaces it — see

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

                HoverHandler {
                    id: pillHover

                    onHoveredChanged: {
                        root.touch(hovered);
                        if (hovered) collapseTimer.stop();
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
            target: "island"

            function toggle(): void { root.expanded = !root.expanded }
            function expand(): void { root.expanded = true }
            function collapse(): void { root.expanded = false }

            function setVisibility(mode: string): void { Config.island.visibility = mode }
            function search(): void { root.openSearch() }
            function attention(on: bool): void { root.demandsAttention = on }
            function state(): string { return island.mode }

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
            target: "notifications-ui"

            function toggle(): void {
                if (root.centreOpen) root.closeCentre();
                else root.openCentre();
            }
            function show(): void { root.openCentre() }
            function hide(): void { root.closeCentre() }
        }

        IpcHandler {
            target: "clipboard-ui"

            function toggle(): void {
                if (root.clipOpen) root.closeClipboard();
                else root.openClipboard();
            }
            function show(): void { root.openClipboard() }
            function hide(): void { root.closeClipboard() }
        }

        IpcHandler {
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
            target: "control"

            function toggle(): void {
                if (root.expanded) root.closeControl();
                else root.openControl();
            }
            function show(): void { root.openControl() }
            function hide(): void { root.closeControl() }
        }

        IpcHandler {
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
