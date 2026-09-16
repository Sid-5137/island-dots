import Quickshell.Widgets
import QtQuick

import "root:/Services"

// Now playing, as a card made out of the artwork.
//
// The artwork is the background rather than a thumbnail beside the
// text, which is the only way a media card ever looks like anything.
// The problem with doing that is the one saneAspect spends three
// minutes on in the Dynamite V3 video, and he is right about it: album
// art is whatever colour the label chose, the shell is whatever colour
// the wallpaper is, and the two have no reason to agree. Every card
// looks out of place except by accident.
//
//   https://www.youtube.com/watch?v=Ob98KFByTec
//
// The fix is a wash of the accent over the art. Enough that the card
// belongs to the theme, not so much that the artwork stops being
// recognisable — `island.artTint` is that dial, and the scrim under
// the text is separate from it so that making the card more colourful
// does not quietly make the title harder to read.
//
// Nothing is tinted where the background is already a themed,
// dimmed surface: a second wash over a first one is just a darker
// first one.

Item {
    id: root

    // See ConnRow: the words are optional, per control. With them off
    // the card is the artwork and the transport, which at two cells is
    // a better-looking thing than a title elided to five characters.
    property bool showText: true

    // Roomy enough for the artist line and the transport together.
    readonly property bool tall: height >= 70
    readonly property bool roomy: width >= 150

    signal opened()

    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surfaceHigh

        Image {
            id: art
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
            // The art is a background, so it is held back from full
            // strength before anything is laid over it. A tint over a
            // fully bright photograph has to be heavy enough to be
            // muddy before it reads as a tint at all.
            opacity: 0.62
        }

        // The wash. Over the art and under the scrim.
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: art.visible ? Config.island.artTint : 0.10

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
        }

        // Text legibility, which is a separate question from theming
        // and gets a separate rectangle. Weighted to the bottom, where
        // the transport is.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.62) }
            }
        }
    }

    // Outside the clip. A 1px stroke drawn inside a rounded clip loses
    // its outer half to the clip and reads as a half-pixel smudge that
    // varies around the curve.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: frame.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
        id: lines
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        anchors.top: parent.top
        anchors.topMargin: 10
        spacing: 0
        visible: root.showText

        Text {
            width: parent.width
            text: Player.title !== "" ? Player.title : "Nothing playing"
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.Bold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.tall && Player.artist !== ""
            text: Player.artist
            color: Qt.rgba(1, 1, 1, 0.78)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    // Transport. Centred, because it is the one thing on the card you
    // aim at without reading first.
    Row {
        id: transport
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.showText ? parent.bottom : undefined
        anchors.bottomMargin: root.tall ? Theme.padCard : 8
        anchors.verticalCenter: root.showText ? undefined
                                              : parent.verticalCenter
        spacing: root.roomy ? 14 : 8

        Repeater {
            model: [
                { glyph: "", act: "prev" },
                { glyph: "",       act: "play" },
                { glyph: "", act: "next" }
            ]

            Item {
                required property var modelData
                readonly property bool isPlay: modelData.act === "play"

                width: isPlay ? 26 : 18
                height: 26
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: parent.isPlay
                    color: Qt.rgba(1, 1, 1, tapped.containsMouse ? 0.28 : 0.18)

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.isPlay
                        ? (Player.playing ? "" : "")
                        : parent.modelData.glyph
                    color: Qt.rgba(1, 1, 1, tapped.containsMouse ? 1 : 0.85)
                    font.family: Theme.fontFamily
                    font.pixelSize: parent.isPlay ? 12 : 11
                }

                MouseArea {
                    id: tapped
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (parent.modelData.act) {
                            case "prev": Player.prev(); break;
                            case "next": Player.next(); break;
                            default:     Player.toggle();
                        }
                    }
                }
            }
        }
    }

    // How far through, along the bottom edge. A line rather than a
    // scrubber: at this size a draggable track would be four pixels
    // of target, and the strip along the panel's floor already has a
    // real one.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 2
        color: Qt.rgba(1, 1, 1, 0.14)
        visible: Player.available && Player.length > 0

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, Player.progress))
            height: parent.height
            color: Theme.primary
        }
    }

    MouseArea {
        anchors.fill: parent
        // Under the transport, which is declared above it. This is
        // only for the rest of the card.
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }
}
