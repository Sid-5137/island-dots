import QtQuick
import "root:/Services"

// The three corners, drawn at the radius each one is actually set to.
//
// "Corner radius: 8 px" is a number about a shape you cannot see from
// the page it is set on — the pill is behind the settings window, the
// window corners are off at the edges of the screen, and the panel is
// the thing you are looking through to read the slider. Three
// rectangles is the whole of what the setting does, so here they are.
//
// They matter most while the link is off: three numbers that are free
// to disagree are worth being able to compare at a glance, and the
// shapes disagreeing is easier to read than the numbers doing it.
//
// Not to scale, deliberately. A window corner of 8px on a 1920px
// screen shrunk into a 200px box would be a third of a pixel. These
// are drawn at the real radius on a shape big enough to show it, which
// is the comparison the page is actually about.

Item {
    id: root

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 104

    Rectangle {
        id: stage
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        radius: Theme.radiusNormal
        color: Theme.surfaceLowest
        clip: true

        // The same strip the island preview stands on: a corner cut
        // against a flat fill reads as a corner, and a corner cut
        // against something busy reads as the corner it will actually
        // be — which is the one question here.
        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 900
            visible: status === Image.Ready
            opacity: 0.55
        }

        Row {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: [
                    {
                        name: "Island",
                        // Not the raw setting: the pill's corner grows
                        // with the shape and settles at a capsule, so
                        // the number in the file is only the start of
                        // it. See Theme.corner — this is the radius
                        // the pill would actually draw at this height.
                        radius: Theme.corner(46),
                        w: 128, h: 46,
                        fill: Theme.surfaceContainer
                    },
                    {
                        name: "Panels",
                        radius: Config.appearance.panelRadius,
                        w: 128, h: 46,
                        fill: Theme.surface
                    },
                    {
                        name: "Windows",
                        radius: Config.appearance.windowRounding,
                        w: 128, h: 46,
                        fill: Theme.surfaceHigh
                    }
                ]

                Item {
                    required property var modelData

                    width: modelData.w
                    height: 64

                    // The same component the real surfaces are drawn
                    // with, so the preview shows the corner rather
                    // than a circular stand-in for it — smoothing is
                    // the other half of this section and a preview
                    // that ignored it would be worse than none.
                    Squircle {
                        width: parent.width
                        height: parent.modelData.h
                        radius: parent.modelData.radius
                        smoothing: Config.appearance.cornerSmoothing
                        color: parent.modelData.fill
                        borderWidth: 1
                        borderColor: Theme.outlineVariant
                        opacity: 0.94

                        // The radius is the thing being watched, so it
                        // moves the way the shell's own shapes do
                        // rather than snapping a step at a time.
                        Behavior on radius {
                            NumberAnimation {
                                duration: Motion.fadeIn
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.name + "  "
                            + Math.round(parent.modelData.radius) + " px"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
