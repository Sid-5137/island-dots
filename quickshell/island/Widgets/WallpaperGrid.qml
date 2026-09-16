import QtQuick
import "root:/Services"

// Wallpaper thumbnails. Picking one sets it and re-derives the
// palette, so this is also the palette control.

Item {
    id: root

    property int columns: 3
    property int spacing: 8

    // How many rows to show before folding the rest away. A folder of
    // forty wallpapers is an ordinary thing to have, and at three
    // across that is thirteen rows — enough to push everything else on
    // the page, including the palette the wallpaper decides, below the
    // fold. 0 shows all of them.
    property int maxRows: 3
    property bool expanded: false

    // Which monitor a click assigns to. "" means all of them, which is
    // the only meaning when per-monitor wallpapers are off.
    property string targetScreen: ""

    readonly property var all: Wallpaper.list

    readonly property int totalRows:
        Math.max(1, Math.ceil(all.length / columns))
    readonly property bool truncated:
        maxRows > 0 && !expanded && totalRows > maxRows

    // The wallpaper in use is always on screen, even when the folder
    // is long enough to be folded. Truncating a sorted list otherwise
    // hides it whenever its name sorts past the fold, and then the
    // grid cannot answer the one question you came to it with.
    readonly property var list: {
        if (!truncated) return all;

        const shown = all.slice(0, maxRows * columns);
        const active = Wallpaper.pathFor(targetScreen);
        if (active === "" || shown.indexOf(active) !== -1) return shown;

        return [active].concat(shown.slice(0, shown.length - 1));
    }

    readonly property int rows: Math.max(1, Math.ceil(list.length / columns))
    readonly property real cellWidth:
        (width - spacing * (columns - 1)) / columns
    readonly property real cellHeight: cellWidth * 9 / 16

    readonly property int gridHeight:
        all.length === 0 ? 72 : rows * cellHeight + (rows - 1) * spacing

    implicitWidth: parent ? parent.width : 400
    implicitHeight: gridHeight + (moreRow.visible ? moreRow.height : 0)

    Text {
        anchors.centerIn: parent
        visible: root.list.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing in " + Config.wallpaper.directory
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        elide: Text.ElideMiddle
        renderType: Text.NativeRendering
    }

    Grid {
        id: grid
        width: parent.width
        height: root.gridHeight
        columns: root.columns
        spacing: root.spacing
        visible: root.list.length > 0

        Repeater {
            model: root.list

            Rectangle {
                id: cell
                required property var modelData

                readonly property bool active:
                    modelData === Wallpaper.pathFor(root.targetScreen)

                // Derived from root, not from the Grid: a Grid sizes
                // itself from its children, so asking it how wide it is
                // from inside a child is circular.
                width: root.cellWidth
                height: root.cellHeight
                radius: Theme.radiusLarge
                color: Theme.surfaceHigh
                clip: true

                border.width: active ? 2 : (cellHover.containsMouse ? 1 : 0)
                border.color: active ? Theme.primary : Theme.outlineVariant

                Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

                Image {
                    anchors.fill: parent
                    anchors.margins: cell.active ? 2 : 0
                    source: "file://" + cell.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // Without this every wallpaper is decoded at full
                    // resolution to fill a thumbnail.
                    sourceSize.width: 420
                    opacity: cellHover.containsMouse || cell.active ? 1 : 0.72

                    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
                }

                // The filename, on hover. Wallpapers are often named
                // something meaningful and the thumbnail is small.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 20
                    color: Qt.rgba(0, 0, 0, 0.62)
                    opacity: cellHover.containsMouse ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7
                        verticalAlignment: Text.AlignVCenter
                        text: cell.modelData.slice(
                            cell.modelData.lastIndexOf("/") + 1)
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 2
                        elide: Text.ElideMiddle
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: cellHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpaper.set(cell.modelData, false,
                                             root.targetScreen)
                }
            }
        }
    }

    // Only when there is something folded away, or something to fold.
    Item {
        id: moreRow
        anchors.top: grid.bottom
        width: parent.width
        height: 34
        visible: root.truncated || root.expanded

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.expanded
                ? "Show fewer"
                : "Show all " + root.all.length
            color: moreHover.containsMouse ? Theme.primary : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        }

        MouseArea {
            id: moreHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
}
