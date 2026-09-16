import QtQuick

import "root:/Services"

// Volume and brightness, as a bar you can hit.
//
// The old sliders were an 8px rail with a knob that appeared on
// hover — a shape borrowed from a settings dialog, where the pointer
// is already still and the value is being set precisely. A control
// centre is the opposite: it is open for two seconds and the gesture
// is a swipe at roughly the right place. So the track is the whole
// control, the fill is the value, and there is no knob to find. The
// glyph rides inside the fill, which means the thing you are most
// likely to aim at — mute — is wherever the level already is.
//
// The card changes shape rather than scaling. Wide, it has room for
// a name; squeezed, the name goes and the bar stays, because a bar
// with no label still reads as a level while a label with no bar does
// not. Taller than it is wide, it stands up and fills from the
// bottom, which is the one orientation where "more" is unambiguous
// without any label at all.

Item {
    id: root

    property string label: ""
    property string glyph: ""
    property int value: 0

    // Drawn at half strength, for a level that is muted or a display
    // that has no backlight to speak of.
    property bool dimmed: false

    // Whether there is a sub-page behind the chevron. A chevron that
    // opens nothing is worse than no chevron: it is a promise the
    // panel does not keep, and you only find that out by clicking it.
    property bool hasPage: true

    // See ConnRow: the words are optional, per control. With them off
    // the bar takes the whole card, which is the one place this is an
    // improvement rather than a preference — a full-height bar is a
    // bigger target than a labelled one.
    property bool showText: true

    readonly property bool vertical: height > width
    readonly property bool showLabel:
        showText && !vertical && height >= 40 && width >= 130

    signal moved(int value)
    signal toggled()
    signal opened()

    Surface {
        anchors.fill: parent
        hovered: drag.containsMouse
    }

    Text {
        id: name
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 7
        visible: root.showLabel
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        font.letterSpacing: 0.4
        renderType: Text.NativeRendering
    }

    Text {
        id: chevron
        anchors.right: parent.right
        // Beside the bar rather than over it when there is no label
        // line for it to sit on.
        anchors.rightMargin: root.showLabel ? 10 : 11
        anchors.verticalCenter: root.showLabel ? name.verticalCenter
                                               : parent.verticalCenter
        visible: root.showText && root.hasPage && !root.vertical
                 && root.width >= 130
        text: "›"
        color: more.containsMouse ? Theme.text : Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: 15

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        MouseArea {
            id: more
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }

    // The track. Everything below measures against this rather than
    // against the card, so the same drag arithmetic works in both
    // orientations.
    Item {
        id: track

        // Laid out by hand rather than by anchors. Three shapes need
        // three different pairs of edges pinned, and switching an
        // anchor to `undefined` per shape is how you end up anchoring
        // to both the bottom and the centre at once — which Qt
        // resolves by ignoring one of them, silently, in whichever
        // order the bindings happened to evaluate.
        readonly property int pad: 8

        readonly property int bar:
            Math.min(26, root.height - 14)

        x: root.showLabel ? 10 : pad
        // The chevron sits inside the card when there is no label
        // line, so the bar stops short of it rather than running
        // underneath. A way into the Sound page that disappears
        // because you turned the words off is a setting with a side
        // effect nobody asked for.
        width: root.width - x * 2
             - (chevron.visible && !root.showLabel ? 20 : 0)

        y: root.vertical ? pad
            : (root.showLabel ? name.y + name.height + 4
                              : Math.round((root.height - bar) / 2))
        height: root.vertical ? root.height - pad * 2
            : (root.showLabel ? root.height - y - 9 : bar)

        readonly property real ratio: Math.max(0, Math.min(1, root.value / 100))

        // The groove and the fill are siblings, not parent and
        // child. The obvious arrangement — fill inside a clipped
        // groove — renders nothing at all once the fill is wide
        // enough, silently: at three cells the bar is there, at six
        // the same rectangle reports the right geometry, the right
        // opacity and visible true, and draws no pixels. Both are
        // capsules with radius height/2, so there was never anything
        // for the clip to do.
        Rectangle {
            id: groove
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: fill

            // A capsule, so at low values it keeps enough width to
            // stay a rounded shape rather than collapsing into a
            // sliver the glyph then hangs out of.
            readonly property real span: root.vertical
                ? track.height : track.width
            readonly property real least: root.vertical
                ? track.width : Math.min(track.height, track.width)

            width: root.vertical
                ? track.width
                : Math.max(least, span * track.ratio)
            height: root.vertical
                ? Math.max(least, span * track.ratio)
                : track.height

            y: root.vertical ? track.height - height : 0

            radius: groove.radius
            color: Theme.primary
            opacity: root.dimmed ? 0.45 : 1

            // The level itself is not animated: it follows a drag,
            // and a spring between the pointer and the fill reads as
            // lag. Only the state does.
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        // Inside the fill, at the end you fill from. It is drawn over
        // both, so it needs a colour that works on either — hence the
        // swap once the fill has reached it.
        Text {
            id: icon

            x: root.vertical
                ? Math.round((track.width - width) / 2)
                : 7
            y: root.vertical
                ? track.height - height - 7
                : Math.round((track.height - height) / 2)

            text: root.glyph
            color: covered ? Theme.textOnPrimary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(15, Math.round(
                (root.vertical ? track.width : track.height) * 0.62))

            readonly property bool covered: root.vertical
                ? fill.height > height + 12
                : fill.width > width + 12

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function apply(x, y) {
                const r = root.vertical
                    ? 1 - Math.max(0, Math.min(1, y / track.height))
                    : Math.max(0, Math.min(1, x / track.width));
                root.moved(Math.round(r * 100));
            }

            // Ordered so the glyph's own area wins: it is declared
            // inside the groove above this, and a press that starts on
            // it is a mute rather than a jump to 4%.
            onPressed: function(m) { apply(m.x, m.y) }
            onPositionChanged: function(m) { if (pressed) apply(m.x, m.y) }
            onWheel: function(w) {
                const step = w.angleDelta.y > 0 ? 5 : -5;
                root.moved(Math.max(0, Math.min(100, root.value + step)));
            }
        }
    }
}
