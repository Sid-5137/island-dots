import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Notification history, with per-item dismiss and clear all.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent
    anchors.margins: 16

    opacity: (island.isCentre
              && pill.width > Config.island.centreWidth * 0.8) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    Item {
        id: centreHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.count > 0
                ? Notifications.count + (Notifications.count === 1
                    ? " notification" : " notifications")
                : "Notifications"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.Bold
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.count > 0
            width: 66
            height: 24
            radius: 7
            color: clearHover.containsMouse
                ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Clear"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: clearHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.clear()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.outlineVariant
        }
    }

    Text {
        anchors.centerIn: parent
        visible: Notifications.count === 0
        text: "Nothing to catch up on"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        renderType: Text.NativeRendering
    }

    ListView {
        id: centreList
        anchors.top: centreHeader.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 6
        model: ScriptModel {
            // Notifications are plain objects rebuilt on every change,
            // so identity comparison would see them all as new. The id
            // is what actually distinguishes them.
            objectProp: "id"
            values: Notifications.history
        }
        delegate: Rectangle {
            required property var modelData

            width: centreList.width
            height: Config.island.centreRowHeight
            radius: 10
            color: rowHover.containsMouse
                ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)

            Behavior on color { ColorAnimation { duration: 120 } }

            // Critical keeps a mark in history, not
            // just in the popup that already went by.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: 3
                radius: 1.5
                visible: modelData.critical
                color: Theme.error
            }

            Rectangle {
                id: rowIconBox
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 9
                color: Theme.surfaceHigh
                clip: true

                Image {
                    id: rowImg
                    anchors.fill: parent
                    anchors.margins: modelData.image ? 0 : 9
                    source: modelData.image
                        ? modelData.image
                        : (modelData.appIcon
                           ? Quickshell.iconPath(modelData.appIcon, true) : "")
                    fillMode: modelData.image
                        ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !rowImg.visible
                    text: "\uf0f3"
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }
            }

            Column {
                anchors.left: rowIconBox.right
                anchors.leftMargin: 12
                anchors.right: rowDismiss.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: modelData.summary
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    text: modelData.body
                    visible: text !== ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    text: modelData.appName
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 2
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            Text {
                id: rowDismiss
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "\u00d7"
                color: dismissHover.containsMouse
                    ? Theme.text : Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 18

                MouseArea {
                    id: dismissHover
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismiss(modelData)
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: modelData.actions.length > 0
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (modelData.actions.length > 0)
                        Notifications.invoke(modelData, 0);
                    Notifications.dismiss(modelData);
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: island.isCentre
        Keys.onEscapePressed: win.closeCentre()
    }
}
