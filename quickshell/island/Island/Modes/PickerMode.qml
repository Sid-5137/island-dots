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

    // Every entry is an object, whatever the tab is showing. The strip
    // has four quite different things to draw now and a bare string
    // cannot say which one it is.
    readonly property var items: {
        switch (win.picker) {
            case "wallpaper":
                return Wallpaper.list.map(function(path) {
                    return { kind: "image", value: path };
                });

            case "theme": {
                // Presets first. They are the larger decision — a
                // preset replaces the palette outright, where a
                // scheme only says how to read the wallpaper — and
                // putting them at the head means the strip opens on
                // them rather than scrolled past them.
                const out = Theming.palettes.map(function(p) {
                    return {
                        kind: "preset", value: p.value, label: p.label,
                        base: p.base, surface: p.surface,
                        text: p.text, accents: p.accents
                    };
                });

                for (const s of Theming.schemes)
                    out.push({ kind: "scheme", value: s.value,
                               label: s.label });

                return out;
            }

            default: return [];
        }
    }

    readonly property string current: {
        switch (win.picker) {
            case "wallpaper": return Wallpaper.current;
            // Whichever of the two is actually in force. A scheme
            // shown as selected while a preset is driving the palette
            // would be pointing at the wrong answer.
            case "theme":
                return Config.appearance.colorSource === "preset"
                    ? Config.appearance.preset
                    : Config.wallpaper.scheme;
            default: return "";
        }
    }

    // Choosing from the strip also chooses where colour comes from. A
    // preset is not a scheme applied to the wallpaper; it is the other
    // source entirely, and picking one has to say so or nothing
    // happens and the card just looks selected.
    readonly property bool isWallpaper: win.picker === "wallpaper"

    // What Enter does. Split out so the key handler and the click
    // handler cannot drift apart.
    function activate() {
        const item = items[grid.currentIndex];
        if (item) choose(item);
    }

    function choose(item) {
        switch (item.kind) {
            case "image":
                Wallpaper.set(item.value);
                break;

            case "preset":
                Config.appearance.colorSource = "preset";
                Config.appearance.preset = item.value;
                break;

            case "scheme":
                Config.appearance.colorSource = "wallpaper";
                Config.wallpaper.scheme = item.value;
                // Services/Wallpaper.qml re-renders on a source
                // change, but not on a scheme change while the source
                // was already the wallpaper — so ask.
                Wallpaper.reapply();
                break;

        }
    }

    Row {
        id: pickerTabs
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
            // Two, not three. An icon theme is picked once and then
            // left; it lives on the Appearance page, where a list
            // beats a grid of twenty near-identical folder icons.
            model: [
                { key: "wallpaper", label: "Wallpaper" },
                { key: "theme",     label: "Palette" }
            ]

            // An unselected tab used to be transparent, which made it
            // a word rather than a control — you found out the other
            // one was clickable by hovering it. They carry the chip's
            // resting wash now, and the selected one is filled.
            Button {
                required property var modelData

                implicitHeight: 26
                padding: Theme.padCard
                text: modelData.label
                kind: win.picker === modelData.key ? "primary" : "plain"
                onClicked: win.openPicker(modelData.key)
            }
        }
    }

    // A grid, not a strip. A wallpaper squeezed into a card narrower
    // than it is tall is cropped to the middle of itself, which is
    // the one part of a wallpaper that tells you least about it; and
    // a horizontal list with no scrollbar hides everything past the
    // fifth one behind a gesture nobody knows is there.
    GridView {
        id: grid

        anchors.top: pickerTabs.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14

        // Wallpapers want the width, palettes want the count: four
        // preset cards across is the whole set on one row.
        readonly property int columns: root.isWallpaper ? 3 : 4
        readonly property int gap: 10

        // GridView's cell includes the gap, so the card is inset
        // inside it rather than the grid being spaced.
        cellWidth: Math.floor(width / columns)

        // A wallpaper's row is whatever 16:9 makes it, and the panel
        // is sized to fit two of those. A palette has no aspect of its
        // own, so its rows divide the panel instead — the whole set is
        // twelve cards and they should all be on screen rather than
        // two and a half of them with the third cut off.
        cellHeight: root.isWallpaper
            ? Math.round((cellWidth - gap) * 9 / 16) + gap
            : Math.max(84, Math.floor(
                height / Math.max(1, Math.ceil(count / columns))))

        clip: true
        model: ScriptModel { values: root.items }

        // Flicking lands on a row rather than between two, so the
        // panel never shows a band of half a wallpaper at its edge.
        snapMode: GridView.SnapToRow

        // Arrow keys and Enter, because a grid you can only click is
        // a grid you have to leave the keyboard for — and the pill
        // already holds the keyboard while a picker is open.
        focus: island.isPicker
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: true

        Keys.onEscapePressed: win.closePicker()
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()

        // Open on whatever is in use, so the first arrow key moves
        // from there rather than from the corner.
        onCountChanged: positionOnCurrent()
        Component.onCompleted: positionOnCurrent()

        function positionOnCurrent() {
            const i = root.items.findIndex(function(it) {
                return it.value === root.current;
            });
            currentIndex = i >= 0 ? i : 0;

            // To the top of its row, not to the item. Contain scrolls
            // the shortest distance that makes the item visible,
            // which parks a half row against the top edge and reads
            // as the panel having been cut off rather than scrolled.
            const row = Math.floor(currentIndex / columns);
            const maxY = Math.max(0, contentHeight - height);
            contentY = Math.min(row * cellHeight, maxY);
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool active: modelData.value === root.current
            readonly property bool focused: grid.currentIndex === index
            readonly property bool isImage: modelData.kind === "image"
            readonly property bool isPreset: modelData.kind === "preset"

            // ClippingRectangle, not Rectangle: `clip` on a Rectangle
            // clips to the bounding box and ignores the radius, so a
            // thumbnail inside one keeps its square corners and
            // overhangs the rounded border at all four of them.
            ClippingRectangle {
                id: card
                anchors.fill: parent
                anchors.margins: grid.gap / 2
                radius: Theme.radiusLarge

                // A preset's card is drawn in the preset's own
                // background, so the grid is a set of small desktops
                // rather than a set of labels.
                color: cell.isPreset ? cell.modelData.base : Theme.surfaceHigh

                border.width: cell.active ? 2 : 1
                border.color: cell.active
                    ? Theme.primary
                    : (cell.focused || cardHover.containsMouse
                       ? Theme.outlineVariant
                       : Theme.fade(Theme.outlineVariant))

                Behavior on border.color {
                    ColorAnimation { duration: Motion.fadeIn }
                }

                Image {
                    anchors.fill: parent
                    visible: cell.isImage
                    source: cell.isImage ? "file://" + cell.modelData.value : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // Decoding a 4K wallpaper at full size for a
                    // 220px card is pure waste.
                    sourceSize.width: 440
                    opacity: cell.active || cell.focused
                             || cardHover.containsMouse ? 1 : 0.78

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fadeIn }
                    }
                }

                // The name, while you are on it. Wallpapers are often
                // named something meaningful and the card is small.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 20
                    visible: cell.isImage
                    color: Qt.rgba(0, 0, 0, 0.62)
                    opacity: cardHover.containsMouse || cell.focused ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fadeIn }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            const v = String(cell.modelData.value);
                            return v.slice(v.lastIndexOf("/") + 1);
                        }
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 2
                        elide: Text.ElideMiddle
                        renderType: Text.NativeRendering
                    }
                }

                // A preset, as its own palette. One accent dot cannot
                // tell Mocha from Macchiato — they differ in their
                // surfaces far more than in their mauve — so the card
                // shows the stack: the background it will give you, a
                // bar of the surface that sits on it, and the accents
                // in a row.
                Column {
                    anchors.centerIn: parent
                    visible: cell.isPreset
                    spacing: 7
                    width: parent.width - 24

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.label || ""
                        color: cell.modelData.text || Theme.text
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        width: parent.width
                        height: 10
                        radius: Theme.radiusSmall
                        color: cell.modelData.surface || "transparent"
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5

                        Repeater {
                            model: cell.modelData.accents || []

                            Rectangle {
                                required property var modelData
                                width: 13
                                height: 13
                                radius: width / 2
                                color: modelData
                            }
                        }
                    }
                }

                // A scheme has no palette of its own to show: it is a
                // way of reading the wallpaper, and what it produces
                // is the palette already on screen.
                Column {
                    anchors.centerIn: parent
                    visible: !cell.isImage && !cell.isPreset
                    spacing: 8
                    width: parent.width - 16

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30; height: 30; radius: width / 2
                        color: Theme.primary
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.label || ""
                        color: cell.active ? Theme.primary : Theme.text
                        font.family: Theme.fontIsland
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: cardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = cell.index;
                        root.choose(cell.modelData);
                    }
                }
            }
        }
    }
}
