import QtQuick
import "root:/Services"

// The pill, drawn from the same settings the real one reads.
//
// Radius, opacity, padding, font size and weight were all sliders with
// a number beside them and no way to see the result without closing
// settings, looking up, and opening it again. This is the same shape
// on the same palette, so the number and the thing it controls are in
// one place.
//
// It sits on a strip of the current wallpaper because the pill's
// opacity only means anything against what is behind it.

Item {
    id: root

    // Draw the compact face, with workspaces, rather than the idle one.
    property bool compact: false

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 104

    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: 10
        color: Theme.surfaceLowest
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // A wide crop of a wallpaper at 104px tall needs nothing
            // like the full decode.
            sourceSize.width: 900
            visible: status === Image.Ready
        }

        // The pill is translucent over whatever is behind it and the
        // compositor blurs that. There is no blur available inside a
        // settings window, so this stands in for it — without some
        // separation the preview reads as far busier than the real
        // thing.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Rectangle {
            id: pill

            anchors.centerIn: parent

            readonly property color base:
                Qt.color(root.compact ? Theme.surfaceContainer
                                      : Theme.surfaceLowest)

            width: Math.max(root.compact ? Config.island.compactWidth
                                         : Config.island.idleWidth,
                            contents.implicitWidth + Config.island.padding * 2)
            height: root.compact ? Config.island.compactHeight
                                 : Config.island.idleHeight

            radius: Config.island.radius
            color: Qt.rgba(base.r, base.g, base.b, Config.island.opacity)
            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on width {
                NumberAnimation {
                    duration: Config.motion.morphDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: Config.motion.morphOvershoot
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Config.motion.morphDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: Config.motion.morphOvershoot
                }
            }
            Behavior on radius { NumberAnimation { duration: 140 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Row {
                id: contents
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(Clock.now, "HH:mm")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Config.island.fontSize
                    font.weight: Config.island.fontWeight
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(Clock.now, "ddd d MMM")
                    visible: !root.compact
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Config.island.fontSize - 2
                    font.weight: Config.island.fontWeight
                    renderType: Text.NativeRendering
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: root.compact && Config.island.showWorkspaces

                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: index === 0 ? 14 : 7
                            height: 3
                            radius: 1.5
                            color: index === 0 ? Theme.primary : Theme.outline
                        }
                    }
                }
            }
        }
    }

    // Toggling the face is the quickest way to check that a padding or
    // font change still fits in both.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.compact = !root.compact
    }

    // On its own backing: the label sits over a wallpaper, and at this
    // size dim grey on an arbitrary photograph is not readable.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 7
        width: hintText.implicitWidth + 14
        height: 19
        radius: 5
        color: Qt.rgba(0, 0, 0, 0.5)

        Text {
            id: hintText
            anchors.centerIn: parent
            text: root.compact ? "compact · click for idle"
                               : "idle · click for compact"
            color: "#e8e8ec"
            opacity: 0.85
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            renderType: Text.NativeRendering
        }
    }
}
