import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Transient notification popup. Takes the island over for a few
// seconds, then hands it back.
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

    opacity: (island.isNotify
              && pill.width > Config.island.notifyWidth * 0.8) ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: win.fadeIn; easing.type: Easing.OutQuad }
    }

    readonly property var n: win.notice

    Rectangle {
        id: noticeIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 46
        radius: 10
        color: root.n && root.n.critical
            ? Theme.error : Theme.surfaceHigh
        clip: true

        Image {
            id: noticeImg
            anchors.fill: parent
            anchors.margins: root.n && root.n.image ? 0 : 11
            source: {
                if (!root.n) return "";
                if (root.n.image) return root.n.image;
                if (root.n.appIcon)
                    return Quickshell.iconPath(root.n.appIcon, true);
                return "";
            }
            fillMode: root.n && root.n.image
                ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !noticeImg.visible
            text: "\uf0f3"
            color: root.n && root.n.critical
                ? Theme.textOnError : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
    }

    Column {
        anchors.left: noticeIcon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: root.n ? root.n.summary : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: root.n ? root.n.body : ""
            visible: text !== ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            // Senders send markup whether or not it's
            // advertised; rendering it raw shows tags.
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: root.n ? root.n.appName : ""
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    // Click runs the first action if there is one, and
    // dismisses either way — a notification you've
    // acted on shouldn't linger.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            const n = root.n;
            if (mouse.button === Qt.LeftButton && n
                && n.actions.length > 0) {
                Notifications.invoke(n, 0);
            }
            win.dismissNotice();
        }
    }
}
