import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"
import "root:/Widgets/Control"

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

    // Island.qml sizes the centre from contentHeight rather than from
    // a stored height, which could only ever disagree with what is in
    // the panel — a notification list is empty most of the time.
    readonly property int headerHeight: 28
    readonly property int headerGap: 10
    readonly property int rowGap: 8

    // Room for the empty state and the air it needs. Empty is a state
    // worth showing properly rather than a state to be sized out of
    // existence — a centre that collapsed to its header would read as
    // broken rather than as quiet.
    readonly property int emptyHeight: 96

    // Exact, not estimated: every row is built (history is capped at
    // sixty), so the column's height is a measurement of what is there.
    readonly property int contentHeight: {
        const body = Notifications.count === 0
            ? emptyHeight : rows.implicitHeight;
        // centreHeight is the ceiling, not the height: past it the
        // list scrolls, which is what a list is for.
        return Math.min(Config.island.centreHeight,
                        inset * 2 + headerHeight + headerGap + body);
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // The control centre's own notifications card labels itself the
    // same way, so the two read as one thing at two sizes.
    Item {
        id: centreHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        // In line with the icons on the cards below, as the button
        // opposite is in line with their right edge.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padCard
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                id: headerTitle
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
                font.letterSpacing: 0.4
                renderType: Text.NativeRendering
            }

            Text {
                anchors.baseline: headerTitle.baseline
                visible: Notifications.count > 0
                text: Notifications.count
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.count > 0
            implicitHeight: 24
            padding: Theme.padRow
            text: "Clear all"
            onClicked: Notifications.clear()
        }
    }

    // Empty: the bell and a line, centred in the room left for them.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
            + (root.emptyHeight - implicitHeight) / 2
        visible: Notifications.count === 0
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.bell
            color: Theme.outline
            font.family: Theme.fontIcons
            font.pixelSize: 22
            renderType: Text.NativeRendering
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing to catch up on"
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }

    Flickable {
        id: centreList
        anchors.top: centreHeader.bottom
        anchors.topMargin: root.headerGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: rows.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: rows
            width: centreList.width
            spacing: root.rowGap

            Repeater {
                model: ScriptModel {
                    // Notifications are plain objects rebuilt on every
                    // change, so identity comparison would see them all
                    // as new. The id is what actually distinguishes them.
                    objectProp: "id"
                    values: Notifications.history
                }

                // A control-centre card, hugging what it holds.
                Item {
                    required property var modelData

                    width: rows.width
                    height: face.implicitHeight + Theme.padCard * 2

                    Surface {
                        anchors.fill: parent
                        hovered: rowHover.containsMouse
                    }

                    // Under the face, so the face's close button sits
                    // on top of it and takes its own click.
                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        // The default action if there is one, as a
                        // click on the popup does; otherwise the first
                        // button, which is what this always did.
                        cursorShape: modelData.hasDefault
                                     || modelData.actions.length > 0
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!Notifications.activate(modelData)
                                && modelData.actions.length > 0)
                                Notifications.invoke(modelData, 0);
                            Notifications.dismiss(modelData);
                        }
                    }

                    NoticeFace {
                        id: face
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.padCard
                        anchors.rightMargin: Theme.padCard
                        entry: modelData
                        iconSize: 36
                        bodyLines: 2
                        dismissable: true
                        hovered: rowHover.containsMouse
                        onDismissed: Notifications.dismiss(modelData)
                    }
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
