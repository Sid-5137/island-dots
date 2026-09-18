import QtQuick
import "root:/Services"

// Three tiled windows, at the gaps and rounding they are set to.
//
// Gaps are drawn at their REAL pixel size on a screen drawn small.
// Scaling them down with the screen would make an inner gap of 4 half
// a pixel, and the preview could not show the difference between any
// two values. The windows are to scale with each other; the gaps are
// to scale with your screen.

Item {
    id: root

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 140

    readonly property var a: Config.appearance

    Rectangle {
        id: screen
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        radius: Theme.radiusNormal
        color: Theme.surfaceLowest
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 900
            visible: status === Image.Ready
        }

        // The tiling area: the screen inset by the outer gap.
        Item {
            id: area
            anchors.fill: parent
            anchors.margins: root.a.gapsOut

            Behavior on anchors.margins {
                NumberAnimation { duration: Motion.fadeIn }
            }

            // Two on the left, one tall on the right — the smallest
            // arrangement that has an inner gap in both directions, so
            // one slider does not look like it only works sideways.
            Item {
                id: left
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round((parent.width - root.a.gapsIn) * 0.52)

                Tile {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.round((parent.height - root.a.gapsIn) / 2)
                    focused: true
                }

                Tile {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.round((parent.height - root.a.gapsIn) / 2)
                }
            }

            Tile {
                anchors.left: left.right
                anchors.leftMargin: root.a.gapsIn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }
        }
    }

    // One window. Inline rather than a file of its own: it is three
    // properties and it means nothing outside this diagram.
    component Tile: Rectangle {
        property bool focused: false

        radius: root.a.windowRounding
        color: focused ? Theme.surfaceHigh : Theme.surface

        // The real thing fades unfocused windows back, and that is a
        // setting on this page too.
        opacity: focused ? 1 : root.a.inactiveOpacity

        border.width: root.a.borderSize
        border.color: focused ? Theme.primary : Theme.outlineVariant

        Behavior on radius {
            NumberAnimation {
                duration: Motion.fadeIn
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
    }
}
