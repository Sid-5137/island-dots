import QtQuick
import "root:/Services"

// A labelled row with a slider and a live value readout.
// Emits `moved` continuously while dragging.

Item {
    id: root

    property string label: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property int decimals: 0

    signal moved(real value)

    // Set to "section.key" and a revert control appears whenever the
    // value differs from the shipped default.
    property string configKey: ""

    implicitWidth: parent ? parent.width : 400

    // Grows for the description rather than assuming one line. The
    // description used to be declared and then never drawn at all, so
    // every explanation written for a slider — here and on every page
    // — was invisible.
    implicitHeight: 40 + (descText.visible ? descText.implicitHeight + 4 : 0)
                       + track.height + 10

    readonly property real ratio: to > from ? (value - from) / (to - from) : 0

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.right: revert.left
        anchors.rightMargin: 10
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    Text {
        id: descText
        anchors.left: parent.left
        anchors.top: labelText.bottom
        anchors.topMargin: 2
        // Clear of the readout, which sits on the first line only.
        anchors.right: parent.right
        text: root.description
        visible: root.description !== ""
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        renderType: Text.NativeRendering
    }

    ResetDot {
        id: revert
        anchors.right: valueText.left
        anchors.rightMargin: 6
        anchors.verticalCenter: labelText.verticalCenter
        configKey: root.configKey
        current: root.value
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: labelText.verticalCenter
        text: root.value.toFixed(root.decimals) + root.suffix
        color: Theme.primary
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        renderType: Text.NativeRendering
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surfaceHigh

            Rectangle {
                width: parent.width * root.ratio
                height: parent.height
                radius: 2
                color: Theme.primary
            }
        }

        Rectangle {
            id: handle
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width,
                                    root.ratio * track.width - width / 2))
            color: Theme.primary
            border.width: 2
            border.color: Theme.surfaceLowest
            scale: drag.pressed ? 1.25 : 1.0

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                const r = Math.max(0, Math.min(1, mx / track.width));
                let v = root.from + r * (root.to - root.from);
                if (root.stepSize > 0)
                    v = Math.round(v / root.stepSize) * root.stepSize;
                root.moved(v);
            }

            onPressed: function(m) { apply(m.x) }
            onPositionChanged: function(m) { if (pressed) apply(m.x) }

            // Ctrl, because a settings page is a scrolling page first
            // and a row of sliders second.
            //
            // The wheel used to adjust the value whenever the pointer
            // happened to be over a track, which on a page that is
            // mostly tracks means scrolling past one changes it. You
            // do not find out until later, and by then you do not know
            // which one moved or what it was. Every toolkit that has
            // had this argument — GTK, Cocoa — resolves it the same
            // way: the wheel belongs to whatever is scrolling.
            //
            // Not accepting the event is what hands it back up to the
            // Flickable. Click-drag is still coarse on a long track,
            // so the precise stepping stays, one modifier away.
            onWheel: function(w) {
                if (!(w.modifiers & Qt.ControlModifier)) {
                    w.accepted = false;
                    return;
                }

                const dir = w.angleDelta.y > 0 ? 1 : -1;
                const step = root.stepSize > 0 ? root.stepSize : 1;
                root.moved(Math.max(root.from,
                                    Math.min(root.to, root.value + dir * step)));
            }
        }
    }
}
