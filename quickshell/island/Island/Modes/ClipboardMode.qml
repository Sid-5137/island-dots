import Quickshell
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"

// The clipboard's field. Type to filter, Enter to copy, Escape to
// close — the entries themselves are on the shelf below, in
// ClipList.qml, for the reason SearchMode.qml gives.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent

    readonly property bool shown: island.isClipboard

    // See SearchMode.step: ids do not cross files, so the selection
    // moves through the handle the window already holds.
    function step(delta) {
        if (!win.clipList) return;
        if (delta > 0) win.clipList.incrementCurrentIndex();
        else win.clipList.decrementCurrentIndex();
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // The filter itself moved to Island.qml: the geometry table needs
    // its length and the shelf's list needs its contents, and it was
    // already being computed twice.
    Item {
        id: fieldRow
        // Centred, because the pill is now a bar and nothing else.
        // This used to hang off the top edge by a padCard so that the
        // rows below it had somewhere to start; the rows are on the
        // shelf now and the field has the bar to itself.
        anchors.verticalCenter: parent.verticalCenter
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
            font.family: Theme.fontIcons
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Config.island.fontWeight
            renderType: Text.NativeRendering
        }

        TextInput {
            id: input
            anchors.left: clipCaret.right
            anchors.leftMargin: 14
            anchors.right: clipCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeNormal
            clip: true

            text: win.clipQuery
            onTextChanged: {
                win.clipQuery = text;
                // Guarded like SearchMode's: the list is on the shelf
                // and in another file, and a bare `list` here was a
                // ReferenceError on every keystroke once it moved.
                if (win.clipList) win.clipList.currentIndex = 0;
            }

            Keys.onEscapePressed: win.closeClipboard()
            Keys.onReturnPressed: win.copySelected()
            Keys.onEnterPressed: win.copySelected()
            Keys.onDownPressed: root.step(1)
            Keys.onUpPressed: root.step(-1)

            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        root.step(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        root.step(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_D) {
                        // Delete the highlighted entry without leaving
                        // the field.
                        const e = win.clipList
                            ? win.clipFiltered[win.clipList.currentIndex]
                            : null;
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
            text: win.clipFiltered.length
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }
}
