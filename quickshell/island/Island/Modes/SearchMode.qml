import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Application launcher. The pill widens into a search field and
// grows downward as results arrive.
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

    // The icon column's width, read by the row delegate and by the
    // field's glyph box so the two cannot drift. It was a literal in
    // the delegate and nothing at all in the field, which is how the
    // field ended up ten pixels to the left of the list it heads.
    readonly property int iconSize: 22

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

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
            width: root.iconSize
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
            Keys.onDownPressed: results.incrementCurrentIndex()
            Keys.onUpPressed: results.decrementCurrentIndex()

            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        results.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        results.decrementCurrentIndex();
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

        // Ends where the row cards end, rather than 4px short of
        // them. A rule that nearly lines up with the things under it
        // reads as a misalignment; one that lines up exactly reads as
        // the top edge of the list.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Theme.padCard
            anchors.right: parent.right
            anchors.rightMargin: Theme.padCard
            height: 1
            color: Theme.outlineVariant
            // Shown whenever there are rows under it, rather than
            // only once something has been typed. At rest the list is
            // already full — every app you have — and with no rule the
            // field floated over it with nothing to say the two were
            // one panel. The rule is the top edge of the list, so it
            // is there exactly when the list is.
            opacity: Search.results.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }
    }

    ListView {
        id: results
        Component.onCompleted: win.searchList = results

        anchors.top: fieldRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // The list ends where the cards do, rather than running to the
        // floor of the panel.
        //
        // It used to have no bottom margin at all, and the island
        // added ten pixels to the panel's height to compensate, so the
        // clip rectangle reached the very bottom edge while the last
        // card stopped short of it. That gap is empty at rest and is
        // exactly where a half-scrolled row sits — down in the panel's
        // bottom corners, where a rectangular clip cuts it off square.
        // A square-cornered card sliced inside a 36px corner is the
        // single thing that made this panel look like it was drawn for
        // a different shape, and it only ever appeared while scrolling,
        // which is why it read as a rendering fault.
        //
        // With the margin here instead, the clip stops a card's inset
        // above the floor: a row scrolling out goes under the edge at
        // the point where the corner has not started to curve in past
        // the cards yet. Island.qml adds the same padCard to the
        // panel's height, so the arithmetic still comes out at rows x
        // rowHeight exactly and no row is short of its own height.
        anchors.bottomMargin: Theme.padCard

        model: ScriptModel {

            values: Search.results

        }
        clip: true
        currentIndex: 0
        highlightMoveDuration: 110
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: Config.island.searchRowHeight
        preferredHighlightEnd: height - Config.island.searchRowHeight

        // A selected row is a card inside the panel, not a band across
        // it. Full-bleed was the one shape a rounded panel cannot
        // hold: at either end of the list the highlight does not end,
        // it gets sliced off by the clip, and a square-cornered stripe
        // running into a 36px corner reads as a rendering fault rather
        // than as a selection. The hard 2px rail that used to mark the
        // current row went with it — it was a square mark in a rounded
        // language, and an inset card has no edge for it to sit
        // against.
        //
        // Not Widgets/Control/Surface, which has two states and is
        // always in one of them. A list needs a third: a row that is
        // not the one you are on has to be nothing at all, because
        // eight washes stacked up is a texture rather than a list. The
        // alphas are Surface's, moved one rung down the ladder — what
        // it calls resting is this row's hover, and what it calls
        // hovered is this row's selection.
        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool active: index === results.currentIndex

            width: results.width
            height: Config.island.searchRowHeight

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.leftMargin: Theme.padCard
                anchors.rightMargin: Theme.padCard
                // Half the gap each, so two neighbouring cards are
                // spacingSmall apart and the first one clears the rule
                // above it by the same amount.
                anchors.topMargin: Theme.spacingSmall / 2
                anchors.bottomMargin: Theme.spacingSmall / 2

                // Concentric with the panel rather than a token of
                // its own — see Theme.inner. A card twelve pixels
                // inside a corner of 36 is round to 24, and nothing
                // else; radiusLarge said 17 and was wrong by seven
                // pixels at the bottom of every list, which is where
                // the eye checks. It follows the panel as the list
                // grows, because the panel's corner does: one result
                // is a nearly square card under a nearly square
                // corner, eight is a round one under a round one.
                radius: Theme.inner(root.pill.radius, Theme.padCard)

                color: row.active
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : (tap.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")

                border.width: 1
                border.color: row.active
                    ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                // Hover says the row is hoverable; only the press says
                // it was hit. Worth having even though the panel is
                // about to close over it — the confirmation lands
                // before the window goes, which is the difference
                // between launching something and hoping you did.
                scale: tap.pressed ? 0.97 : 1

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.hover
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.arrive
                    }
                }

                IconImage {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: root.iconSize
                    source: Quickshell.iconPath(row.modelData.icon,
                                                "application-x-executable")
                }

                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: Theme.gapBadge
                    anchors.right: rowGeneric.left
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: row.active ? Theme.primary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Config.island.fontWeight
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                Text {
                    id: rowGeneric
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padRow
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 150)
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.genericName || ""
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        results.currentIndex = row.index;
                        win.runSelected();
                    }
                }
            }
        }
    }
}
