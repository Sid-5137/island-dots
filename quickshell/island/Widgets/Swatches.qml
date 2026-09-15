import QtQuick
import "root:/Services"

// The palette matugen derived from the wallpaper, as colour.
//
// The scheme selector used to be four words with no way to tell what
// any of them would do. The palette is the thing being chosen, and it
// is already loaded — so show it. Changing the wallpaper or the scheme
// repaints this within the time matugen takes, which makes the
// difference between Mono and Vibrant something you can see rather
// than something you have to apply and then go and look at.

Item {
    id: root

    // Roles worth showing, in the order they matter. The full palette
    // is 24 keys, most of which are surface steps a reader cannot
    // usefully tell apart at swatch size.
    readonly property var roles: [
        { key: "primary",          label: "Primary",   on: "onPrimary" },
        { key: "secondary",        label: "Secondary", on: "onSecondary" },
        { key: "tertiary",         label: "Tertiary",  on: "onTertiary" },
        { key: "error",            label: "Error",     on: "onError" },
        { key: "surface",          label: "Surface",   on: "onSurface" },
        { key: "surfaceContainer", label: "Container", on: "onSurface" },
        { key: "surfaceHigh",      label: "High",      on: "onSurface" },
        { key: "outline",          label: "Outline",   on: "surface" }
    ]

    property int columns: 4
    property int cellHeight: 54
    property int spacing: 6

    readonly property int rows: Math.ceil(roles.length / columns)

    implicitWidth: parent ? parent.width : 400
    implicitHeight: rows * cellHeight + (rows - 1) * spacing

    Grid {
        anchors.fill: parent
        columns: root.columns
        spacing: root.spacing

        Repeater {
            model: root.roles

            Rectangle {
                id: chip
                required property var modelData

                // Derived from the Grid's parent rather than the Grid:
                // a Grid takes its width from its children, so reading
                // it back here would be circular and collapse to zero.
                width: (root.width - root.spacing * (root.columns - 1))
                       / root.columns
                height: root.cellHeight
                radius: 8

                readonly property string hex:
                    Theme.palette[modelData.key] || "#000000"
                readonly property string inkHex:
                    Theme.palette[modelData.on] || "#ffffff"

                color: chip.hex
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                Behavior on color { ColorAnimation { duration: 260 } }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 7
                    text: chip.modelData.label
                    color: chip.inkHex
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                // The value, because a palette you can read off is a
                // palette you can reuse somewhere else.
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    text: chip.hex
                    color: chip.inkHex
                    opacity: 0.75
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall - 2
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
