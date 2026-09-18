import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"

// The clipboard's entries, on the shelf below the pill. The bottom
// half of ClipboardMode.qml, moved for the reason SearchList.qml
// gives.
//
// Unlike the launcher, this shelf is there whenever the clipboard is
// open, even with nothing on it. "Empty until you type" is what the
// launcher is for; the clipboard was opened on purpose, and "No
// matches" is the answer to a question somebody asked.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var shelf    // the surface this sits on

    anchors.fill: parent

    readonly property bool shown: island.isClipboard

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Text {
        anchors.centerIn: parent
        visible: win.clipFiltered.length === 0
        text: Clipboard.count === 0 ? "Nothing copied yet" : "No matches"
        color: Theme.outline
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    ListView {
        id: list
        anchors.fill: parent

        // See SearchList: the first card needs the same inset from the
        // shelf's top edge that the last one keeps from its bottom.
        anchors.topMargin: Theme.padCard
        // The list's floor, above the panel's — see SearchMode, which
        // explains what sits in the gap when there isn't one. Island
        // adds the same padCard to this panel's height.
        anchors.bottomMargin: Theme.padCard

        model: ScriptModel {
            objectProp: "id"
            values: win.clipFiltered
        }

        clip: true
        currentIndex: 0
        highlightMoveDuration: 110
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: Config.island.clipRowHeight
        preferredHighlightEnd: height - Config.island.clipRowHeight

        Component.onCompleted: win.clipList = list

        // The same card as SearchMode's, for the same reasons — the
        // two panels are the same object with a different list in it,
        // and they looked it everywhere except here.
        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool active: index === list.currentIndex

            width: list.width
            height: Config.island.clipRowHeight

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.leftMargin: Theme.padCard
                anchors.rightMargin: Theme.padCard
                anchors.topMargin: Theme.spacingSmall / 2
                anchors.bottomMargin: Theme.spacingSmall / 2

                // Concentric with the panel — see Theme.inner, and
                // SearchMode, whose rows this is a copy of down to
                // the inset it is measured from.
                radius: Theme.inner(root.shelf.radius, Theme.padCard)

                color: row.active
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : (rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")

                border.width: 1
                border.color: row.active
                    ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                scale: rowHover.pressed ? 0.97 : 1

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.hover
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.arrive
                    }
                }

                Text {
                    id: clipIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: row.modelData.isImage ? Icons.image : Icons.file
                    color: Theme.outline
                    font.family: Theme.fontIcons
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.left: clipIcon.right
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.right: clipDelete.left
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.preview
                    color: row.active ? Theme.primary : Theme.text
                    font.family: Theme.fontIsland
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Config.island.fontWeight
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                Text {
                    id: clipDelete
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u00d7"
                    color: delHover.containsMouse ? Theme.error : Theme.outline
                    font.family: Theme.fontIsland
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    opacity: rowHover.containsMouse || row.active ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

                    MouseArea {
                        id: delHover
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clipboard.remove(row.modelData.id)
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    // Clear of the delete cross, which does something
                    // else with the same click.
                    anchors.rightMargin: 34
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        list.currentIndex = row.index;
                        win.copySelected();
                    }
                }
            }
        }
    }
}
