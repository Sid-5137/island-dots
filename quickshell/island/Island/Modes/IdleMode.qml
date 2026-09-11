import Quickshell
import Quickshell.Io
import QtQuick

import Quickshell.Services.SystemTray

import "root:/Services"

// The collapsed pill. Scrolling over it cycles the face; hovering adds
// workspaces and the playing indicator to whichever face is showing.

Row {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.centerIn: parent
    spacing: 12

    opacity: (!island.isExpanded && !island.isSearching
              && !island.isSession && !island.isControl && !island.isPicker
              && !island.isNotify && !island.isCentre && !island.isOsd
              && !island.isAuth && !island.isClipboard
              && !island.isSwitcher && !island.isOverview
              && pill.height < Config.island.compactHeight + 8) ? 1 : 0
    scale: opacity > 0.5 ? 1.0 : 0.94
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutCubic }
    }

    Row {
        id: hoverLeft
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        readonly property bool shown:
            island.mode === "compact" && win.face !== "workspaces"

        width: shown ? implicitWidth : 0
        opacity: shown ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: Config.island.showWorkspaces && Wm.workspaces.length > 0
            width: visible ? implicitWidth : 0

            Repeater {
                model: Wm.workspaces

                Rectangle {
                    required property var modelData
                    readonly property bool active: modelData.id === Wm.activeId

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 16 : (modelData.windows > 0 ? 7 : 4)
                    height: 3
                    radius: 1.5
                    color: active
                        ? Theme.primary
                        : (modelData.windows > 0 ? Theme.textDim : Theme.outline)

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wm.switchTo(modelData.id)
                    }
                }
            }
        }

        // Playing indicator. Sits beside the workspaces on every face,
        // so a glance at the collapsed pill says whether something is
        // running without having to scroll to the media face.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            // Not on the media face — that face draws its own bars, and
            // two sets side by side is just noise.
            visible: island.media && win.face !== "media"
            width: visible ? implicitWidth : 0

            Repeater {
                model: 3

                Rectangle {
                    id: liveBar

                    // Declared, not assumed: without it the stagger
                    // below computes a NaN duration and the animation
                    // never starts.
                    required property int index

                    width: 2
                    height: 9
                    radius: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Player.playing ? Theme.primary : Theme.outline

                    Behavior on color { ColorAnimation { duration: 200 } }

                    SequentialAnimation on height {
                        running: Player.playing && hoverLeft.shown
                        loops: Animation.Infinite

                        PauseAnimation { duration: liveBar.index * 120 }
                        NumberAnimation {
                            to: 14; duration: 320; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 5; duration: 320; easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 13
            color: Theme.outlineVariant
        }
    }

    // Only the current face is laid out, so the pill's derived width
    // tracks whichever one is showing.

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: win.face === "clock"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.time
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Config.island.fontSize
            font.weight: Config.island.fontWeight
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }

        Text {
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

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9
        visible: win.face === "media"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: island.media

            Repeater {
                model: 3

                Rectangle {
                    id: bar

                    // Declared, not assumed. A delegate only receives
                    // `index` implicitly under some conditions in Qt 6;
                    // where it doesn't, the stagger below computes a
                    // NaN duration and the whole animation silently
                    // fails to start.
                    required property int index

                    width: 2
                    // Resting height is what a paused player shows, so
                    // it has to be legible on its own.
                    height: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: Player.playing ? Theme.primary : Theme.outline
                    radius: 1

                    Behavior on color { ColorAnimation { duration: 200 } }

                    SequentialAnimation on height {
                        running: Player.playing && win.face === "media"
                        loops: Animation.Infinite
                        alwaysRunToEnd: false

                        PauseAnimation { duration: bar.index * 120 }
                        NumberAnimation {
                            to: 13; duration: 320; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 5; duration: 320; easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: island.media ? Player.title : "Nothing playing"
            color: island.media ? Theme.primary : Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Config.island.fontSize
            font.weight: Config.island.fontWeight
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 190)
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: island.media && Player.artist !== ""
            text: Player.artist
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Config.island.fontSize - 1
            elide: Text.ElideRight
            width: visible ? Math.min(implicitWidth, 130) : 0
            renderType: Text.NativeRendering
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: win.face === "workspaces"

        Repeater {
            model: Wm.workspaces

            Rectangle {
                required property var modelData
                readonly property bool active: modelData.id === Wm.activeId

                anchors.verticalCenter: parent.verticalCenter
                width: active ? 24 : 18
                height: 18
                radius: 5
                color: active ? Theme.primary
                    : (modelData.windows > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                border.width: modelData.windows > 0 || active ? 0 : 1
                border.color: Theme.outline

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: parent.active ? Theme.textOnPrimary : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Config.island.fontSize - 3
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.switchTo(modelData.id)
                }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: win.face === "tray"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Tray.count === 0
            text: "No tray icons"
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Config.island.fontSize - 1
            renderType: Text.NativeRendering
        }

        Repeater {
            model: Tray.items

            Item {
                id: trayItem
                required property var modelData

                readonly property bool attention:
                    modelData.status === SystemTrayStatus.NeedsAttention

                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: trayItem.modelData.icon
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    opacity: trayMouse.containsMouse ? 1 : 0.8

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -1
                    width: 6
                    height: 6
                    radius: 3
                    visible: trayItem.attention
                    color: Theme.error
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: function(mouse) {
                        const item = trayItem.modelData;

                        if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                // Relative to the window, not the icon.
                                const p = trayItem.mapToItem(
                                    null, 0, trayItem.height + 8);
                                item.display(win, p.x, p.y);
                            }
                            return;
                        }

                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                            return;
                        }

                        item.activate();
                    }
                }
            }
        }
    }

    // Which face, as dots. Without it nothing says the pill scrolls.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        readonly property bool shown:
            Config.island.faceIndicator && win.faceHint

        width: shown ? implicitWidth : 0
        opacity: shown ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Repeater {
            model: win.faces

            Rectangle {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 3
                radius: 1.5
                opacity: modelData === win.face ? 1 : 0.35
                color: Theme.textDim

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
