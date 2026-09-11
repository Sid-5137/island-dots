import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Now playing, along the bottom of the control centre when
// something is playing.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    // Positioned rather than anchored. anchors.bottom put the strip at
    // the top of the panel, which means something else was setting the
    // vertical anchor first — an explicit y cannot be overridden that
    // way, and reads unambiguously.
    x: 12
    width: pill.width - 24

    // Positioned from the top of its band rather than from the bottom
    // of the pill. Deriving both y and height from the same number made
    // every adjustment cancel itself out: making the band taller moved
    // the strip down by exactly as much as it grew.
    //
    // The band is mediaStripHeight; the strip sits 12 into it and
    // leaves 12 below.
    height: Config.island.mediaStripHeight + 2
    y: pill.height - Config.island.mediaStripHeight - 14

    // No height gate. It was there to hold the strip back until the
    // pill had grown, but the opacity animation already covers the
    // morph, and a gate comparing against a configured height fails
    // silently the moment that height and the real one disagree.
    opacity: (island.isControl && island.media) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    // Same lift off the shared surface as the control centre's other
    // modules, so it reads as part of the set rather than as content
    // dropped onto the panel.
    Rectangle {
        anchors.fill: parent
        radius: Config.appearance.panelRadius
        color: {
            const c = Qt.color(Theme.surfaceContainer);
            return Qt.rgba(c.r, c.g, c.b, Config.island.opacity);
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: -1
    }

    // A small equaliser between the artwork and the title. Reads as
    // "this is playing" faster than the transport icons do, and gives
    // the strip something alive in it while a track runs.
    Row {
        id: stripBars
        anchors.left: stripArt.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        visible: Player.available

        Repeater {
            model: 4

            Rectangle {
                id: eqBar

                // Declared rather than assumed: without it the stagger
                // below computes a NaN duration and the animation
                // never starts.
                required property int index

                width: 3
                height: 10
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: Player.playing ? Theme.primary : Theme.outline

                Behavior on color { ColorAnimation { duration: 200 } }

                SequentialAnimation on height {
                    running: Player.playing && island.isControl
                    loops: Animation.Infinite

                    PauseAnimation { duration: eqBar.index * 110 }
                    NumberAnimation {
                        to: 22; duration: 300; easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        to: 6; duration: 300; easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Rectangle {
        id: stripArt
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 44
        radius: 8
        color: Theme.surfaceHigh
        clip: true

        Image {
            id: stripImg
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !stripImg.visible
            text: "\u266a"
            color: Theme.outline
            font.pixelSize: 20
        }
    }

    Column {
        anchors.left: stripBars.right
        anchors.leftMargin: 14
        anchors.right: stripControls.left
        anchors.rightMargin: 12
        anchors.verticalCenter: stripArt.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: Player.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: Player.artist
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Row {
        id: stripControls
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: stripArt.verticalCenter
        spacing: 18

        Repeater {
            model: [
                { g: "\u23ee", act: "prev" },
                { g: "",        act: "toggle" },
                { g: "\u23ed", act: "next" }
            ]

            Text {
                required property var modelData
                text: modelData.act === "toggle"
                    ? (Player.playing ? "\u23f8" : "\u25b6")
                    : modelData.g
                color: modelData.act === "toggle" ? Theme.primary : Theme.textDim
                font.pixelSize: 17

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
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
