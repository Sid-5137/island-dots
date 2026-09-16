import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Clipboard history. Type to filter, Enter to copy, Escape to close.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    readonly property bool shown: island.isClipboard

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    readonly property var filtered: {
        const q = win.clipQuery.trim().toLowerCase();
        if (q === "") return Clipboard.entries;
        return Clipboard.entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    Item {
        id: fieldRow
        anchors.top: parent.top
        // Off the top edge by the same padCard the list keeps off the
        // bottom one. Island.qml spends it in the panel's height, so
        // the field moves down rather than the rows getting shorter —
        // and an empty panel comes out as a bar with the field centred
        // in it. See the geometry table there.
        anchors.topMargin: Theme.padCard
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.island.searchFieldHeight

        // See SearchMode: one left edge for the whole panel, clearing
        // both the row's inset and its icon's inset inside that.
        readonly property int gutter: Theme.padCard + Theme.padRow

        Text {
            id: clipCaret
            anchors.left: parent.left
            anchors.leftMargin: fieldRow.gutter
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.clipboard
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Config.island.fontWeight
        }

        TextInput {
            id: input
            anchors.left: clipCaret.right
            anchors.leftMargin: 14
            anchors.right: clipCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            clip: true

            text: win.clipQuery
            onTextChanged: {
                win.clipQuery = text;
                list.currentIndex = 0;
            }

            Keys.onEscapePressed: win.closeClipboard()
            Keys.onReturnPressed: win.copySelected()
            Keys.onEnterPressed: win.copySelected()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()

            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.decrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_D) {
                        // Delete the highlighted entry without leaving
                        // the field.
                        const e = root.filtered[list.currentIndex];
                        if (e) Clipboard.remove(e.id);
                        event.accepted = true;
                    }
                }
            }

            Component.onCompleted: win.clipInput = input

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: "Clipboard history"
                color: Theme.outline
                font: input.font
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: clipCount
            anchors.right: parent.right
            anchors.rightMargin: fieldRow.gutter
            anchors.verticalCenter: parent.verticalCenter
            text: root.filtered.length
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Theme.padCard
            anchors.right: parent.right
            anchors.rightMargin: Theme.padCard
            height: 1
            color: Theme.outlineVariant
            opacity: root.filtered.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.filtered.length === 0
        text: Clipboard.count === 0 ? "Nothing copied yet" : "No matches"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    ListView {
        id: list
        anchors.top: fieldRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // The list's floor, above the panel's — see SearchMode, which
        // explains what sits in the gap when there isn't one. Island
        // adds the same padCard to this panel's height.
        anchors.bottomMargin: Theme.padCard

        model: ScriptModel {
            objectProp: "id"
            values: root.filtered
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
                radius: Theme.inner(root.pill.radius, Theme.padCard)

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
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.left: clipIcon.right
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.right: clipDelete.left
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.preview
                    color: row.active ? Theme.primary : Theme.text
                    font.family: Theme.fontFamily
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
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
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
