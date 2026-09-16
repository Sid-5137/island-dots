import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Horizontal strip of wallpapers, palettes and icon themes.
// Scroll to browse, click to apply.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent

    readonly property bool shown: island.isPicker

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    readonly property var items: {
        switch (win.picker) {
            case "wallpaper": return Wallpaper.list;
            case "theme": return [
                "scheme-monochrome", "scheme-neutral",
                "scheme-tonal-spot", "scheme-vibrant",
                "scheme-expressive", "scheme-content",
                "scheme-fidelity", "scheme-rainbow"
            ];
            case "icon": return Theming.available;
            default: return [];
        }
    }

    readonly property string current: {
        switch (win.picker) {
            case "wallpaper": return Wallpaper.current;
            case "theme": return Config.wallpaper.scheme;
            case "icon": return Config.appearance.iconTheme;
            default: return "";
        }
    }

    function choose(v) {
        switch (win.picker) {
            case "wallpaper": Wallpaper.set(v); break;
            case "theme":
                Config.wallpaper.scheme = v;
                if (Wallpaper.current !== "") Wallpaper.generate(Wallpaper.current);
                break;
            case "icon": Config.appearance.iconTheme = v; break;
        }
    }

    Row {
        id: pickerTabs
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
            model: [
                { key: "wallpaper", label: "Wallpaper" },
                { key: "theme",     label: "Palette" },
                { key: "icon",      label: "Icons" }
            ]

            Rectangle {
                required property var modelData
                readonly property bool active: win.picker === modelData.key

                width: tabLabel.implicitWidth + 24
                height: 26
                radius: 8
                color: active ? Theme.primary
                    : (tabHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.active ? Theme.textOnPrimary : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: tabHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.openPicker(modelData.key)
                }
            }
        }
    }

    ListView {
        id: strip
        anchors.top: pickerTabs.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14

        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        model: ScriptModel {
            values: root.items
        }
        // Wheel scrolls the strip; a horizontal list
        // with no visible scrollbar is otherwise only
        // reachable by dragging.
        WheelHandler {
            onWheel: function(e) {
                strip.contentX -= e.angleDelta.y;
                strip.returnToBounds();
            }
        }

        delegate: Rectangle {
            required property var modelData

            readonly property bool active: modelData === root.current
            readonly property bool isImage: win.picker === "wallpaper"

            width: isImage ? 132 : 116
            height: strip.height
            radius: 10
            color: Theme.surfaceHigh
            border.width: active ? 2 : 1
            border.color: active ? Theme.primary
                : (cardHover.containsMouse ? Theme.outlineVariant : "transparent")
            clip: true

            Behavior on border.color { ColorAnimation { duration: 140 } }

            Image {
                anchors.fill: parent
                anchors.margins: parent.active ? 2 : 1
                visible: parent.isImage
                source: parent.isImage ? "file://" + modelData : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Decoding a 4K wallpaper at full size
                // for a 132px card is pure waste.
                sourceSize.width: 260
            }

            // Palettes and icon sets have no thumbnail,
            // so they get their name and a swatch.
            Column {
                anchors.centerIn: parent
                visible: !parent.isImage
                spacing: 8
                width: parent.width - 16

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34; height: 34; radius: 17
                    color: Theme.primary
                    visible: win.picker === "theme"
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: String(modelData).replace("scheme-", "")
                    color: parent.parent.active ? Theme.primary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.choose(modelData)
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: island.isPicker
        Keys.onEscapePressed: win.closePicker()
    }
}
