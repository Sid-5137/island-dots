import QtQuick

import "root:/Services"
import "root:/Widgets"

// A satellite beside the island: a small capsule flanking the pill.
//
// It never moves the island's centre — a dynamic island that drifts
// left when a tray icon appears is not an island. Two sizes, rest and
// open, collapsing into the pill's edge when it has nothing to say.
//
// Only the pod animates between them; its content holds still in two
// cross-fading layers, as the modes do inside the pill.
//
// Content is declared as ordinary children, and input areas are
// ordered by z rather than declaration so a pod can be subclassed.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var pill     // the shape it hangs off

    // Which edge of the pill it attaches to.
    property string side: "left"   // "left" | "right"

    // False when there is nothing to show at all — no workspaces, an
    // empty tray. An empty capsule sitting there is clutter of exactly
    // the kind the pods exist to remove, so it collapses instead.
    property bool present: true

    // Measured from the two content layers by whoever declares the
    // pod. Both are plain implicitWidths of layouts that do not
    // animate, so the pod's own morph has nothing to chase.
    property real restWidth: 32
    property real openWidth: 120

    // Click the pod's own background and it stays open. Hovering is a
    // look; this is for when you want it to hold still.
    property bool pinned: false

    // Raised for a moment by whatever the pod watches.
    property bool peeking: false

    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool open: present && (hovered || pinned || peeking)

    // Pods belong to the collapsed island. Every other mode is a panel
    // that owns the whole shape, and satellites orbiting a search
    // field are debris. "hidden" is docked too: the island slides up
    // off the screen as one object and the pods ride with it rather
    // than fading out first and leaving it to go alone.
    readonly property bool docked:
        island.mode === "idle" || island.mode === "compact"
        || island.mode === "hidden"

    readonly property bool shown: docked && present

    // ── How the shape moves ──────────────────────────────────
    //
    // Same contract as the island: the pod says where it is going and
    // every spring on it reads the answer. A peek is the one moment
    // a pod is allowed to be springy — nothing in it is being read at
    // that instant, and a shape that pops is the entire point of it.
    // Opening under the cursor is not: a capsule that overshoots
    // while you are reaching for a tray icon moves the icon.
    readonly property int springResponse:
        !shown ? Motion.collapseResponse
               : (peeking ? Motion.popResponse
                          : (open ? Motion.hoverResponse
                                  : Motion.collapseResponse))

    readonly property real springBounce:
        !shown ? Motion.departBounce
               : (peeking ? Motion.popBounce
                          : (open ? Motion.arriveBounce
                                  : Motion.departBounce))

    function peek() {
        if (!Config.island.podPeek || !present) return;
        peeking = true;
        peekTimer.restart();
    }

    Timer {
        id: peekTimer
        interval: Config.island.podPeekDuration
        onTriggered: root.peeking = false
    }

    // A pod that empties, or one the island has taken the screen back
    // from, must not stay held open at nothing.
    onPresentChanged: if (!present) { peeking = false; pinned = false }
    onDockedChanged: if (!docked) { peeking = false; pinned = false }

    // ── Geometry ─────────────────────────────────────────────
    //
    // Anchored to the pill's edge, so the pod follows it and the pill
    // never has to know the pod exists. Only one of the two anchors is
    // ever set; the unused margin is harmless.

    anchors.top: pill.top
    anchors.right: side === "left" ? pill.left : undefined
    anchors.left: side === "right" ? pill.right : undefined

    anchors.rightMargin: tuck.value
    anchors.leftMargin: tuck.value

    // Negative on the way out, so the pod slides under the pill's
    // edge as it goes rather than blinking off beside it. One spring
    // for both: only one of the two anchors is ever set.
    Spring {
        id: tuck
        shape: root
        target: root.shown ? Config.island.podGap : -8
    }

    width: podWidth.value
    height: podHeight.value

    opacity: shown ? 1 : 0
    scale: podScale.value
    // Toward the pill, so a leaving pod collapses into the island
    // instead of shrinking into its own middle.
    transformOrigin: side === "left" ? Item.Right : Item.Left
    visible: opacity > 0.01

    // The same spring the pill is on, so the three shapes move as one
    // object. Collapsing to nothing is why departures keep so little
    // bounce, and why each of these has a floor: an overshoot at zero
    // is a negative width, and a negative width anchored to the
    // pill's edge draws over the pill.

    // Never narrower than it is tall. One workspace dot or one tray
    // icon measures about twenty-five pixels against a height of
    // thirty-four, and the corner is clamped to half the shorter side
    // — so the pod would end up a lozenge standing on end beside a
    // pill lying down, which is the one shape the island does not
    // own. At the floor it is square, the corner has the full half to
    // spend, and a pod with a single thing in it comes out round.
    //
    // Measured against the height's target rather than its current
    // value: a width that chased the height's spring would arrive
    // behind it, and the two are one shape.
    Spring {
        id: podWidth
        shape: root
        minimum: 0
        target: root.shown
            ? Math.max(podHeight.target,
                       root.open ? root.openWidth : root.restWidth)
            : 0
    }

    // Matches the pill rather than being a fixed height of its own:
    // hovering either one lifts all three shapes together.
    Spring {
        id: podHeight
        shape: root
        minimum: 0
        target: root.island.mode === "compact"
            ? Config.island.compactHeight : Config.island.idleHeight
    }

    // How far it leans out of the way while it is absent.
    Spring {
        id: podScale
        shape: root
        minimum: 0
        target: root.shown ? 1 : Motion.absentScale
    }

    Behavior on opacity {
        ContentFade { revealing: root.shown }
    }

    // ── Surface ──────────────────────────────────────────────
    //
    // The pill's, exactly: same tint, same radius, same border. A pod
    // is the island in a smaller shape, not a different widget.

    // The pill's, exactly — the same function against its own height,
    // so a pod at 34px and a pill at 34px are the same shape, and now
    // the same curve as well.
    readonly property real radius: Theme.corner(height)
    clip: true

    // The pill's, exactly — and a pod only exists while the island is
    // docked, so that is one colour rather than a choice. Hovering
    // lifts all three shapes and recolours none of them.
    readonly property color fill: {
        const c = Qt.color(Theme.surfaceLowest);
        return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
    }

    // Declared first so it sits under everything, which is what the
    // Rectangle's own background used to do. See Widgets/Squircle.qml
    // for why a pod cannot simply be a Rectangle any more.
    Squircle {
        smoothing: Config.appearance.cornerSmoothing
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        borderWidth: 1
        borderColor: Theme.outlineVariant
    }

    // The pill's second line too — a pod is the island in a smaller
    // shape, and half an edge is a shape it would not share.
    Bezel { z: 49; outer: root.radius }

    // Pinning is a state, so it says so rather than leaving you to
    // wonder why the pod stopped closing. Above the content and below
    // the hover area, and inert either way.
    Squircle {
        z: 50
        anchors.fill: parent
        radius: parent.radius
        smoothing: Config.appearance.cornerSmoothing
        color: "transparent"
        borderWidth: 1
        borderColor: Theme.primary
        opacity: root.pinned ? 0.55 : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
    }

    // ── Input ────────────────────────────────────────────────
    //
    // Beneath the content, so whatever the pod holds gets its own
    // clicks and this only catches presses on the empty capsule around
    // them.
    MouseArea {
        z: -1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pinned = !root.pinned
    }

    // A MouseArea rather than a HoverHandler, and above everything —
    // the same reason Island.qml gives for the pill. A child MouseArea
    // with hoverEnabled consumes hover, so a handler underneath one
    // stops reporting the moment the cursor reaches a tray icon, and
    // the pod would close while you were pointing at it.
    //
    // NoButton means it sees hover but never takes a click.
    MouseArea {
        id: hoverArea
        z: 100
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        // Keeps smart hiding from pulling the island out from under a
        // pod you are reading.
        onContainsMouseChanged: win.touch(containsMouse)
    }
}
