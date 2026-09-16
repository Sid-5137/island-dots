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

    // One settings window, on the monitor Hyprland considers focused
    // rather than whichever screen happens to be first in the list.
    screen: Screens.active

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

        // The island's own motion, so the settings window arrives the
        // way everything else does. See Services/Motion.qml.
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? Motion.contentIn : Motion.contentOut
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.ease
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? Motion.expand : Motion.collapse
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.open ? Motion.arrive : Motion.settle
            }
        }

        // Swallow clicks so they don't reach the dismiss area behind.
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 216
            radius: Theme.radiusNormal
            color: root.tint(Theme.surfaceLowest, Config.appearance.panelOpacity)
            border.width: 1
            border.color: root.tint(Theme.outline, 0.30)
            clip: true

            // The island's second line — see Widgets/Bezel.qml. The
            // settings window is the largest rounded thing the shell
            // draws and so the one with the most corner to read, and
            // it was the only panel still drawn with a single stroke.
            // Two shells' worth of edge treatment is one shell too
            // many.
            Bezel { outer: sidebar.radius }

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
                    // Five, not seven. Wallpaper and the theming half
                    // of Appearance are one subject and are now one
                    // page; Motion was five sliders about the island
                    // and lives under it; Session and the compositor
                    // half of Appearance are both "the system".
                    model: root.pages

                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.id === root.page

                        width: sidebar.width - 28
                        height: 38
                        radius: Theme.radiusLarge
                        color: active
                            ? Theme.surfaceHigh
                            : (navHover.containsMouse ? Theme.surfaceLow : "transparent")

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                        // A rail that marks the current page without
                        // relying on the fill alone, which is a very
                        // small difference on a dark palette.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.active ? 20 : 0
                            radius: width / 2
                            color: Theme.primary

                            Behavior on height {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            id: navIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.glyph
                            color: parent.active ? Theme.primary : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.left: navIcon.right
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
            radius: Theme.radiusNormal
            color: root.tint(Theme.surface, Config.appearance.panelOpacity)
            border.width: 1
            border.color: root.tint(Theme.outline, 0.30)
            clip: true

            // Inside the pane rather than over the Flickable beside
            // it: the page content is inset by 26 and the edge by 2,
            // so they never meet.
            Bezel { outer: pane.radius }
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
                        case "control": return controlPage;
                        case "theme":   return themePage;
                        case "input":   return inputPage;
                        case "system":  return systemPage;
                        case "network": return networkPage;
                        default:        return islandPage;
                    }
                }

                // Fade between pages so switching doesn't snap.
                opacity: 1
                Behavior on opacity {
                    NumberAnimation { duration: Motion.fadeIn }
                }
            }
        }
    }

    readonly property var pages: [
        { id: "island",  label: "Island",  glyph: Icons.tabIsland },
        { id: "control", label: "Control", glyph: Icons.tabControl },
        { id: "theme",   label: "Theme",   glyph: Icons.tabTheme },
        { id: "input",   label: "Input",   glyph: Icons.tabInput },
        { id: "system",  label: "System",  glyph: Icons.tabSystem },
        { id: "network", label: "Network", glyph: Icons.tabNetwork }
    ]

    property string page: "island"

    // Old names still work: they are in muscle memory, in binds, and
    // in anything that scripted `settings page`.
    readonly property var aliases: ({
        appearance: "theme",
        wallpaper:  "theme",
        motion:     "island",
        session:    "system",
        // What the control centre's own settings tile opens, and the
        // name anyone would guess for it.
        centre:     "control",
        tiles:      "control"
    })

    onPageChanged: {
        // Back to the top. The Flickable outlives the page inside it,
        // so without this, arriving at a page lands you wherever you
        // happened to have scrolled the last one to — and on a short
        // page that is past the end of it, looking at nothing.
        scroll.contentY = 0;
        loader.opacity = 0;
        pageFade.restart();
    }

    Timer {
        id: pageFade
        interval: 60
        onTriggered: loader.opacity = 1
    }

    Component { id: islandPage;  IslandPage  { width: scroll.width } }
    Component { id: controlPage; ControlPage { width: scroll.width } }
    Component { id: themePage;   ThemePage   { width: scroll.width } }
    Component { id: inputPage;   InputPage   { width: scroll.width } }
    Component { id: systemPage;  SystemPage  { width: scroll.width } }
    Component { id: networkPage; NetworkPage { width: scroll.width } }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.open = !root.open }
        // `show` cannot be reached from the command line: qs's
        // own `ipc show` subcommand swallows the word before it
        // gets as far as the function name, and even `--` does not
        // help. `open` is the same thing under a name the CLI can
        // actually pass. Both are kept — `show` still works for
        // anything talking to the socket directly.
        function open(): void { root.open = true }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
        function page(name: string): void {
            root.page = root.aliases[name] || name;
            root.open = true;
        }
    }
}
