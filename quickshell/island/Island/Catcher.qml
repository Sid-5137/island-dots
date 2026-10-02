import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/Services"

// Click outside to close: a transparent layer under the island that
// takes a click anywhere else on the screen while a panel is open.
//
// Wayland hands the shell no clicks outside its own surfaces, so
// something of the shell's has to be there to receive them. It used to
// be the island's own window, grown to the whole screen while a panel
// was open — which meant every frame of a panel opening redrew and
// re-blurred the whole screen. This draws nothing, is never blurred,
// and never redraws.
//
// It must stack below the island, and compositors stack surfaces on
// one layer in the order they were made: shell.qml declares this
// before Island, and it stays mapped from then on — one pixel tall and
// taking no input while nothing is open — so it never moves above it.
// Hyprland's focus grab was tried first and did not see clicks in the
// empty space either side of a panel, which is still inside the
// island's window.

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
        }

        // Every screen, not just the one the panel is on: a click on
        // the other monitor is outside too.
        readonly property bool active: Panels.open

        implicitHeight: active && screen ? screen.height : 1

        mask: active ? everywhere : nowhere

        property Region everywhere: Region { item: area }
        property Region nowhere: Region {}

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: root.active
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.closeRequested()
        }
    }
}
