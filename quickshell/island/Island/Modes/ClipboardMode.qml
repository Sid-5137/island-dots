import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"

// Clipboard history. Type to filter, Enter to copy, Escape to close.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    opacity: (island.isClipboard
              && pill.width > Config.island.clipWidth * 0.8) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    readonly property var filtered: {
        const q = win.clipQuery.trim().toLowerCase();
        if (q === "") return Clipboard.entries;
        return Clipboard.entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    Item {
        id: fieldRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.island.searchFieldHeight

        Text {
            id: clipCaret
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0ea"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
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
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: root.filtered.length
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: 1
            color: Theme.outlineVariant
            opacity: root.filtered.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.filtered.length === 0
        text: Clipboard.count === 0 ? "Nothing copied yet" : "No matches"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        renderType: Text.NativeRendering
    }

    ListView {
        id: list
        anchors.top: fieldRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 6

        model: ScriptModel {
            objectProp: "id"
            values: root.filtered
        }

        clip: true
        currentIndex: 0
        highlightMoveDuration: 110
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 44
        preferredHighlightEnd: height - 44

        Component.onCompleted: win.clipList = list

        delegate: Rectangle {
            required property var modelData
            required property int index

            readonly property bool active: index === list.currentIndex

            width: list.width
            height: Config.island.clipRowHeight
            color: active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.active ? 20 : 0
                color: Theme.primary
                Behavior on height {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
            }

            Text {
                id: clipIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                text: modelData.isImage ? "\uf03e" : "\uf15c"
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                anchors.left: clipIcon.right
                anchors.leftMargin: 10
                anchors.right: clipDelete.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.preview
                color: parent.active ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                id: clipDelete
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "\u00d7"
                color: delHover.containsMouse ? Theme.error : Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 16
                opacity: rowHover.containsMouse || parent.active ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 120 } }

                MouseArea {
                    id: delHover
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Clipboard.remove(modelData.id)
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                anchors.rightMargin: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    list.currentIndex = index;
                    win.copySelected();
                }
            }
        }
    }
}
