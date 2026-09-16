import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Power actions. Destructive ones arm on first press and run on
// the second.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent

    readonly property bool shown: island.isSession

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: Session.actions

            Rectangle {
                required property var modelData

                required property int index

                readonly property bool armed: win.armed === modelData.id
                readonly property bool danger: Session.isDestructive(modelData.id)
                readonly property bool selected:
                    win.sessionIndex === index || btnHover.containsMouse

                width: 78
                height: 84
                radius: 10
                color: armed
                    ? Theme.error
                    : (selected ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                border.width: 1
                border.color: armed
                    ? Theme.error
                    : (selected ? Theme.outlineVariant : "transparent")

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.glyph
                        color: parent.parent.armed
                            ? Theme.textOnError
                            : (parent.parent.danger && parent.parent.selected
                               ? Theme.error : Theme.text)
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Config.island.fontWeight
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.parent.armed ? "Confirm" : modelData.label
                        color: parent.parent.armed ? Theme.textOnError : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: btnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.runAction(modelData.id)
                    // Hovering moves the keyboard
                    // selection too, so the two never
                    // disagree about what's active.
                    onContainsMouseChanged: {
                        if (containsMouse) win.sessionIndex = index;
                    }
                }
            }
        }
    }

    // Escape closes. Focus lands here because the
    // window holds exclusive keyboard focus while the
    // session state is active.
    Item {
        anchors.fill: parent
        focus: island.isSession

        Keys.onEscapePressed: win.closeSession()
        Keys.onLeftPressed: win.moveSession(-1)
        Keys.onRightPressed: win.moveSession(1)
        Keys.onReturnPressed: win.activateSession()
        Keys.onEnterPressed: win.activateSession()

        Keys.onPressed: function(event) {
            // h/l as well, for the vim-inclined.
            if (event.key === Qt.Key_H) {
                win.moveSession(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                win.moveSession(1);
                event.accepted = true;
            }
        }
    }
}
