import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Super+W. Each workspace as a card holding live thumbnails of its
// windows, captured through the compositor. Click a card to switch,
// click a thumbnail to focus that window.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent
    anchors.margins: 12

    readonly property bool shown: island.isOverview

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // Hyprland's toplevel objects carry the address, and each wraps
    // the Wayland toplevel that screencopy can capture. This is the
    // bridge from a hyprctl window to a live thumbnail.
    function toplevelFor(address) {
        const all = Hyprland.toplevels.values;
        if (!all) return null;
        for (const t of all) {
            if (t.address === address) return t;
        }
        return null;
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: Wm.workspaces

            Rectangle {
                id: card
                required property var modelData
                readonly property bool active: modelData.id === Wm.activeId
                readonly property var wins:
                    Wm.allWindows.filter(w => w.workspaceId === modelData.id)

                width: Config.island.overviewCard
                height: Config.island.overviewCard * 0.68
                radius: Theme.radiusLarge
                color: active ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: active ? Theme.primary
                    : (cardHover.containsMouse ? Theme.outlineVariant : "transparent")
                clip: true

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 8
                    text: card.modelData.id
                    color: card.active ? Theme.primary : Theme.outline
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    z: 2
                }

                Text {
                    anchors.centerIn: parent
                    visible: card.wins.length === 0
                    text: "empty"
                    color: Theme.outline
                    font.family: Theme.fontIsland
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                // Thumbnails tile the card. One window fills it; more
                // split it into a grid, which is how GNOME lays out an
                // overview cell.
                // Below the thumbnail grid. A Grid does not accept
                // mouse events itself, so this still catches every
                // click that isn't on a thumbnail.
                MouseArea {
                    id: cardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const id = card.modelData.id;
                        win.closeOverview();
                        // Not Qt.callLater — see afterSurfaceDown in
                        // Island.qml. Dispatching before this surface
                        // has dropped its keyboard grab lets the
                        // compositor undo the switch.
                        win.afterSurfaceDown(() => Wm.switchTo(id));
                    }
                }

                Grid {
                    id: thumbs
                    anchors.fill: parent
                    anchors.margins: 6
                    anchors.topMargin: 22
                    columns: card.wins.length <= 1 ? 1 : 2
                    spacing: 4

                    readonly property int rows:
                        Math.max(1, Math.ceil(card.wins.length / columns))
                    readonly property int cellW: (width - spacing * (columns - 1)) / columns
                    readonly property int cellH: (height - spacing * (rows - 1)) / rows

                    Repeater {
                        model: card.wins

                        Rectangle {
                            id: thumb
                            required property var modelData
                            readonly property var toplevel: root.toplevelFor(modelData.address)

                            // A thumbnail is inside a card already,
                            // so it takes the chip's corner rather than
                            // the card's — the same corner twice, once
                            // nested in the other, reads as a mistake.
                            width: thumbs.cellW
                            height: thumbs.cellH
                            radius: Theme.radiusSmall
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: thumbHover.containsMouse
                                ? Theme.primary : Theme.fade(Theme.primary)
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 1
                                captureSource: thumb.toplevel ? thumb.toplevel.wayland : null
                                live: true
                                paintCursor: false
                                visible: hasContent
                            }

                            // Icon while the capture warms up, or if the
                            // toplevel couldn't be matched.
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: Math.min(parent.width, parent.height) * 0.4
                                source: Quickshell.iconPath(
                                    thumb.modelData.cls.toLowerCase(),
                                    "application-x-executable")
                                visible: !thumb.toplevel
                            }

                            MouseArea {
                                id: thumbHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const addr = thumb.modelData.address;
                                    win.closeOverview();
                                    win.afterSurfaceDown(
                                        () => Wm.focusWindow(addr));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: win.closeOverview()
        Keys.onReturnPressed: win.closeOverview()
    }
}
