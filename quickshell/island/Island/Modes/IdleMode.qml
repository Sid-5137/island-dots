import QtQuick

import "root:/Services"
import "root:/Widgets"

// The collapsed pill: the clock, and media.
//
// Nothing here appears or disappears — each slot's width falls as the
// next one's rises, so the pill morphs rather than swaps. The pill's
// width is derived from this row.
//
// The title is deliberately absent: it is as long as whoever named the
// track decided and changes while you are not looking, so the shape at
// rest became a different shape every few minutes. Three animated bars
// answer what the glance actually asks. `island.pillTitle` puts it
// back.

Row {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.centerIn: parent

    // Zero, because the gaps belong to the slots. A slot that has
    // collapsed to nothing must take its spacing with it, or the pill
    // keeps ten pixels of air where the date used to be.
    spacing: 0

    // Named for what it is rather than for everything it is not. The
    // list of twelve negations this replaces also carried a height
    // gate, which is how the clock came back mid-collapse: the pill
    // passed under the threshold while it was still moving.
    readonly property bool shown:
        island.mode === "idle" || island.mode === "compact"

    // Two things decide whether the clock shows: the mode, faded as
    // usual, and how close the shape is to the pill — the other half of
    // panelLayer's openness in Island.qml. A panel opening takes the
    // clock away within its first forty pixels, and a panel closing
    // only gives it back in its last forty, so the two can never be on
    // screen at once however the spring is tuned. A fade on its own
    // timer could only guess where the spring would be. Measured
    // against the hovered height, so a hover lift leaves it alone.
    readonly property real closeness: Math.max(0, Math.min(1,
        1 - (pill.height - Config.island.compactHeight) / 40))

    property real fade: shown ? 1 : 0
    Behavior on fade { ContentFade { revealing: root.shown } }

    opacity: fade * closeness
    visible: opacity > 0.01

    // And settles in as it comes back: a touch small while the shape
    // is still closing, full size at rest.
    scale: 1 - (1 - Motion.contentFloor) * 0.5 * (1 - closeness)

    // The pill itself. Hovering a pod lifts all three shapes, but it
    // must not put buttons under a cursor that is somewhere else.
    readonly property bool hovered: island.pillHovered

    Text {
        id: timeText
        anchors.verticalCenter: parent.verticalCenter
        text: Clock.time
        color: Theme.primary
        font.family: Theme.fontIsland
        font.pixelSize: Config.island.fontSize
        font.weight: Config.island.fontWeight
        font.letterSpacing: 1.2
        renderType: Text.NativeRendering
    }

    // ── The date, while nothing is playing ───────────────────

    Item {
        id: dateSlot

        // The date stays now that the title has gone: there is room
        // for both, and a pill whose second field is the date except
        // when music is on is a pill you have to read twice.
        readonly property bool shown:
            !(root.island.media && Config.island.pillTitle)

        anchors.verticalCenter: parent.verticalCenter
        width: dateWidth.value
        height: dateText.implicitHeight
        clip: true

        // On the pill's own spring: these slots are the pill's width,
        // one level down, and a slot that arrived on a different
        // curve from the shape around it would read as two moves.
        Spring {
            id: dateWidth
            shape: island
            minimum: 0
            target: dateSlot.shown ? dateText.implicitWidth + 10 : 0
        }

        Text {
            id: dateText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.date
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Config.island.fontSize - 1
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }
    }

    // ── The track, while something is ────────────────────────

    Item {
        id: mediaSlot

        readonly property bool shown: root.island.media

        anchors.verticalCenter: parent.verticalCenter
        width: mediaWidth.value
        height: mediaRow.implicitHeight
        clip: true

        // As above.
        Spring {
            id: mediaWidth
            shape: island
            minimum: 0
            target: mediaSlot.shown ? mediaRow.implicitWidth + 10 : 0
        }

        Row {
            id: mediaRow
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // The equaliser. It reads as "this is playing" faster than
            // a glyph does, and it is what tells a paused player from
            // a running one without any text at all.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: 3

                    Rectangle {
                        id: bar

                        // Declared rather than assumed. A delegate only
                        // receives `index` implicitly under some
                        // conditions in Qt 6; where it does not, the
                        // stagger below computes a NaN duration and the
                        // whole animation silently fails to start.
                        required property int index

                        width: 2
                        // Still, by default: an equaliser caught mid-
                        // bar while something plays, level when it is
                        // paused. The shape and the colour say which,
                        // and neither needs a frame after the change.
                        //
                        // It used to dance the whole time, and that
                        // meant redrawing the island at the display's
                        // refresh rate — 120 commits a second, each
                        // re-blurred by Hyprland — for as long as any
                        // audio played. Measured, that was 15% of a
                        // core in the shell alone, and on this laptop
                        // the load was audible: the speakers crackled
                        // at high volume until the bars stopped.
                        // Config.island.animateBars brings it back.
                        readonly property var playingHeights: [7, 13, 9]
                        height: Player.playing ? playingHeights[index] : 9
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Player.playing ? Theme.primary : Theme.outline

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                        // One ease between the two shapes. Off while
                        // the loop below owns the height, or every
                        // step of it would be eased twice.
                        Behavior on height {
                            enabled: !Config.island.animateBars
                            NumberAnimation {
                                duration: Motion.fadeIn
                                easing.type: Easing.OutCubic
                            }
                        }

                        SequentialAnimation on height {
                            running: Config.island.animateBars
                                     && Player.playing && mediaSlot.shown
                                     && root.visible
                            loops: Animation.Infinite

                            PauseAnimation { duration: bar.index * 120 }
                            NumberAnimation {
                                to: 14; duration: 320
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                to: 5; duration: 320
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.island.pillTitle
                text: Player.title
                color: Theme.text
                font.family: Theme.fontIsland
                font.pixelSize: Config.island.fontSize
                font.weight: Config.island.fontWeight
                elide: Text.ElideRight
                // A title is allowed to make the pill wider, up to a
                // point. Past it the island stops being an island.
                width: Math.min(implicitWidth, 190)
                renderType: Text.NativeRendering
            }

            // Transport, on hover. Three targets is as much as the
            // collapsed shape can carry, and they are the three you
            // reach for.
            Item {
                id: transportSlot

                readonly property bool shown: root.hovered

                anchors.verticalCenter: parent.verticalCenter
                width: transportWidth.value
                height: transport.implicitHeight
                clip: true

                Spring {
                    id: transportWidth
                    shape: island
                    minimum: 0
                    target: transportSlot.shown
                        ? transport.implicitWidth + 6 : 0
                }

                Row {
                    id: transport
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    opacity: transportSlot.shown ? 1 : 0

                    Behavior on opacity {
                        ContentFade { revealing: transportSlot.shown }
                    }

                    Repeater {
                        model: [
                            { g: Icons.previous, act: "prev" },
                            { g: "",             act: "toggle" },
                            { g: Icons.next,     act: "next" }
                        ]

                        Text {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.act === "toggle"
                                ? (Player.playing ? Icons.pause : Icons.play)
                                : modelData.g
                            color: modelData.act === "toggle"
                                ? Theme.primary : Theme.textDim
                            font.family: Theme.fontIcons
                            // The pill's parity, not the text's: an odd
                            // icon in an even pill has half a pixel of
                            // slack, and it lands low. See LevelSlider.
                            font.pixelSize: Config.island.fontSize
                                - (Config.island.idleHeight
                                   - Config.island.fontSize) % 2
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                // Not hoverEnabled: a hovering child
                                // swallows the pill's own hover, and
                                // the pill would collapse out of
                                // compact the moment you reached for
                                // the button that only exists there.
                                onClicked: {
                                    if (modelData.act === "prev") Player.prev();
                                    else if (modelData.act === "next") Player.next();
                                    else Player.toggle();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
