import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Clock, workspaces and a playing indicator. Workspaces and the
// indicator are revealed on hover only.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Row {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.centerIn: parent
    spacing: 12

    // Gated on the pill's ACTUAL height, not on the
    // state — content can't appear inside a shape that
    // hasn't grown to fit it, however the morph is tuned.
    opacity: (!island.isExpanded && !island.isSearching
              && !island.isSession && !island.isControl && !island.isPicker
              && !island.isNotify && !island.isCentre && !island.isOsd
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

        readonly property bool shown: island.mode === "compact"

        width: shown ? implicitWidth : 0
        opacity: shown ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Playing indicator. Three bars beat a label:
        // it reads instantly and costs almost no width.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: island.media
            width: visible ? implicitWidth : 0

            Repeater {
                model: 3
                Rectangle {
                    width: 2
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.primary
                    radius: 1

                    SequentialAnimation on height {
                        running: Player.playing && hoverLeft.shown
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 120 }
                        NumberAnimation { to: 11; duration: 320; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 4;  duration: 320; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        // Workspaces as dashes: the active one stretches,
        // one holding windows is wider than an empty one.
        // Reads at a glance without relying on colour.
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

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 13
            color: Theme.outlineVariant
        }
    }

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
