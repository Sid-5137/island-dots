import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Notification history, with per-item dismiss and clear all.
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

    // The popup's number, for the same reason — see NotifyMode. The
    // centre is the taller of the two and so has the rounder corner,
    // which makes it the one where a constant inset shows first.
    readonly property int inset:
        Math.max(Theme.padCard, Math.round(Config.island.radius * 1.15))

    readonly property bool shown: island.isCentre

    // ── What the panel has to be ─────────────────────────────
    //
    // Island.qml sizes the centre from this rather than from a stored
    // height, the way the control centre was changed to when its own
    // controlHeight turned out to be a number that could only ever
    // disagree with what was in the panel.
    //
    // It was disagreeing here too, and worse, because a notification
    // list is empty most of the time. At rest the centre was 480 by
    // 440 with a title, a rule, and one line of dim text adrift in
    // four hundred pixels of nothing — which is a dialog box, not one
    // of the shell's cards, and no amount of corner work was going to
    // rescue it. One notification got the same 440. So did four, which
    // is the only count the number was ever right for.
    //
    // The three metrics below are the layout's, declared here so the
    // arithmetic and the anchors cannot drift apart: change the header
    // and the panel that holds it changes with it.
    readonly property int headerHeight: 30
    readonly property int headerGap: 8
    readonly property int rowGap: 6

    // Room for "Nothing to catch up on" and the air it needs. Empty is
    // a state worth showing properly rather than a state to be sized
    // out of existence — a centre that collapsed to its header would
    // read as broken rather than as quiet.
    readonly property int emptyHeight: 80

    readonly property int contentHeight: {
        const n = Notifications.count;
        const body = n === 0
            ? emptyHeight
            : n * Config.island.centreRowHeight + (n - 1) * rowGap;
        // centreHeight is the ceiling, not the height: past it the
        // list scrolls, which is what a list is for.
        return Math.min(Config.island.centreHeight,
                        inset * 2 + headerHeight + headerGap + body);
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Item {
        id: centreHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

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

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.count > 0
            implicitHeight: 24
            text: "Clear"
            onClicked: Notifications.clear()
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
            + (root.emptyHeight - implicitHeight) / 2
        visible: Notifications.count === 0
        text: "Nothing to catch up on"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    ListView {
        id: centreList
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: root.rowGap
        model: ScriptModel {
            // Notifications are plain objects rebuilt on every change,
            // so identity comparison would see them all as new. The id
            // is what actually distinguishes them.
            objectProp: "id"
            values: Notifications.history
        }
        delegate: Rectangle {
            required property var modelData

            width: centreList.width
            height: Config.island.centreRowHeight
            // Concentric with the panel — see Theme.inner. These rows
            // run the full inner width and the list reaches the
            // bottom, so the first and last of them sit in the panel's
            // corners; a 440px panel is round to 40 and an inset of 16
            // leaves 24. radiusLarge said 17, and seven pixels of
            // disagreement read as two panels rather than one.
            radius: Theme.inner(root.pill.radius, root.inset)
            color: rowHover.containsMouse
                ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            // Critical keeps a mark in history, not
            // just in the popup that already went by.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Theme.padRow
                width: 3
                radius: width / 2
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
                // The popup's tile, same ratio — see NotifyMode.
                radius: width * 0.225
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
                    text: Icons.bell
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
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
                    font.weight: Font.DemiBold
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
                    font.weight: Font.DemiBold
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
                font.weight: Config.island.fontWeight

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
