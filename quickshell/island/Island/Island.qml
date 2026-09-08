import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// ─────────────────────────────────────────────────────────────
// Island — step 3c
//
// Four states: hidden → idle → compact → expanded.
// Collapsed is always the clock; media lives in the expanded view.
//
// Motion notes, because this is the part that's easy to get wrong:
//
//   · The shape uses OutBack with a SMALL overshoot. A large one
//     applied to width and height at once reads as a wobble in two
//     axes rather than a single spring.
//   · Outgoing content leaves fast (110ms). Incoming content waits
//     ~150ms before appearing, so the two never overlap and the text
//     is never visible inside a pill that's still growing.
//   · Content scales as well as fades — 0.94 → 1.0. Fading alone
//     makes text pop; scaling makes it grow into place.
// ─────────────────────────────────────────────────────────────

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island-bar"
        exclusiveZone: 0

        // Only grab the keyboard while searching. Holding exclusive
        // focus the rest of the time would swallow every keystroke
        // meant for the focused app.
        WlrLayershell.keyboardFocus: (searching || sessionOpen || centreOpen
                                      || picker !== "" || win.expanded)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        property bool searching: false
        property bool sessionOpen: false
        property bool expanded: false


        // Picker: a horizontal strip of wallpapers, themes or icon sets
        // scrolled inside the pill. Same idea as search — the island is
        // the surface, not a launcher for other windows.
        property string picker: ""          // "" | wallpaper | theme | icon

        // A notification popup takes the island over briefly, then
        // hands it back to whatever it was doing. The centre is a
        // deliberate mode you open and close.
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
            win.expanded = true;
        }

        function closeControl() { win.expanded = false }
        // Which destructive action is armed and waiting for a second
        // press. Empty means nothing is armed.
        property string armed: ""
        // Keyboard selection within the session row.
        property int sessionIndex: 0

        function openSession() {
            sessionOpen = true;
            searching = false;
            win.expanded = false;
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
            win.expanded = false;
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
                            Config.island.searchFieldHeight
                              + Config.island.searchMaxRows * Config.island.searchRowHeight)
                      + Config.island.topMargin
                      + 60
        color: "transparent"

        // ── Motion constants ─────────────────────────────────
        // One place to tune the whole feel.

        readonly property int morphDuration: Config.motion.morphDuration
        readonly property real morphOvershoot: Config.motion.morphOvershoot
        readonly property int fadeOut: Config.motion.fadeOut
        readonly property int fadeIn: Config.motion.fadeIn

        // ── Visibility ───────────────────────────────────────
        // TODO: bind to Config once it exists.

        readonly property string visibilityMode: Config.island.visibility
        readonly property int revealZone: Config.island.revealZone
        property bool demandsAttention: false

        // ── Occlusion ────────────────────────────────────────
        //
        // "smart" asks whether a window actually reaches the strip the
        // island sits in. Hiding because *any* window exists means the
        // island vanishes on a workspace where nothing is anywhere
        // near it, which is most of them.

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

        // Hover is latched with a grace period. Raw hover state and
        // geometry feed each other: the pill grows or shrinks out from
        // under the cursor, hover drops, the pill hides, the cursor is
        // over it again — which is the flicker that only showed up
        // with windows present, because that's when hiding is live.
        property bool hoverLatch: false

        Timer {
            id: unlatch
            interval: Config.island.hoverGrace
            onTriggered: win.hoverLatch = false
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
            || win.expanded
            || searching
            || sessionOpen
            || picker !== ""
            || notice !== null
            || centreOpen

        // One Region with an explicit item. A nested pair of child
        // Regions produced a mask that didn't cover the pill, so
        // clicks landed on the desktop instead of the picker cards —
        // the same shape that made the tiles feel dead.
        //
        // `island` is bound to the pill's size, so this tracks every
        // morph without a second region to keep in sync.
        mask: Region {
            item: win.revealed ? island : revealStrip
        }

        // ── Attention ────────────────────────────────────────

        property bool autoExpanded: false

        Connections {
            target: Player
            function onTrackChanged() {
                win.demandsAttention = true;
                if (Config.island.expandOnTrackChange) {
                    win.autoExpanded = true;
                    win.expanded = true;
                }
                attentionTimer.restart();
            }
        }

        // An armed action disarms itself if you hesitate, so a stray
        // click can't leave the shutdown button primed.
        Timer {
            id: armTimer
            interval: 3000
            onTriggered: win.armed = ""
        }

        Connections {
            target: Notifications
            function onArrived(entry) {
                win.notice = entry;
                noticeTimer.interval = entry.critical
                    ? Config.island.notifyCriticalDuration
                    : Config.island.notifyDuration;
                noticeTimer.restart();
            }
        }

        Timer {
            id: noticeTimer
            onTriggered: win.notice = null
        }

        Timer {
            id: attentionTimer
            interval: Config.island.attentionDuration
            onTriggered: {
                win.demandsAttention = false;
                if (win.autoExpanded) {
                    win.expanded = false;
                    win.autoExpanded = false;
                }
            }
        }

        // Collapse shortly after the cursor leaves. The grace period
        // stops a brush past the edge snapping it shut mid-interaction.
        Timer {
            id: collapseTimer
            interval: Config.island.collapseDelay
            onTriggered: {
                if (!pillHover.hovered && !win.autoExpanded)
                    win.expanded = false;
            }
        }

        // ── Reveal zone ──────────────────────────────────────

        Item {
            id: revealStrip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: win.revealZone

            MouseArea {
                id: revealArea
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: win.touch(containsMouse)
            }
        }

        // ── The pill ─────────────────────────────────────────

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
                // A popup outranks everything except an interaction
                // already in progress — it's brief and it's news.
                if (win.notice !== null && !win.searching && !win.sessionOpen
                    && !win.centreOpen && win.picker === "")
                    return "notify";
                if (win.centreOpen) return "centre";
                if (win.picker !== "") return "picker";
                if (win.sessionOpen) return "session";
                if (win.searching) return "search";
                // Fullscreen wins over everything except an explicit
                // interaction — video and games shouldn't get a pill
                // hovering over them.
                if (Config.island.hideOnFullscreen && Wm.fullscreen
                    && !pillHover.hovered && !revealArea.containsMouse
                    && !win.expanded)
                    return "hidden";
                if (!win.revealed) return "hidden";
                if (win.expanded) return "expanded";
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
                    duration: win.morphDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: win.morphDuration }
            }

            readonly property bool media: Player.available && Player.title !== ""
            readonly property bool isExpanded: mode === "expanded"

            readonly property bool isSearching: mode === "search"
            readonly property bool isSession: mode === "session"
            readonly property bool isPicker: mode === "picker"
            readonly property bool isNotify: mode === "notify"
            readonly property bool isCentre: mode === "centre"
            // Expanded and control are the same thing.
            readonly property bool isControl: mode === "expanded"

            Rectangle {
                id: pill

                // FIRST child, so it sits beneath every content block.
                // It had drifted to the end as modes were added, which
                // put it on top and made it swallow every click meant
                // for the tiles, sliders and picker cards.
                MouseArea {
                    id: pillClick
                    anchors.fill: parent

                    // Modes with their own interactive content take
                    // their own clicks entirely.
                    enabled: island.mode === "idle"
                             || island.mode === "compact"
                             || island.mode === "hidden"

                    onClicked: {
                        win.expanded = !win.expanded;
                        win.autoExpanded = false;
                        collapseTimer.stop();
                    }
                }


                // Size is ONE binding driven by state, not a set of
                // PropertyChanges. A PropertyChanges that overrides a
                // bound property replaces the binding rather than
                // animating through it, which made some transitions
                // jump instead of morph. With a single expression the
                // Behavior below applies to every change uniformly.
                readonly property int collapsedWidth:
                    Math.max(Config.island.idleWidth,
                             idleContent.implicitWidth + Config.island.padding * 2)

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
                    notify:   { w: Config.island.notifyWidth,  h: Config.island.notifyHeight },
                    centre:   { w: Config.island.centreWidth,  h: Config.island.centreHeight }
                })

                width:  (geometry[island.mode] || geometry.idle).w
                height: (geometry[island.mode] || geometry.idle).h

                color: island.mode === "idle" || island.mode === "hidden"
                    ? Theme.surfaceLowest
                    : Theme.surfaceContainer

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

                // ── Picker ───────────────────────────────────
                // Wallpapers, colour schemes and icon themes as one
                // horizontal strip inside the pill. Scroll to browse,
                // click to apply — the choice lands immediately rather
                // than after a trip through a settings window.


                // ── Notification popup ───────────────────────
                // Brief, and gone. The island takes it over for a few
                // seconds rather than a card appearing in a corner —
                // if the shell has one shape, news arrives in it too.

                Item {
                    id: noticeContent
                    anchors.fill: parent
                    anchors.margins: 16

                    opacity: (island.isNotify
                              && pill.width > Config.island.notifyWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    readonly property var n: win.notice

                    Rectangle {
                        id: noticeIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 46
                        radius: 10
                        color: noticeContent.n && noticeContent.n.critical
                            ? Theme.error : Theme.surfaceHigh
                        clip: true

                        Image {
                            id: noticeImg
                            anchors.fill: parent
                            anchors.margins: noticeContent.n && noticeContent.n.image ? 0 : 11
                            source: {
                                if (!noticeContent.n) return "";
                                if (noticeContent.n.image) return noticeContent.n.image;
                                if (noticeContent.n.appIcon)
                                    return Quickshell.iconPath(noticeContent.n.appIcon, true);
                                return "";
                            }
                            fillMode: noticeContent.n && noticeContent.n.image
                                ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !noticeImg.visible
                            text: "\uf0f3"
                            color: noticeContent.n && noticeContent.n.critical
                                ? Theme.textOnError : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        anchors.left: noticeIcon.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: noticeContent.n ? noticeContent.n.summary : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: noticeContent.n ? noticeContent.n.body : ""
                            visible: text !== ""
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            // Senders send markup whether or not it's
                            // advertised; rendering it raw shows tags.
                            textFormat: Text.StyledText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: noticeContent.n ? noticeContent.n.appName : ""
                            color: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 2
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    // Click runs the first action if there is one, and
                    // dismisses either way — a notification you've
                    // acted on shouldn't linger.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: function(mouse) {
                            const n = noticeContent.n;
                            if (mouse.button === Qt.LeftButton && n
                                && n.actions.length > 0) {
                                Notifications.invoke(n, 0);
                            }
                            win.dismissNotice();
                        }
                    }
                }

                // ── Notification centre ──────────────────────

                Item {
                    id: centreContent
                    anchors.fill: parent
                    anchors.margins: 16

                    opacity: (island.isCentre
                              && pill.width > Config.island.centreWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    Item {
                        id: centreHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifications.count > 0
                                ? Notifications.count + (Notifications.count === 1
                                    ? " notification" : " notifications")
                                : "Notifications"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            renderType: Text.NativeRendering
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Notifications.count > 0
                            width: 66
                            height: 24
                            radius: 7
                            color: clearHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Clear"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: clearHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifications.clear()
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Theme.outlineVariant
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Notifications.count === 0
                        text: "Nothing to catch up on"
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        renderType: Text.NativeRendering
                    }

                    ListView {
                        id: centreList
                        anchors.top: centreHeader.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        spacing: 6
                        model: Notifications.history

                        delegate: Rectangle {
                            required property var modelData

                            width: centreList.width
                            height: Config.island.centreRowHeight
                            radius: 10
                            color: rowHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Critical keeps a mark in history, not
                            // just in the popup that already went by.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                width: 3
                                radius: 1.5
                                visible: modelData.critical
                                color: Theme.error
                            }

                            Rectangle {
                                id: rowIconBox
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38
                                height: 38
                                radius: 9
                                color: Theme.surfaceHigh
                                clip: true

                                Image {
                                    id: rowImg
                                    anchors.fill: parent
                                    anchors.margins: modelData.image ? 0 : 9
                                    source: modelData.image
                                        ? modelData.image
                                        : (modelData.appIcon
                                           ? Quickshell.iconPath(modelData.appIcon, true) : "")
                                    fillMode: modelData.image
                                        ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !rowImg.visible
                                    text: "\uf0f3"
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                            }

                            Column {
                                anchors.left: rowIconBox.right
                                anchors.leftMargin: 12
                                anchors.right: rowDismiss.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modelData.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.body
                                    visible: text !== ""
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    textFormat: Text.StyledText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.appName
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                id: rowDismiss
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u00d7"
                                color: dismissHover.containsMouse
                                    ? Theme.text : Theme.outline
                                font.family: Theme.fontFamily
                                font.pixelSize: 18

                                MouseArea {
                                    id: dismissHover
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifications.dismiss(modelData)
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.actions.length > 0
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (modelData.actions.length > 0)
                                        Notifications.invoke(modelData, 0);
                                    Notifications.dismiss(modelData);
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        focus: island.isCentre
                        Keys.onEscapePressed: win.closeCentre()
                    }
                }

                Item {
                    id: pickerContent
                    anchors.fill: parent

                    opacity: (island.isPicker
                              && pill.width > Config.island.pickerWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    readonly property var items: {
                        switch (win.picker) {
                            case "wallpaper": return Wallpaper.list;
                            case "theme": return [
                                "scheme-monochrome", "scheme-neutral",
                                "scheme-tonal-spot", "scheme-vibrant",
                                "scheme-expressive", "scheme-content",
                                "scheme-fidelity", "scheme-rainbow"
                            ];
                            case "icon": return Theming.available;
                            default: return [];
                        }
                    }

                    readonly property string current: {
                        switch (win.picker) {
                            case "wallpaper": return Wallpaper.current;
                            case "theme": return Config.wallpaper.scheme;
                            case "icon": return Config.appearance.iconTheme;
                            default: return "";
                        }
                    }

                    function choose(v) {
                        switch (win.picker) {
                            case "wallpaper": Wallpaper.set(v); break;
                            case "theme":
                                Config.wallpaper.scheme = v;
                                if (Wallpaper.current !== "") Wallpaper.generate(Wallpaper.current);
                                break;
                            case "icon": Config.appearance.iconTheme = v; break;
                        }
                    }

                    // ── Header: the three kinds, as tabs ─────

                    Row {
                        id: pickerTabs
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Repeater {
                            model: [
                                { key: "wallpaper", label: "Wallpaper" },
                                { key: "theme",     label: "Palette" },
                                { key: "icon",      label: "Icons" }
                            ]

                            Rectangle {
                                required property var modelData
                                readonly property bool active: win.picker === modelData.key

                                width: tabLabel.implicitWidth + 24
                                height: 26
                                radius: 8
                                color: active ? Theme.primary
                                    : (tabHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                                Behavior on color { ColorAnimation { duration: 140 } }

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: parent.active ? Theme.textOnPrimary : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    id: tabHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.openPicker(modelData.key)
                                }
                            }
                        }
                    }

                    // ── Strip ────────────────────────────────

                    ListView {
                        id: strip
                        anchors.top: pickerTabs.bottom
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.bottomMargin: 14

                        orientation: ListView.Horizontal
                        spacing: 10
                        clip: true
                        model: pickerContent.items

                        // Wheel scrolls the strip; a horizontal list
                        // with no visible scrollbar is otherwise only
                        // reachable by dragging.
                        WheelHandler {
                            onWheel: function(e) {
                                strip.contentX -= e.angleDelta.y;
                                strip.returnToBounds();
                            }
                        }

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool active: modelData === pickerContent.current
                            readonly property bool isImage: win.picker === "wallpaper"

                            width: isImage ? 132 : 116
                            height: strip.height
                            radius: 10
                            color: Theme.surfaceHigh
                            border.width: active ? 2 : 1
                            border.color: active ? Theme.primary
                                : (cardHover.containsMouse ? Theme.outlineVariant : "transparent")
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: parent.active ? 2 : 1
                                visible: parent.isImage
                                source: parent.isImage ? "file://" + modelData : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                // Decoding a 4K wallpaper at full size
                                // for a 132px card is pure waste.
                                sourceSize.width: 260
                            }

                            // Palettes and icon sets have no thumbnail,
                            // so they get their name and a swatch.
                            Column {
                                anchors.centerIn: parent
                                visible: !parent.isImage
                                spacing: 8
                                width: parent.width - 16

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 34; height: 34; radius: 17
                                    color: Theme.primary
                                    visible: win.picker === "theme"
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: String(modelData).replace("scheme-", "")
                                    color: parent.parent.active ? Theme.primary : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                id: cardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pickerContent.choose(modelData)
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        focus: island.isPicker
                        Keys.onEscapePressed: win.closePicker()
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: win.morphDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: win.morphOvershoot
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: win.morphDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: win.morphOvershoot
                    }
                }
                Behavior on color {
                    ColorAnimation { duration: win.morphDuration }
                }

                // ── Collapsed content ────────────────────────

                Row {
                    id: idleContent
                    anchors.centerIn: parent
                    spacing: 12

                    // Gated on the pill's ACTUAL height, not on the
                    // state — content can't appear inside a shape that
                    // hasn't grown to fit it, however the morph is tuned.
                    opacity: (!island.isExpanded && !island.isSearching
                              && !island.isSession && !island.isControl && !island.isPicker
                              && !island.isNotify && !island.isCentre
                              && pill.height < Config.island.compactHeight + 8) ? 1 : 0
                    scale: opacity > 0.5 ? 1.0 : 0.94
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutCubic }
                    }

                    // ── Revealed on hover ────────────────────
                    // Workspaces and the playing indicator are detail,
                    // not glanceable information. They arrive when you
                    // approach the pill and leave when you don't.

                    Row {
                        id: hoverLeft
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        readonly property bool shown: island.mode === "compact"

                        width: shown ? implicitWidth : 0
                        opacity: shown ? 1 : 0
                        clip: true

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // Playing indicator. Three bars beat a label:
                        // it reads instantly and costs almost no width.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            visible: island.media
                            width: visible ? implicitWidth : 0

                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 2
                                    height: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.primary
                                    radius: 1

                                    SequentialAnimation on height {
                                        running: Player.playing && hoverLeft.shown
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: index * 120 }
                                        NumberAnimation { to: 11; duration: 320; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 4;  duration: 320; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }
                        }

                        // Workspaces as dashes: the active one stretches,
                        // one holding windows is wider than an empty one.
                        // Reads at a glance without relying on colour.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: Config.island.showWorkspaces && Wm.workspaces.length > 0
                            width: visible ? implicitWidth : 0

                            Repeater {
                                model: Wm.workspaces

                                Rectangle {
                                    required property var modelData
                                    readonly property bool active: modelData.id === Wm.activeId

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: active ? 16 : (modelData.windows > 0 ? 7 : 4)
                                    height: 3
                                    radius: 1.5
                                    color: active
                                        ? Theme.primary
                                        : (modelData.windows > 0 ? Theme.textDim : Theme.outline)

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Wm.switchTo(modelData.id)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 13
                            color: Theme.outlineVariant
                        }
                    }

                    // ── Always visible ───────────────────────
                    // Time and date are the glanceable pair. Nothing
                    // else earns permanent space.

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: clock.time
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Config.island.fontSize
                        font.weight: Config.island.fontWeight
                        font.letterSpacing: 1.2
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: clock.date
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Config.island.fontSize - 1
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        renderType: Text.NativeRendering
                    }
                }

                // ── Expanded content ─────────────────────────

                // The old expanded view (large clock, media card)
                // lived here. The control centre replaces it — see
                // controlContent below.


                // ── Search ───────────────────────────────────
                // The launcher IS the island: rather than a separate
                // window, the pill stretches into a search field and
                // grows downward as results come in.

                Item {
                    id: searchContent
                    anchors.fill: parent

                    // Same geometry gate as the other content: the
                    // field can't render inside a pill that hasn't
                    // widened to hold it yet.
                    opacity: (island.isSearching
                              && pill.width > Config.island.searchWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    Item {
                        id: fieldRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Config.island.searchFieldHeight

                        Text {
                            id: caret
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u276f"
                            color: Theme.primary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeNormal
                            renderType: Text.NativeRendering
                        }

                        TextInput {
                            id: input
                            Component.onCompleted: win.searchInput = input

                            anchors.left: caret.right
                            anchors.leftMargin: 12
                            anchors.right: hitCount.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            selectionColor: Qt.rgba(1, 1, 1, 0.25)
                            selectedTextColor: Theme.text
                            clip: true

                            onTextChanged: {
                                Search.query = text;
                                if (win.searchList) win.searchList.currentIndex = 0;
                            }

                            Keys.onEscapePressed: win.closeSearch()
                            Keys.onReturnPressed: win.runSelected()
                            Keys.onEnterPressed: win.runSelected()
                            Keys.onDownPressed: results.incrementCurrentIndex()
                            Keys.onUpPressed: results.decrementCurrentIndex()

                            Keys.onPressed: function(event) {
                                if (event.modifiers & Qt.ControlModifier) {
                                    if (event.key === Qt.Key_J) {
                                        results.incrementCurrentIndex();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_K) {
                                        results.decrementCurrentIndex();
                                        event.accepted = true;
                                    }
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: input.text === ""
                                text: "Search"
                                color: Theme.outline
                                font: input.font
                                renderType: Text.NativeRendering
                            }
                        }

                        Text {
                            id: hitCount
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: input.text === "" ? "" : Search.results.length
                            color: Theme.outline
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            renderType: Text.NativeRendering
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            height: 1
                            color: Theme.outlineVariant
                            opacity: Search.results.length > 0 && input.text !== "" ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    ListView {
                        id: results
                        Component.onCompleted: win.searchList = results

                        anchors.top: fieldRow.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 4
                        anchors.bottomMargin: 6

                        model: Search.results
                        clip: true
                        currentIndex: 0
                        highlightMoveDuration: 110
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 44
                        preferredHighlightEnd: height - 44

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool active: index === results.currentIndex

                            width: results.width
                            height: Config.island.searchRowHeight
                            color: active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: parent.active ? 20 : 0
                                color: Theme.primary
                                Behavior on height {
                                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                                }
                            }

                            IconImage {
                                id: rowIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 22
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            Text {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 12
                                anchors.right: rowGeneric.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: parent.active ? Theme.primary : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                id: rowGeneric
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 150)
                                horizontalAlignment: Text.AlignRight
                                text: modelData.genericName || ""
                                color: Theme.outline
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    results.currentIndex = index;
                                    win.runSelected();
                                }
                            }
                        }
                    }
                }


                // ── Session ──────────────────────────────────
                // Power actions, in the island rather than a panel.
                // Destructive ones arm on first press and run on the
                // second, so a misclick can't reboot the machine.

                Item {
                    id: sessionContent
                    anchors.fill: parent

                    opacity: (island.isSession
                              && pill.width > Config.island.sessionWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: Session.actions

                            Rectangle {
                                required property var modelData

                                required property int index

                                readonly property bool armed: win.armed === modelData.id
                                readonly property bool danger: Session.isDestructive(modelData.id)
                                readonly property bool selected:
                                    win.sessionIndex === index || btnHover.containsMouse

                                width: 78
                                height: 84
                                radius: 10
                                color: armed
                                    ? Theme.error
                                    : (selected ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                                border.width: 1
                                border.color: armed
                                    ? Theme.error
                                    : (selected ? Theme.outlineVariant : "transparent")

                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyph
                                        color: parent.parent.armed
                                            ? Theme.textOnError
                                            : (parent.parent.danger && parent.parent.selected
                                               ? Theme.error : Theme.text)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 22
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: parent.parent.armed ? "Confirm" : modelData.label
                                        color: parent.parent.armed ? Theme.textOnError : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.letterSpacing: 0.8
                                        renderType: Text.NativeRendering
                                    }
                                }

                                MouseArea {
                                    id: btnHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.runAction(modelData.id)
                                    // Hovering moves the keyboard
                                    // selection too, so the two never
                                    // disagree about what's active.
                                    onContainsMouseChanged: {
                                        if (containsMouse) win.sessionIndex = index;
                                    }
                                }
                            }
                        }
                    }

                    // Escape closes. Focus lands here because the
                    // window holds exclusive keyboard focus while the
                    // session state is active.
                    Item {
                        anchors.fill: parent
                        focus: island.isSession

                        Keys.onEscapePressed: win.closeSession()
                        Keys.onLeftPressed: win.moveSession(-1)
                        Keys.onRightPressed: win.moveSession(1)
                        Keys.onReturnPressed: win.activateSession()
                        Keys.onEnterPressed: win.activateSession()

                        Keys.onPressed: function(event) {
                            // h/l as well, for the vim-inclined.
                            if (event.key === Qt.Key_H) {
                                win.moveSession(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_L) {
                                win.moveSession(1);
                                event.accepted = true;
                            }
                        }
                    }
                }


                // ── Control centre ───────────────────────────
                // Calendar on the left, quick toggles and sliders on
                // the right. Same in-pill approach as search and
                // session — no separate window.

                Item {
                    id: controlContent
                    anchors.fill: parent
                    anchors.margins: 18
                    anchors.bottomMargin: island.media
                        ? Config.island.mediaStripHeight + 2 : 18

                    opacity: (island.isControl
                              && pill.width > Config.island.controlWidth * 0.8) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    // ── Clock ────────────────────────────────
                    // Heads the calendar column: time and date belong
                    // together, and the corner was an odd place for it.

                    Row {
                        id: bigClock
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: 10
                        width: 266

                        Text {
                            id: clockTime
                            anchors.bottom: parent.bottom
                            text: clock.time
                            color: Theme.primary
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.6
                            renderType: Text.NativeRendering
                        }

                        Text {
                            // Sits on the time's baseline rather than
                            // centred, so the pair reads as one line.
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            text: clock.date
                            color: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.letterSpacing: 1.2
                            renderType: Text.NativeRendering
                        }
                    }

                    // Right end of the clock line, so the left column
                    // reads as one row: time and date at the start,
                    // charge at the finish.
                    BatteryRing {
                        id: batteryRing
                        visible: Battery.present

                        anchors.left: parent.left
                        anchors.leftMargin: calendar.width - width
                        anchors.verticalCenter: bigClock.verticalCenter

                        // Sized to the clock line rather than standing
                        // above it — it's a status glance, not a
                        // headline.
                        width: 38
                        height: 38

                        level: Battery.level
                        charging: Battery.charging
                        low: Battery.low

                    }

                    // ── Calendar ─────────────────────────────

                    Item {
                        id: calendar
                        anchors.left: parent.left
                        anchors.top: bigClock.bottom
                        anchors.topMargin: 16
                        height: calHeader.height + 6 + weekdays.height + 4 + dayGrid.height
                        width: 266

                        // Month being shown; offset from the current
                        // one so the arrows can page without touching
                        // the clock.
                        property int monthOffset: 0
                        property var shown: {
                            const d = new Date(clockSource.date);
                            d.setDate(1);
                            d.setMonth(d.getMonth() + monthOffset);
                            return d;
                        }
                        readonly property int daysInMonth:
                            new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
                        // Monday-first, so shift Sunday from 0 to 6.
                        readonly property int firstWeekday:
                            (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7

                        Item {
                            id: calHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 30

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(calendar.shown, "MMMM yyyy")
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLarge
                                font.letterSpacing: 0.8
                                renderType: Text.NativeRendering
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Repeater {
                                    model: [{ g: "\u2039", d: -1 }, { g: "\u203a", d: 1 }]
                                    Rectangle {
                                        required property var modelData
                                        width: 24; height: 24; radius: 6
                                        color: navHover.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.g
                                            color: Theme.textDim
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            id: navHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: calendar.monthOffset += modelData.d
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            id: weekdays
                            anchors.top: calHeader.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            spacing: 0

                            Repeater {
                                model: ["M", "T", "W", "T", "F", "S", "S"]
                                Text {
                                    required property var modelData
                                    width: 38
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.letterSpacing: 1
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        Grid {
                            id: dayGrid
                            anchors.top: weekdays.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            columns: 7
                            spacing: 0

                            Repeater {
                                model: calendar.firstWeekday + calendar.daysInMonth

                                Item {
                                    required property int index
                                    readonly property int day: index - calendar.firstWeekday + 1
                                    readonly property bool isToday:
                                        calendar.monthOffset === 0
                                        && day === clockSource.date.getDate()

                                    width: 38
                                    height: 32
                                    visible: true

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 30; height: 30; radius: 8
                                        color: parent.isToday ? Theme.primary : "transparent"
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.day > 0
                                        text: parent.day
                                        color: parent.isToday ? Theme.textOnPrimary : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeNormal
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: calendar.right
                        anchors.leftMargin: 18
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        width: 1
                        color: Theme.outlineVariant
                    }

                    // ── Quick toggles ────────────────────────
                    // Square tiles rather than wide rows: the same
                    // column fits six controls instead of two, and a
                    // grid reads faster than a stack of labelled bars.

                    Grid {
                        id: tiles
                        anchors.left: calendar.right
                        anchors.leftMargin: 36
                        anchors.top: parent.top
                        columns: 3
                        spacing: 12

                        // Width is stated, not anchored to both sides.
                        // A Grid takes its width from its children, and
                        // the children took theirs from `cell` — which
                        // read the Grid's width. That loop collapsed the
                        // tiles to a fraction of their size, which is
                        // why they came out small and the glyphs looked
                        // wrong inside them.
                        readonly property int columnWidth:
                            controlContent.width - calendar.width - 36

                        readonly property int cell:
                            Math.floor((columnWidth - spacing * (columns - 1)) / columns)

                        width: columnWidth

                        Repeater {
                            model: [
                                { key: "wifi",     label: "Wi-Fi" },
                                { key: "bt",       label: "Bluetooth" },
                                { key: "mic",      label: "Mic" },
                                { key: "dnd",      label: "Focus" },
                                { key: "caffeine", label: "Awake" },
                                { key: "settings", label: "Settings" }
                            ]

                            Tile {
                                required property var modelData

                                width: tiles.cell
                                height: tiles.cell

                                label: modelData.label
                                hasSecondary: modelData.key === "wifi" || modelData.key === "bt"

                                active: {
                                    switch (modelData.key) {
                                        case "wifi":     return Network.wifiEnabled;
                                        case "bt":       return Bluetooth.powered;
                                        case "mic":      return !Audio.micMuted;
                                        case "dnd":      return Config.island.dnd;
                                        case "caffeine": return Config.island.caffeine;
                                        default:         return false;
                                    }
                                }

                                glyph: {
                                    switch (modelData.key) {
                                        case "wifi":     return Network.icon;
                                        case "bt":       return Bluetooth.icon;
                                        case "mic":      return Audio.micIcon;
                                        case "dnd":      return Config.island.dnd ? "\uf1f6" : "\uf0f3";
                                        case "notif":    return Notifications.count > 0 ? "\uf0f3" : "\uf1f6";
                                        case "caffeine": return "\uf0f4";
                                        default:         return "\uf013";
                                    }
                                }

                                sub: {
                                    switch (modelData.key) {
                                        case "wifi": return Network.label;
                                        case "bt":   return Bluetooth.label;
                                        case "mic":  return Audio.micMuted ? "Muted" : "Live";
                                        case "dnd":  return Config.island.dnd ? "On" : "Off";
                                        case "caffeine": return Config.island.caffeine ? "On" : "Off";
                                        default:     return "Open";
                                    }
                                }

                                onTriggered: {
                                    switch (modelData.key) {
                                        case "wifi":     Network.toggle(); break;
                                        case "bt":       Bluetooth.toggle(); break;
                                        case "mic":      Audio.toggleMic(); break;
                                        case "dnd":      Config.island.dnd = !Config.island.dnd; break;
                                        case "caffeine": Config.island.caffeine = !Config.island.caffeine; break;
                                        default:
                                            win.closeControl();
                                            settingsIpc.open("island");
                                    }
                                }

                                onSecondary: {
                                    win.closeControl();
                                    settingsIpc.open("network");
                                }

                            }
                        }
                    }

                    // ── Sliders ──────────────────────────────
                    // Full column width and a taller grab area: a 4px
                    // track is fine to look at and miserable to hit
                    // with a touchpad.

                    Column {
                        id: sliders
                        anchors.left: calendar.right
                        anchors.leftMargin: 36
                        anchors.top: tiles.bottom
                        anchors.topMargin: 22
                        width: tiles.columnWidth
                        spacing: 12

                        Repeater {
                            model: [{ key: "vol" }, { key: "bright" }]

                            Item {
                                required property var modelData
                                readonly property bool isVol: modelData.key === "vol"
                                readonly property int value:
                                    isVol ? Audio.volume : Audio.brightness

                                width: parent.width
                                height: 38

                                Text {
                                    id: sIcon
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    text: parent.isVol ? Audio.volumeIcon : Audio.brightnessIcon
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 17

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: parent.parent.isVol
                                        onClicked: Audio.toggleMute()
                                    }
                                }

                                Item {
                                    id: sTrack
                                    anchors.left: sIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: sValue.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.10)

                                        Rectangle {
                                            width: Math.max(8, parent.width * (sTrack.parent.value / 100))
                                            height: parent.height
                                            radius: 4
                                            color: Theme.primary
                                        }
                                    }

                                    Rectangle {
                                        id: knob
                                        width: 14
                                        height: 14
                                        radius: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(sTrack.width - width,
                                            (sTrack.parent.value / 100) * sTrack.width - width / 2))
                                        color: Theme.primary
                                        border.width: 2
                                        border.color: Theme.surfaceContainer
                                        opacity: sDrag.containsMouse || sDrag.pressed ? 1 : 0
                                        scale: sDrag.pressed ? 1.2 : 1

                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                    }

                                    MouseArea {
                                        id: sDrag
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function apply(mx) {
                                            const r = Math.max(0, Math.min(1, mx / sTrack.width));
                                            const v = Math.round(r * 100);
                                            if (sTrack.parent.isVol) Audio.setVolume(v);
                                            else Audio.setBrightness(v);
                                        }

                                        onPressed: function(m) { apply(m.x) }
                                        onPositionChanged: function(m) { if (pressed) apply(m.x) }
                                        onWheel: function(w) {
                                            const step = w.angleDelta.y > 0 ? 5 : -5;
                                            const v = Math.max(0, Math.min(100, sTrack.parent.value + step));
                                            if (sTrack.parent.isVol) Audio.setVolume(v);
                                            else Audio.setBrightness(v);
                                        }
                                    }
                                }

                                Text {
                                    id: sValue
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    // Three digits at most, so the label
                                    // only needs room for "100" — the
                                    // rest was dead space the track
                                    // could have used.
                                    width: 28
                                    horizontalAlignment: Text.AlignRight
                                    text: parent.value
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        focus: island.isControl
                        Keys.onEscapePressed: win.closeControl()
                    }
                }

                // ── Now playing strip ────────────────────────
                // Sits below the control centre when something is
                // playing, so media and controls share one surface
                // instead of being separate modes.

                Item {
                    id: mediaStrip
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    // Inset from the bottom edge. Anchored flush, it
                    // covered the pill's own border, which is what made
                    // the lower edge look like it was missing.
                    anchors.bottomMargin: 14
                    height: Config.island.mediaStripHeight - 14

                    opacity: (island.isControl && island.media
                              && pill.height > Config.island.controlHeight * 0.9) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.outlineVariant
                    }

                    Rectangle {
                        id: stripArt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 6
                        width: 48; height: 48
                        radius: 8
                        color: Theme.surfaceHigh
                        clip: true

                        Image {
                            id: stripImg
                            anchors.fill: parent
                            source: Player.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !stripImg.visible
                            text: "\u266a"
                            color: Theme.outline
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        anchors.left: stripArt.right
                        anchors.leftMargin: 12
                        anchors.right: stripControls.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: stripArt.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: Player.title
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: Player.artist
                            color: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    Row {
                        id: stripControls
                        anchors.right: parent.right
                        anchors.verticalCenter: stripArt.verticalCenter
                        spacing: 18

                        Repeater {
                            model: [
                                { g: "\u23ee", act: "prev" },
                                { g: "",        act: "toggle" },
                                { g: "\u23ed", act: "next" }
                            ]

                            Text {
                                required property var modelData
                                text: modelData.act === "toggle"
                                    ? (Player.playing ? "\u23f8" : "\u25b6")
                                    : modelData.g
                                color: modelData.act === "toggle" ? Theme.primary : Theme.textDim
                                font.pixelSize: 17

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.act === "prev") Player.prev();
                                        else if (modelData.act === "next") Player.next();
                                        else Player.toggle();
                                    }
                                }
                            }
                        }
                    }
                }

                // Hover is reported by a handler, not a MouseArea.
                // A MouseArea that gets disabled reports containsMouse
                // false, which dropped `revealed`, which collapsed the
                // pill, which re-enabled the MouseArea — the loop that
                // made clicking flicker.
                HoverHandler {
                    id: pillHover

                    onHoveredChanged: {
                        win.touch(hovered);
                        if (hovered) collapseTimer.stop();
                        else if (win.expanded && Config.island.collapseDelay > 0)
                            collapseTimer.restart();
                    }
                }
            }


        }

        // Opens the settings app on a given page. Going through the
        // shell's own IPC keeps Island from needing to know anything
        // about Settings beyond the target name.
        QtObject {
            id: settingsIpc
            function open(page) {
                openProc.command = ["qs", "-c", "island", "ipc", "call",
                                    "settings", "page", page];
                openProc.running = true;
            }
        }

        Process { id: openProc; running: false }

        // ── Clock ────────────────────────────────────────────

        SystemClock {
            id: clockSource
            precision: SystemClock.Seconds
        }

        QtObject {
            id: clock
            readonly property string time:     Qt.formatDateTime(clockSource.date, "hh:mm")
            readonly property string date:     Qt.formatDateTime(clockSource.date, "ddd dd MMM")
            readonly property string timeLong: Qt.formatDateTime(clockSource.date, "hh:mm:ss")
            readonly property string dateLong: Qt.formatDateTime(clockSource.date, "dddd, dd MMMM yyyy")
        }

        // ── IPC ──────────────────────────────────────────────

        IpcHandler {
            target: "island"

            function toggle(): void { win.expanded = !win.expanded }
            function expand(): void { win.expanded = true }
            function collapse(): void { win.expanded = false }

            function setVisibility(mode: string): void { Config.island.visibility = mode }
            function search(): void { win.openSearch() }
            function attention(on: bool): void { win.demandsAttention = on }
            function state(): string { return island.mode }

            // Everything the visibility decision depends on, in one
            // line. Guessing at which term is wrong costs more than
            // printing them.
            function why(): string {
                const r = win.islandRect;
                return "mode=" + island.mode
                    + " visibility=" + win.visibilityMode
                    + " revealed=" + win.revealed
                    + " occluded=" + win.occluded
                    + " overlapped=" + win.overlapped
                    + " fullscreen=" + Wm.fullscreen
                    + " empty=" + Wm.empty
                    + " windows=" + Wm.windows.length
                    + " latch=" + win.hoverLatch
                    + " islandRect=" + Math.round(r.x) + "," + Math.round(r.y)
                    + " " + Math.round(r.width) + "x" + Math.round(r.height)
                    + " screen=" + win.screen.width + "x" + win.screen.height;
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
                if (win.centreOpen) win.closeCentre();
                else win.openCentre();
            }
            function show(): void { win.openCentre() }
            function hide(): void { win.closeCentre() }
        }

        IpcHandler {
            target: "picker"

            function toggle(kind: string): void {
                const k = kind === "" ? "wallpaper" : kind;
                if (win.picker === k) win.closePicker();
                else win.openPicker(k);
            }
            function wallpapers(): void { win.openPicker("wallpaper") }
            function palettes(): void { win.openPicker("theme") }
            function icons(): void { win.openPicker("icon") }
            function hide(): void { win.closePicker() }
        }

        IpcHandler {
            target: "control"

            function toggle(): void {
                if (win.expanded) win.closeControl();
                else win.openControl();
            }
            function show(): void { win.openControl() }
            function hide(): void { win.closeControl() }
        }

        IpcHandler {
            target: "session"

            function toggle(): void {
                if (win.sessionOpen) win.closeSession();
                else win.openSession();
            }
            function show(): void { win.openSession() }
            function hide(): void { win.closeSession() }
            function run(action: string): void { Session.run(action) }
        }

        // SUPER+R and ALT+Space are bound to launcher toggle.
        IpcHandler {
            target: "launcher"

            function toggle(): void {
                if (win.searching) win.closeSearch();
                else win.openSearch();
            }
            function show(): void { win.openSearch() }
            function hide(): void { win.closeSearch() }
        }
    }
}
