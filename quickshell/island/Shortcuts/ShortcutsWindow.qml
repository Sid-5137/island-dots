import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Every keybind, on one surface.
//
// The shell has sixty-odd of them and the only place they existed was
// hypr/binds.lua, which is the right place for them to be defined and
// the wrong place to have to read them from — you cannot look up a
// shortcut in a Lua file while the thing you wanted the shortcut for
// is on screen.
//
// Super+Shift+S, and Super+/ as well, because a cheat sheet is the one
// window whose own shortcut you are least likely to remember.
//
// Same two surfaces as the settings window: a heading on its own
// shape, the rows on another. It reads what Hyprland is holding, not a
// list written out again here — see Services/Shortcuts.qml.

PanelWindow {
    id: root

    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    screen: Screens.active
    visible: Shortcuts.open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-shortcuts"
    WlrLayershell.keyboardFocus: Shortcuts.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Shortcuts.open ? Config.appearance.panelScrim : 0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Shortcuts.open = false
        }
    }

    Item {
        id: panel

        focus: Shortcuts.open
        Keys.onEscapePressed: Shortcuts.open = false

        anchors.centerIn: parent
        width: Math.min(1040, root.width - 80)
        height: Math.min(700, root.height - 80)

        opacity: Shortcuts.open ? 1 : 0
        scale: Shortcuts.open ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: Shortcuts.open ? Motion.contentIn : Motion.contentOut
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.ease
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Shortcuts.open ? Motion.expand : Motion.collapse
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Shortcuts.open ? Motion.arrive : Motion.settle
            }
        }

        MouseArea { anchors.fill: parent }

        // The heading, on its own shape — the settings window's sidebar
        // and pane, with one row instead of six.
        Item {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56

            Squircle {
                smoothing: Config.appearance.cornerSmoothing
                anchors.fill: parent
                radius: Theme.radiusNormal
                color: root.tint(Theme.surfaceLowest, Config.appearance.panelOpacity)
                borderWidth: 1
                borderColor: root.tint(Theme.outline, 0.30)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "SHORTCUTS"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                font.letterSpacing: 4
                renderType: Text.NativeRendering
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                // Named rather than counted down to a number: the point
                // is where the list comes from, which is the thing that
                // makes it trustworthy.
                text: Shortcuts.problem !== "" ? Shortcuts.problem
                    : "from hyprctl binds  ·  Esc to close"
                color: Shortcuts.problem !== "" ? Theme.error : Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }
        }

        Item {
            id: pane
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: head.bottom
            anchors.topMargin: 14
            anchors.bottom: parent.bottom

            Squircle {
                smoothing: Config.appearance.cornerSmoothing
                anchors.fill: parent
                radius: Theme.radiusNormal
                color: root.tint(Theme.surface, Config.appearance.panelOpacity)
                borderWidth: 1
                borderColor: root.tint(Theme.outline, 0.30)
            }
        }

        Flickable {
            anchors.fill: pane
            anchors.margins: 22

            contentWidth: width
            contentHeight: columns.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Two columns, because a group is a short list and a single
            // column of seven groups is mostly scrolling. Split by
            // weight rather than by count, so the two sides come out
            // near the same length whatever the groups happen to hold.
            Row {
                id: columns
                width: parent.width
                spacing: 26

                readonly property var split: {
                    const total = Shortcuts.groups.reduce(
                        (n, g) => n + g.binds.length + 2, 0);
                    const left = [];
                    const right = [];
                    let run = 0;

                    for (const g of Shortcuts.groups) {
                        if (run < total / 2) left.push(g);
                        else right.push(g);
                        run += g.binds.length + 2;
                    }
                    return [left, right];
                }

                Repeater {
                    model: columns.split

                    Column {
                        required property var modelData
                        width: (columns.width - columns.spacing) / 2
                        spacing: 2

                        Repeater {
                            model: parent.modelData

                            Column {
                                required property var modelData
                                width: parent.width
                                spacing: 2
                                bottomPadding: 14

                                SectionHeader { text: parent.modelData.name }

                                Repeater {
                                    model: parent.modelData.binds

                                    Item {
                                        required property var modelData
                                        width: parent.width
                                        height: 28

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: chord.left
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: parent.modelData.label
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                        }

                                        // The chord as separate caps,
                                        // not one string. "Super + Shift
                                        // + S" set as text is a sentence
                                        // you have to read; three keys
                                        // are three things you match
                                        // against your hand.
                                        Row {
                                            id: chord
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: parent.parent.modelData.keys

                                                Rectangle {
                                                    required property var modelData

                                                    width: cap.implicitWidth + 12
                                                    height: 20
                                                    radius: Theme.radiusSmall
                                                    color: Qt.rgba(1, 1, 1, 0.07)
                                                    border.width: 1
                                                    border.color: Theme.outlineVariant

                                                    Text {
                                                        id: cap
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        color: Theme.textDim
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeSmall - 1
                                                        font.weight: Font.DemiBold
                                                        renderType: Text.NativeRendering
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
