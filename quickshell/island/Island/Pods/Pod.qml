import QtQuick

import "root:/Services"
import "root:/Widgets"

// A satellite beside the island.
//
// The collapsed pill used to carry everything at once: the clock, a
// row of workspace dashes, a playing indicator, the tray — and a
// scroll gesture to cycle between three "faces" because it could not
// hold them all. Scrolling to find out what is running is not a
// glance, and the things worth a glance were exactly the ones the
// gesture kept hidden.
//
// So they moved out. A pod is a small capsule that flanks the pill. It
// does not push the pill aside and it never moves the island's centre,
// because a dynamic island that drifts left when a tray icon appears
// is not an island. It has two sizes — rest and open — and it
// collapses into the pill's edge when it has nothing to say at all.
//
// Between those two sizes only the pod animates. Its content holds
// still in two layers that cross-fade, which is exactly how the modes
// behave inside the pill: one shape morphing, contents swapping.
//
// Content is declared as ordinary children. The pod's own input areas
// are ordered by z rather than by declaration, so a pod can be
// subclassed without having to be threaded through an alias.

Rectangle {
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
    // every Behavior on it reads the answer. A peek is the one moment
    // a pod is allowed to be springy — nothing in it is being read at
    // that instant, and a shape that pops is the entire point of it.
    // Opening under the cursor is not: a capsule that overshoots
    // while you are reaching for a tray icon moves the icon.
    readonly property int morphTime:
        !shown ? Motion.collapse
               : (peeking ? Motion.peek
                          : (open ? Motion.hover : Motion.collapse))

    readonly property var morphCurve:
        !shown ? Motion.settle
               : (peeking ? Motion.pop
                          : (open ? Motion.arrive : Motion.settle))

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

    // Negative on the way out, so the pod slides under the pill's edge
    // as it goes rather than blinking off beside it.
    anchors.rightMargin: shown ? Config.island.podGap : -8
    anchors.leftMargin: shown ? Config.island.podGap : -8

    width: shown ? Math.max(20, open ? openWidth : restWidth) : 0

    // Matches the pill rather than being a fixed height of its own:
    // hovering either one lifts all three shapes together.
    height: island.mode === "compact"
        ? Config.island.compactHeight : Config.island.idleHeight

    opacity: shown ? 1 : 0
    scale: shown ? 1 : Motion.absentScale
    // Toward the pill, so a leaving pod collapses into the island
    // instead of shrinking into its own middle.
    transformOrigin: side === "left" ? Item.Right : Item.Left
    visible: opacity > 0.01

    // The same curve the pill uses, so the three shapes move as one
    // object. Collapsing to nothing is the reason departures are
    // critically damped and not merely gentler: an overshoot at zero
    // is a negative width, and a negative width anchored to the
    // pill's edge draws over the pill.
    Behavior on width { Morph { shape: root } }
    Behavior on height { Morph { shape: root } }
    Behavior on anchors.rightMargin { Morph { shape: root } }
    Behavior on anchors.leftMargin { Morph { shape: root } }
    Behavior on scale { Morph { shape: root } }

    Behavior on opacity {
        ContentFade { revealing: root.shown }
    }

    // ── Surface ──────────────────────────────────────────────
    //
    // The pill's, exactly: same tint, same radius, same border. A pod
    // is the island in a smaller shape, not a different widget.

    // The pill's, exactly — the same function against its own height,
    // so a pod at 34px and a pill at 34px are the same shape.
    radius: Theme.corner(height)
    clip: true

    color: {
        const c = Qt.color(island.mode === "idle" || island.mode === "hidden"
            ? Theme.surfaceLowest : Theme.surfaceContainer);
        return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
    }

    border.width: 1
    border.color: Theme.outlineVariant

    // The pill's second line too — a pod is the island in a smaller
    // shape, and half an edge is a shape it would not share.
    Bezel { z: 49; outer: root.radius }

    // Pinning is a state, so it says so rather than leaving you to
    // wonder why the pod stopped closing. Above the content and below
    // the hover area, and inert either way.
    Rectangle {
        z: 50
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.primary
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
