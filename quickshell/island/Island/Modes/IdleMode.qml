import QtQuick

import "root:/Services"
import "root:/Widgets"

// The collapsed pill.
//
// It holds the clock and nothing else it does not have to. The
// workspaces and the tray moved out to the pods either side; what is
// left is the one thing worth reading at every glance, and the one
// thing worth morphing the shape for.
//
// That one thing is media. A track starting is the island's own
// gesture — an equaliser appears beside the date and the pill grows a
// little to fit, because its width is derived from this row. Hovering
// adds the transport controls. Nothing here appears or disappears:
// each slot's width falls as the next one's rises, so the pill is
// always morphing rather than swapping.
//
// The title is not in the collapsed pill. It used to be, and it is the
// one thing here that cannot be read at a glance: it is as long as
// whoever named the track decided, it changes while you are not
// looking, and the pill changes width with it — so the shape at rest
// was a different shape every few minutes. Three animated bars say
// the same thing the glance is actually asking, which is whether
// something is playing. `island.pillTitle` puts it back.

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

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // The pill itself. Hovering a pod lifts all three shapes, but it
    // must not put buttons under a cursor that is somewhere else.
    readonly property bool hovered: island.pillHovered

    Text {
        id: timeText
        anchors.verticalCenter: parent.verticalCenter
        text: Clock.time
        color: Theme.primary
        font.family: Theme.fontFamily
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
        width: shown ? dateText.implicitWidth + 10 : 0
        height: dateText.implicitHeight
        clip: true

        // On the pill's own curve: these slots are the pill's
        // width, one level down.
        Behavior on width { Morph { shape: island } }

        Text {
            id: dateText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.date
            color: Theme.textDim
            font.family: Theme.fontFamily
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
        width: shown ? mediaRow.implicitWidth + 10 : 0
        height: mediaRow.implicitHeight
        clip: true

        // On the pill's own curve: these slots are the pill's
        // width, one level down.
        Behavior on width { Morph { shape: island } }

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
                        // The resting height is what a paused player
                        // shows, so it has to be legible on its own.
                        height: 9
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Player.playing ? Theme.primary : Theme.outline

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                        SequentialAnimation on height {
                            running: Player.playing && mediaSlot.shown
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
                font.family: Theme.fontFamily
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
                width: shown ? transport.implicitWidth + 6 : 0
                height: transport.implicitHeight
                clip: true

                Behavior on width { Morph { shape: island } }

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
                            { g: "⏮", act: "prev" },
                            { g: "",        act: "toggle" },
                            { g: "⏭", act: "next" }
                        ]

                        Text {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.act === "toggle"
                                ? (Player.playing ? "⏸" : "▶")
                                : modelData.g
                            color: modelData.act === "toggle"
                                ? Theme.primary : Theme.textDim
                            font.pixelSize: Config.island.fontSize
                            font.weight: Config.island.fontWeight

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
