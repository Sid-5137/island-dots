import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// The launcher's field. The pill widens into it and stops there —
// the results are on the shelf below, in SearchList.qml.
//
// The pill used to hold both and grow downward as matches arrived,
// which made it two shapes wearing one outline: a bar while empty, a
// tall panel once full, and a field that stopped reading as a field
// the moment it became the top edge of a box. It is the bar now, and
// it does not change height while you type.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent

    // Same geometry gate as the other content: the
    // field can't render inside a pill that hasn't
    // widened to hold it yet.
    readonly property bool shown: island.isSearching

    // Moving the selection goes through the same handle the rest of
    // the window already uses for the list — ids do not resolve across
    // files, and the list is a file away now. Guarded, because the
    // arrow keys work before anything has been typed and until then
    // there is no list to move.
    function step(delta) {
        if (!win.searchList) return;
        if (delta > 0) win.searchList.incrementCurrentIndex();
        else win.searchList.decrementCurrentIndex();
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

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

        // Every left edge in the launcher is this one: the caret, the
        // rule under the field, and the icon in each row below. A row
        // is inset from the panel by padCard and its icon sits padRow
        // inside that, so the field has to clear both to line up with
        // them.
        readonly property int gutter: Theme.padCard + Theme.padRow

        // The glyph sits in the icon column rather than merely
        // starting at it.
        //
        // A row's icon is a 22px square: the eye reads the column off
        // the middle of those squares, not off their left edge. The
        // caret is a thin glyph about ten pixels wide, so anchoring it
        // at the same x put its mass six pixels left of every icon
        // under it — close enough to look like a mistake rather than a
        // different kind of thing. Boxed and centred, it lands on the
        // column, and the field reads as the top of the list instead
        // of as a strip that happens to sit above one.
        Item {
            id: caretBox
            anchors.left: parent.left
            anchors.leftMargin: fieldRow.gutter
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconRow
            height: width

            Text {
                anchors.centerIn: parent
                text: "\u276f"
                color: Theme.primary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Config.island.fontWeight
                renderType: Text.NativeRendering
            }
        }

        TextInput {
            id: input
            Component.onCompleted: win.searchInput = input

            anchors.left: caretBox.right
            // gapBadge, because that is what a row puts between its
            // icon and its label. The 12 that used to be here was a
            // different number for the same gap, which left the
            // placeholder starting at 44 while every app name under it
            // started at 54. Ten pixels is invisible on one line and
            // unmistakable down eight of them.
            anchors.leftMargin: Theme.gapBadge
            anchors.right: hitCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Theme.fontFamily
            // The query is the largest text the shell shows outside
            // the clock, because it is the only text here you wrote.
            // At the body size it sat in the middle of a 46px row with
            // eighteen pixels of air above and below it, which reads
            // as a strip that happens to contain text rather than as
            // a field — and it made the panel's 36px corner look like
            // it belonged to something else.
            font.pixelSize: Theme.fontSizeLarge
            selectionColor: Qt.rgba(1, 1, 1, 0.25)
            selectedTextColor: Theme.text
            clip: true

            onTextChanged: {
                Search.query = text;
                if (win.searchList) win.searchList.currentIndex = 0;
            }

            Keys.onEscapePressed: win.closeSearch()
            Keys.onReturnPressed: win.runSelected()
            Keys.onEnterPressed: win.runSelected()
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
                    }
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: "Search"
                color: Theme.outline
                font: input.font
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: hitCount
            anchors.right: parent.right
            anchors.rightMargin: fieldRow.gutter
            anchors.verticalCenter: parent.verticalCenter
            text: input.text === "" ? "" : Search.results.length
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

    }
}
