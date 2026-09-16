import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Transient notification popup. Takes the island over for a few
// seconds, then hands it back.
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

    // How far in the popup holds its contents.
    //
    // This was a flat 16, which is correct for exactly one setting of
    // the radius slider: the one it was measured against. A popup is
    // 104px tall, so its corner is a little over the slider's value,
    // and at 14 the two happen to agree. Push the slider up and the
    // corner grows past the margin — the icon tile's top-left and the
    // reply field's bottom corners end up sitting inside the arc, each
    // squarely in the part of the panel that is busy curving away from
    // them. Nothing overlaps, so nothing looks broken; it just looks
    // like the contents were laid out for a squarer popup and the
    // corners were rounded afterwards.
    //
    // Tied to the slider instead, so the inset opens up with the
    // corner it has to clear. The multiplier is what keeps today's
    // default landing on today's 16.
    readonly property int inset:
        Math.max(Theme.padCard, Math.round(Config.island.radius * 1.15))

    readonly property bool shown: island.isNotify

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    readonly property var n: win.notice

    Rectangle {
        id: noticeIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 46
        // Not a token, and not concentric with anything: this tile is
        // vertically centred, so it never comes near a corner of the
        // popup and has no corner to be concentric with. Its roundness
        // is a fact about what it is — it stands in for an app icon,
        // and an app icon is round to about two-ninths of its side on
        // every platform that draws one. radiusLarge made it 17 of 46,
        // better than a third, which is the blobby over-rounded tile
        // that makes the whole popup read as squircle-first.
        radius: width * 0.225
        color: root.n && root.n.critical
            ? Theme.error : Theme.surfaceHigh
        clip: true

        Image {
            id: noticeImg
            anchors.fill: parent
            anchors.margins: root.n && root.n.image ? 0 : 11
            source: {
                if (!root.n) return "";
                if (root.n.image) return root.n.image;
                if (root.n.appIcon)
                    return Quickshell.iconPath(root.n.appIcon, true);
                return "";
            }
            fillMode: root.n && root.n.image
                ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !noticeImg.visible
            text: Icons.bell
            color: root.n && root.n.critical
                ? Theme.textOnError : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Config.island.fontWeight
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
            text: root.n ? root.n.summary : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: root.n ? root.n.body : ""
            visible: text !== ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
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
            text: root.n ? root.n.appName : ""
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
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
        height: 30
        // This one *is* in the corner — it spans the full inner width
        // along the bottom, so its two bottom corners sit directly
        // inside the panel's. See Theme.inner: inset from a corner of
        // 22 by 16 leaves 6, and radiusNormal's 14 on a 30px-tall box
        // was very nearly a capsule tucked into a gentle corner.
        radius: Theme.inner(root.pill.radius, root.inset)
        visible: root.canReply

        color: replyField.activeFocus
            ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: replyField.activeFocus
            ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

        TextInput {
            id: replyField
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: sendBtn.width + 16
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font.family: Theme.fontFamily
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
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: "Send"
            color: replyField.text === ""
                ? Theme.outline
                : (sendHover.containsMouse ? Theme.primary : Theme.text)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
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

    readonly property bool canReply:
        !!n && n.hasReply === true && island.isNotify

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

    // Click runs the first action if there is one, and
    // dismisses either way — a notification you've
    // acted on shouldn't linger.
    Row {
        id: actions
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.canReply ? replyBox.height + 6 : 0
        spacing: 6
        visible: root.n && root.n.actions.length > 0

        // The first action is the one the sender means, so it is
        // filled rather than merely filling on hover. Which action a
        // popup is for is worth knowing before you have moved the
        // pointer onto one of them.
        Repeater {
            model: root.n ? root.n.actions : []

            Button {
                required property var modelData
                required property int index

                implicitHeight: 26
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

    // Clicking the body dismisses. Actions have their own buttons, so
    // the whole popup being one big button would make a stray click
    // run whatever the sender put first.
    MouseArea {
        anchors.fill: parent
        // Declared last, so this sits above everything. Keep it clear
        // of the controls underneath or it swallows their clicks.
        anchors.bottomMargin: (root.canReply ? replyBox.height + 6 : 0)
                            + (actions.visible ? 32 : 0)
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.dismissNotice()
    }
}
