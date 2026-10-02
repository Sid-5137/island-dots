import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Transient notification popup. Takes the island over for a few
// seconds, then hands it back.
//
// The face is NoticeFace, shared with the history rows. What is here is
// the frame round it: one inset on all four sides, and whatever the
// sender offers — actions, a reply — stacked underneath at that same
// inset, across the full width. Island.qml sizes the popup from
// contentHeight, so it is exactly as tall as what it holds rather than
// a fixed box with the content floating in it.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent
    anchors.margins: inset

    // How far in the popup holds its contents. Tied to the radius
    // rather than flat, so the inset opens up with the corner it has
    // to clear — otherwise the icon and the reply field end up inside
    // the arc at any radius but the one this was measured at.
    readonly property int inset:
        Math.max(Theme.padCard, Math.round(Config.island.radius * 1.15))

    readonly property int gap: 12
    readonly property int actionHeight: 28
    readonly property int replyHeight: 32

    readonly property var n: win.notice
    readonly property bool hasActions: !!n && n.actions.length > 0
    readonly property bool hasReply: !!n && n.hasReply === true

    // Off the notice rather than the mode, so the shape already knows
    // its height on the frame the popup starts to open.
    readonly property int contentHeight: inset * 2 + face.implicitHeight
        + (hasActions ? gap + actionHeight : 0)
        + (hasReply ? gap + replyHeight : 0)

    readonly property bool shown: island.isNotify

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // Clicking the popup runs the sender's default action — the one the
    // spec reserves for a click on the notification itself — and
    // dismisses it; a right click only dismisses. Never the first
    // button: that is a choice, and a stray click should not make it.
    // Declared first, so the buttons and the reply field above it take
    // their own clicks.
    MouseArea {
        anchors.fill: parent
        anchors.margins: -root.inset
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.n && root.n.hasDefault
            ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) Notifications.activate(root.n);
            win.dismissNotice();
        }
    }

    NoticeFace {
        id: face
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        entry: root.n
        iconSize: 40
        bodyLines: 3
    }

    // Equal widths across the whole inner width, so the row is as wide
    // as the face above it and ends where it ends. The first action is
    // the one the sender means, so it is the filled one.
    Row {
        id: actions
        anchors.top: face.bottom
        anchors.topMargin: root.gap
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        visible: root.hasActions

        Repeater {
            id: actionRepeater
            model: root.n ? root.n.actions : []

            Button {
                required property var modelData
                required property int index

                width: (actions.width - actions.spacing
                        * (actionRepeater.count - 1)) / actionRepeater.count
                implicitHeight: root.actionHeight
                padding: Theme.padRow
                text: modelData
                kind: index === 0 ? "primary" : "plain"

                onClicked: {
                    Notifications.invoke(root.n, index);
                    win.dismissNotice();
                }
            }
        }
    }

    // Inline reply, for clients that advertise one. The field takes
    // the keyboard while it's up, which is why the popup's dismiss
    // timer is held off in Island.qml for as long as it has focus —
    // a reply box that vanishes mid-sentence is worse than no reply
    // box at all.
    Rectangle {
        id: replyBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.replyHeight
        // In the corner: it spans the full inner width along the
        // bottom, so its two bottom corners sit directly inside the
        // panel's. See Theme.inner.
        radius: Theme.inner(root.pill.radius, root.inset)
        visible: root.canReply

        color: replyField.activeFocus
            ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: replyField.activeFocus
            ? Theme.primary : Qt.rgba(1, 1, 1, 0.09)

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

        TextInput {
            id: replyField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: sendBtn.width + 20
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            clip: true

            Keys.onEscapePressed: win.dismissNotice()
            onAccepted: root.send()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: replyField.text === ""
                text: root.n ? (root.n.replyHint || "Reply") : "Reply"
                color: Theme.outline
                font: replyField.font
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: sendBtn
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Send"
            color: replyField.text === ""
                ? Theme.outline
                : (sendHover.containsMouse ? Theme.primary : Theme.text)
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            MouseArea {
                id: sendHover
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.send()
            }
        }

        // Focus the field as soon as the popup carrying it appears,
        // so a reply is one keystroke away rather than a click first.
        Connections {
            target: root
            function onCanReplyChanged() {
                if (root.canReply) {
                    replyField.text = "";
                    replyField.forceActiveFocus();
                }
            }
        }
    }

    readonly property bool canReply: hasReply && island.isNotify

    // Island.qml holds the dismiss timer while this is true.
    Binding {
        target: win
        property: "replyFocused"
        value: root.canReply && replyField.activeFocus
        restoreMode: Binding.RestoreBindingOrValue
    }

    function send() {
        if (replyField.text.trim() === "") return;
        Notifications.reply(root.n, replyField.text);
        replyField.text = "";
        win.dismissNotice();
    }
}
