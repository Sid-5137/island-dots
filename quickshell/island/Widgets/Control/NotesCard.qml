import QtQuick

import "root:/Services"

// Recent notifications, in the panel.
//
// The island already shows a notification as it arrives and keeps a
// history panel of its own. What was missing was the middle case: you
// were away from the desk for ten minutes, you open the control
// centre, and you want to know whether anything happened. So this is
// deliberately not the history panel — no actions, no replies, no
// per-item dismiss. It is an answer to "did I miss anything", and
// clicking it opens the place where you can do something about it.

Item {
    id: root

    signal opened()

    Surface {
        anchors.fill: parent
        hovered: hover.containsMouse
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 8
        text: "Notifications"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
        font.letterSpacing: 0.4
        renderType: Text.NativeRendering
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: title.verticalCenter
        visible: Notifications.count > 0
        text: Notifications.count
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall - 1
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: title.bottom
        anchors.topMargin: 6
        visible: Notifications.count === 0
        text: "Nothing waiting"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }

    Column {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.top: title.bottom
        anchors.topMargin: 5
        spacing: 4
        clip: true

        // However many fit. The card is resizable, so the count is a
        // measurement rather than a constant — and one clipped half-row
        // at the bottom would say "there is more" more honestly than a
        // gap, but it would also be the only clipped thing in the
        // panel.
        readonly property int fits:
            Math.max(0, Math.floor((root.height - 34) / 26))

        Repeater {
            model: Notifications.history.slice(0, list.fits)

            Item {
                required property var modelData
                width: list.width
                height: 22

                Rectangle {
                    id: pip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 11; radius: 1.5
                    color: modelData.critical ? Theme.error : Theme.primary
                }

                Text {
                    id: app
                    anchors.left: pip.right
                    anchors.leftMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    text: modelData.appName || ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.left: app.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.summary || ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
