import QtQuick
import "root:/Services"
import "root:/Widgets"

Column {
    id: page
    spacing: 4

    SectionHeader { text: "Source" }

    Item {
        width: parent.width
        height: 52

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: countText.left
            anchors.rightMargin: 16
            spacing: 2

            Text {
                text: "Directory"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: Config.wallpaper.directory
                color: Theme.outline
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideMiddle
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: countText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Wallpaper.list.length + " found"
            color: Theme.primary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }
    }

    ChoiceRow {
        label: "Colour scheme"
        description: "How the palette is derived from the wallpaper."
        current: Config.wallpaper.scheme
        options: [
            { value: "scheme-monochrome",  label: "Mono" },
            { value: "scheme-neutral",     label: "Neutral" },
            { value: "scheme-tonal-spot",  label: "Tonal" },
            { value: "scheme-vibrant",     label: "Vibrant" }
        ]
        onSelected: function(v) {
            Config.wallpaper.scheme = v;
            // Re-derive immediately so the change is visible.
            if (Wallpaper.current !== "") Wallpaper.generate(Wallpaper.current);
        }
    }

    SliderRow {
        label: "Crossfade"
        from: 0; to: 2000; stepSize: 50; suffix: " ms"
        value: Config.wallpaper.crossfadeDuration
        onMoved: function(v) { Config.wallpaper.crossfadeDuration = v }
    }

    SliderRow {
        label: "Rotate every"
        description: "0 disables automatic rotation."
        from: 0; to: 120; stepSize: 5; suffix: " min"
        value: Config.wallpaper.rotateMinutes
        onMoved: function(v) { Config.wallpaper.rotateMinutes = v }
    }

    SectionHeader { text: "Choose" }

    // Thumbnail grid. sourceSize keeps decoding cheap — without it
    // every full-resolution wallpaper would be decoded at full size.
    Grid {
        width: parent.width
        columns: 3
        spacing: 8

        Repeater {
            model: Wallpaper.list

            Rectangle {
                required property var modelData

                readonly property bool active: modelData === Wallpaper.current

                width: (page.width - 16) / 3
                height: width * 9 / 16
                radius: 6
                color: Theme.surfaceHigh
                clip: true

                border.width: active ? 2 : 0
                border.color: Theme.primary

                Image {
                    anchors.fill: parent
                    anchors.margins: parent.active ? 2 : 0
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 320
                    opacity: thumbHover.containsMouse || parent.active ? 1 : 0.75

                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }
                }

                MouseArea {
                    id: thumbHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpaper.set(modelData)
                }
            }
        }
    }
}
