import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "root:/Services"
import "root:/Widgets"
import "root:/Settings/Pages"

PanelWindow {
    id: root

    property bool open: false

    // Theme colours are hex strings with no alpha. This re-emits one
    // with the alpha we want, so Hyprland's blur rule has something
    // translucent to blur through.
    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // Only one settings window, on the focused screen.
    screen: Quickshell.screens[0]

    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-settings"

    // Needed for Escape to close and for future text entry.
    WlrLayershell.keyboardFocus: open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // A scrim, at a level the blur can still work through. Removing
    // it entirely made the panel read as floating in the desktop
    // rather than over it — blur separates texture, but not tone.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? Config.appearance.panelScrim : 0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    // Two surfaces with a gap, not one box divided by a line. The
    // sidebar is navigation and the pane is content; giving each its
    // own shape says so, and it matches the island's language.
    Item {
        id: panel

        focus: root.open
        Keys.onEscapePressed: root.open = false

        anchors.centerIn: parent
        width: 990
        height: 680

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        }

        // Swallow clicks so they don't reach the dismiss area behind.
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 216
            radius: Config.appearance.panelRadius
            color: root.tint(Theme.surfaceLowest, Config.appearance.panelOpacity)
            border.width: 1
            border.color: root.tint(Theme.outline, 0.30)
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                Text {
                    text: "ISLAND"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    font.letterSpacing: 4
                    bottomPadding: 18
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: [
                        { id: "island",     label: "Island" },
                        { id: "network",    label: "Network" },
                        { id: "input",      label: "Input" },
                        { id: "appearance", label: "Appearance" },
                        { id: "motion",     label: "Motion" },
                        { id: "wallpaper",  label: "Wallpaper" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.id === root.page

                        width: sidebar.width - 28
                        height: 36
                        radius: 8
                        color: active
                            ? Theme.surfaceHigh
                            : (navHover.containsMouse ? Theme.surfaceLow : "transparent")

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: parent.active ? Theme.primary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: parent.active ? Font.Bold : Font.Medium
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: navHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = modelData.id
                        }
                    }
                }
            }
        }

        Rectangle {
            id: pane
            anchors.left: sidebar.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: Config.appearance.panelRadius
            color: root.tint(Theme.surface, Config.appearance.panelOpacity)
            border.width: 1
            border.color: root.tint(Theme.outline, 0.30)
            clip: true
        }

        Flickable {
            id: scroll
            anchors.fill: pane
            anchors.margins: 26

            contentWidth: width
            contentHeight: loader.item ? loader.item.implicitHeight : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: loader
                width: scroll.width
                sourceComponent: {
                    switch (root.page) {
                        case "network":    return networkPage;
                        case "input":      return inputPage;
                        case "appearance": return appearancePage;
                        case "motion":     return motionPage;
                        case "wallpaper":  return wallpaperPage;
                        default:           return islandPage;
                    }
                }

                // Fade between pages so switching doesn't snap.
                opacity: 1
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }

    property string page: "island"

    onPageChanged: {
        loader.opacity = 0;
        pageFade.restart();
    }

    Timer {
        id: pageFade
        interval: 60
        onTriggered: loader.opacity = 1
    }

    Component { id: islandPage;    IslandPage { width: scroll.width } }
    Component { id: motionPage;    MotionPage { width: scroll.width } }
    Component { id: wallpaperPage;  WallpaperPage { width: scroll.width } }
    Component { id: appearancePage; AppearancePage { width: scroll.width } }
    Component { id: networkPage;    NetworkPage { width: scroll.width } }
    Component { id: inputPage;      InputPage { width: scroll.width } }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.open = !root.open }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
        function page(name: string): void { root.page = name; root.open = true }
    }
}
