import Quickshell.Services.SystemTray
import QtQuick

import "root:/Services"

// One StatusNotifierItem, at whatever size it is asked for.
//
// The tray pod draws its resting row and its open row as two separate
// layouts that cross-fade, so this exists to keep the click handling —
// which is fiddly, and the same in both — in one place.

Item {
    id: root

    // The SystemTray item.
    required property var item
    // The window a menu is displayed against. Menus are positioned
    // against a window, not against an icon.
    required property var win

    property int size: 16

    readonly property bool attention: item.status === Status.NeedsAttention

    width: size
    height: size

    Image {
        anchors.fill: parent
        source: root.item.icon
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        // Dimmed at rest so a row of tray icons reads as one quiet
        // block rather than as several things each asking to be
        // looked at.
        opacity: mouse.containsMouse ? 1 : 0.78

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -1
        width: Math.max(5, root.size * 0.34)
        height: width
        radius: width / 2
        visible: root.attention
        color: Theme.error
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: function(mouse) {
            const it = root.item;

            if (mouse.button === Qt.RightButton || it.onlyMenu) {
                if (it.hasMenu) {
                    // Relative to the window, not to the icon.
                    const p = root.mapToItem(null, 0, root.height + 10);
                    it.display(root.win, p.x, p.y);
                }
                return;
            }

            if (mouse.button === Qt.MiddleButton) {
                it.secondaryActivate();
                return;
            }

            it.activate();
        }
    }
}
