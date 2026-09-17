import Quickshell
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// The launcher's results, on the shelf below the pill.
//
// This was the bottom two thirds of SearchMode.qml, drawn inside the
// pill. It is a surface of its own now with a gap above it — the
// separation the settings window makes between its sidebar and its
// pane, and the gap the pods already keep beside the pill. The field
// stays a field and the list is a list, and the shape of each says
// which it is without either needing to be labelled.
//
// The shelf is passed in for its radius rather than the pill's: a
// card inset from a corner is concentric with the corner it is inside,
// and it is the shelf's corner these cards are inside now.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags
    required property var shelf    // the surface this sits on

    anchors.fill: parent

    readonly property bool shown: island.isSearching

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    ListView {
        id: results
        Component.onCompleted: win.searchList = results

        anchors.fill: parent

        // padCard at the top as well as the bottom now. It used to sit
        // directly under the field's rule inside one panel; on a surface
        // of its own the first card needs the same inset from the top
        // edge that the last one keeps from the bottom, or the list looks
        // like it is falling out of the shelf.
        anchors.topMargin: Theme.padCard

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
                radius: Theme.inner(root.shelf.radius, Theme.padCard)

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
                    implicitSize: Theme.iconRow
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
