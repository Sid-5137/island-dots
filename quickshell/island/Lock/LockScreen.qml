import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/Services"

// The lock surface, one per screen. Clock, a password field, and
// nothing else — a lock screen is not a place to put widgets.

WlSessionLock {
    id: lock

    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.background

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        // The wallpaper is there for recognition, not for looking at.
        // Dimming it heavily keeps the field readable on any image.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.72
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Clock.time
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 84
                font.weight: Font.Light
                font.letterSpacing: 4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Clock.dateLong
                color: Qt.rgba(1, 1, 1, 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                font.letterSpacing: 2
                bottomPadding: 40
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 46
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: Lock.error
                    ? Theme.error
                    : (input.activeFocus ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18))

                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: Text.AlignVCenter

                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    color: "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    enabled: !Lock.busy
                    clip: true

                    text: Lock.entry
                    onTextChanged: Lock.entry = text
                    onAccepted: Lock.submit()

                    // The surface is created when the lock engages, so
                    // focus has to be taken then rather than at load.
                    Component.onCompleted: forceActiveFocus()

                    Connections {
                        target: Lock
                        function onEntryChanged() {
                            if (input.text !== Lock.entry) input.text = Lock.entry;
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === "" && !Lock.busy
                        text: "Password"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font: input.font
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 20
                text: Lock.busy ? "Checking…" : Lock.message
                color: Lock.error ? Theme.error : Qt.rgba(1, 1, 1, 0.55)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 40
            visible: Battery.present
            text: Battery.icon + "  " + Battery.level + "%"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
