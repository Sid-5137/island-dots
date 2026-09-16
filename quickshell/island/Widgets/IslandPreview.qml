import QtQuick
import "root:/Services"

// The island and its pods, drawn from the same settings the real ones
// read.
//
// Radius, opacity, padding, font size, pod gap and font weight were all
// sliders with a number beside them and no way to see the result
// without closing settings, looking up, and opening it again. This is
// the same three shapes on the same palette, so the number and the
// thing it controls are in one place.
//
// It sits on a strip of the current wallpaper because the pill's
// opacity only means anything against what is behind it.

Item {
    id: root

    // The open state: pods at full size, everything lifted. Clicking
    // the preview toggles it, which is the quickest way to check that a
    // padding or gap change still works in both.
    property bool open: false

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 104

    readonly property int shapeHeight: open ? Config.island.compactHeight
                                            : Config.island.idleHeight

    function tint(c) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, Config.island.opacity);
    }

    readonly property color shapeColor:
        tint(open ? Theme.surfaceContainer : Theme.surfaceLowest)

    // The real thing's contract, so the preview springs open and
    // settles shut exactly as the island does. See Services/Motion.qml.
    readonly property int morphTime: open ? Motion.hover : Motion.collapse
    readonly property var morphCurve: open ? Motion.arrive : Motion.settle

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

        // ── The workspace pod ────────────────────────────────

        Rectangle {
            id: leftPod

            anchors.right: pill.left
            anchors.rightMargin: Config.island.podGap
            anchors.verticalCenter: pill.verticalCenter

            readonly property bool shown: Config.island.showWorkspaces

            width: shown ? (root.open ? openDashes.implicitWidth + 16
                                      : restDashes.implicitWidth + 16)
                         : 0
            height: root.shapeHeight
            radius: Config.island.radius
            color: root.shapeColor
            border.width: shown ? 1 : 0
            border.color: Theme.outlineVariant
            opacity: shown ? 1 : 0
            clip: true

            Behavior on width { Morph { shape: root } }
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

            Row {
                id: restDashes
                anchors.centerIn: parent
                spacing: 4
                opacity: root.open ? 0 : 1
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: 120 } }

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: index === 0 ? 16 : (index === 3 ? 4 : 7)
                        height: 3
                        radius: 1.5
                        color: index === 0 ? Theme.primary
                            : (index === 3 ? Theme.outline : Theme.textDim)
                    }
                }
            }

            Row {
                id: openDashes
                anchors.centerIn: parent
                spacing: 5
                opacity: root.open ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: 120 } }

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        readonly property bool active: index === 0

                        anchors.verticalCenter: parent.verticalCenter
                        width: active ? 24 : 18
                        height: 18
                        radius: 5
                        color: active ? Theme.primary
                            : (index === 3 ? "transparent"
                                           : Qt.rgba(1, 1, 1, 0.12))
                        border.width: index === 3 ? 1 : 0
                        border.color: Theme.outline

                        Text {
                            anchors.centerIn: parent
                            text: parent.index + 1
                            color: parent.active ? Theme.textOnPrimary
                                                 : Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: Config.island.fontSize - 3
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        // ── The island ───────────────────────────────────────

        Rectangle {
            id: pill

            anchors.centerIn: parent

            width: Math.max(root.open ? Config.island.compactWidth
                                      : Config.island.idleWidth,
                            contents.implicitWidth + Config.island.padding * 2)
            height: root.shapeHeight

            radius: Config.island.radius
            color: root.shapeColor
            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on width { Morph { shape: root } }
            Behavior on height { Morph { shape: root } }
            Behavior on radius { NumberAnimation { duration: Motion.fadeIn } }
            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            Row {
                id: contents
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(Clock.now, "HH:mm")
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Config.island.fontSize
                    font.weight: Config.island.fontWeight
                    font.letterSpacing: 1.2
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(Clock.now, "ddd d MMM")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Config.island.fontSize - 1
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    renderType: Text.NativeRendering
                }
            }
        }

        // ── The tray pod ─────────────────────────────────────

        Rectangle {
            id: rightPod

            anchors.left: pill.right
            anchors.leftMargin: Config.island.podGap
            anchors.verticalCenter: pill.verticalCenter

            readonly property bool shown: Config.island.showTray
            readonly property int icon: root.open ? 18 : 16
            readonly property int gap: root.open ? 11 : 7

            width: shown ? 3 * icon + 2 * gap + 16 : 0
            height: root.shapeHeight
            radius: Config.island.radius
            color: root.shapeColor
            border.width: shown ? 1 : 0
            border.color: Theme.outlineVariant
            opacity: shown ? 1 : 0
            clip: true

            Behavior on width { Morph { shape: root } }
            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

            // Stand-ins. The real pod draws whatever has placed an icon;
            // what the preview is for is the shape around them.
            Row {
                anchors.centerIn: parent
                spacing: rightPod.gap

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: rightPod.icon
                        height: rightPod.icon
                        radius: 4
                        opacity: root.open ? 1 : 0.78
                        color: index === 0 ? Theme.primary
                            : (index === 1 ? Theme.secondary : Theme.tertiary)

                        Behavior on width { Morph { shape: root } }
                        Behavior on height { Morph { shape: root } }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
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
            text: root.open ? "open · click for rest"
                            : "at rest · click to open"
            color: "#e8e8ec"
            opacity: 0.85
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            renderType: Text.NativeRendering
        }
    }
}
