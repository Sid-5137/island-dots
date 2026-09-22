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
    readonly property int springResponse:
        open ? Motion.hoverResponse : Motion.collapseResponse
    readonly property real springBounce:
        open ? Motion.arriveBounce : Motion.departBounce

    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Theme.radiusNormal
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

            // The pod's floor as well as its padding — a pod is never
            // narrower than it is tall. Four made-up workspaces never
            // reach it, but a preview that mirrors the pod has to
            // mirror the whole line or it is a preview of the old one.
            width: leftPodWidth.value
            height: root.shapeHeight

            Spring {
                id: leftPodWidth
                shape: root
                minimum: 0
                target: leftPod.shown
                    ? Math.max(root.shapeHeight,
                               (root.open ? openDashes.implicitWidth
                                          : restDashes.implicitWidth) + 16)
                    : 0
            }
            // The real pod's own line, against the same height — see
            // Theme.corner. Reading the slider directly drew a shape
            // the island never takes: at the default 8 the pill is
            // actually a 10, because the corner grows with the height,
            // and a preview two pixels off is a preview of something
            // else.
            radius: Theme.corner(height)
            color: root.shapeColor
            border.width: shown ? 1 : 0
            border.color: Theme.outlineVariant
            opacity: shown ? 1 : 0

            // A pod's second line. Gated with the pod by inheriting
            // its opacity rather than by repeating the condition.
            Bezel { outer: parent.radius }
            clip: true

            Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

            Row {
                id: restDashes
                anchors.centerIn: parent
                // The pod's own spacing per style — see
                // Island/Pods/WorkspacePod.qml, which this mirrors.
                spacing: Config.island.workspaceStyle === "dashes" ? 4
                       : Config.island.workspaceStyle === "dots" ? 5 : 7
                opacity: root.open ? 0 : 1
                visible: opacity > 0.01

                // The real pod's cross-fade, not a clock of its own —
                // see Widgets/ContentFade and Island/Pods/WorkspacePod.
                Behavior on opacity { ContentFade { revealing: !root.open } }

                Repeater {
                    model: 4

                    // Four made-up workspaces: the one you are on, two
                    // with windows, one empty. The shapes and sizes are
                    // the pod's, so picking a style below shows the
                    // style rather than an impression of it.
                    Item {
                        required property int index

                        readonly property bool active: index === 0
                        readonly property bool busy: index !== 3
                        readonly property string style:
                            Config.island.workspaceStyle
                        readonly property color tint: active ? Theme.primary
                            : (busy ? Theme.textDim : Theme.outline)

                        anchors.verticalCenter: parent.verticalCenter
                        width: style === "numbers" ? label.implicitWidth
                             : style === "icons" ? (busy ? 14 : 4)
                             : bar.width
                        height: 16

                        Rectangle {
                            id: bar
                            anchors.centerIn: parent
                            visible: parent.style === "dashes"
                                     || parent.style === "dots"
                            readonly property bool round:
                                parent.style === "dots"
                            width: round ? (parent.active ? 9
                                            : parent.busy ? 6 : 4)
                                         : (parent.active ? 16
                                            : parent.busy ? 7 : 4)
                            height: round ? width : 3
                            radius: height / 2
                            color: parent.tint
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            visible: parent.style === "numbers"
                            text: parent.index + 1
                            color: parent.tint
                            font.family: Theme.fontMono
                            font.pixelSize: Config.island.fontSize - 2
                            font.weight: parent.active ? Font.Bold
                                                       : Font.DemiBold
                            renderType: Text.NativeRendering
                        }

                        // A stand-in: the preview has no windows to
                        // take icons from, so it shows where they
                        // would sit and how much room they would take.
                        Rectangle {
                            anchors.centerIn: parent
                            visible: parent.style === "icons"
                            width: parent.busy ? 14 : 4
                            height: width
                            radius: parent.busy ? 4 : height / 2
                            color: parent.tint
                            opacity: parent.busy && !parent.active ? 0.5 : 1
                        }
                    }
                }
            }

            Row {
                id: openDashes
                anchors.centerIn: parent
                spacing: 5
                opacity: root.open ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity { ContentFade { revealing: root.open } }

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        readonly property bool active: index === 0

                        anchors.verticalCenter: parent.verticalCenter
                        width: active ? 24 : 18
                        height: 18
                        radius: Theme.radiusSmall
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

            width: pillWidth.value
            height: pillHeight.value

            Spring {
                id: pillWidth
                shape: root
                minimum: 0
                target: Math.max(root.open ? Config.island.compactWidth
                                           : Config.island.idleWidth,
                                 contents.implicitWidth
                                 + Config.island.padding * 2)
            }

            Spring {
                id: pillHeight
                shape: root
                minimum: 0
                target: root.shapeHeight
            }

            radius: Theme.corner(height)
            color: root.shapeColor
            border.width: 1
            border.color: Theme.outlineVariant

            // The pill's, so the preview and the pill agree about
            // what an edge is as well as about what a corner is.
            Bezel { outer: parent.radius }

            // No spring on radius, for the same reason the island
            // has none: the corner is a function of a height that is
            // already on a spring, so it arrives with the shape rather
            // than chasing it on a second clock.
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

            width: rightPodWidth.value
            height: root.shapeHeight

            Spring {
                id: rightPodWidth
                shape: root
                minimum: 0
                target: rightPod.shown
                    ? 3 * rightPod.icon + 2 * rightPod.gap + 16 : 0
            }
            radius: Theme.corner(height)
            color: root.shapeColor
            border.width: shown ? 1 : 0
            border.color: Theme.outlineVariant
            opacity: shown ? 1 : 0

            Bezel { outer: parent.radius }
            clip: true

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
                        // Circles, because Widgets/TrayIcon draws
                        // circles. The preview had them as rounded
                        // squares.
                        width: iconSize.value
                        height: iconSize.value
                        radius: width / 2
                        opacity: root.open ? 1 : 0.78
                        color: index === 0 ? Theme.primary
                            : (index === 1 ? Theme.secondary : Theme.tertiary)

                        Spring {
                            id: iconSize
                            shape: root
                            minimum: 0
                            target: rightPod.icon
                        }
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
        radius: Theme.radiusSmall
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
