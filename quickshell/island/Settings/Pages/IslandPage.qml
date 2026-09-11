import QtQuick
import "root:/Services"
import "root:/Widgets"

Column {
    spacing: 4

    SectionHeader { text: "Visibility"; section: "island" }

    ChoiceRow {
        configKey: "island.visibility"
        label: "Mode"
        description: "Always keeps the island on screen and windows below it. Smart lets windows use the full screen and moves the island out of the way when one reaches it."
        current: Config.island.visibility
        options: [
            { value: "always", label: "Always" },
            { value: "smart",  label: "Smart" }
        ]
        onSelected: function(v) { Config.island.visibility = v }
    }

    SliderRow {
        configKey: "island.hoverGrace"
        label: "Hover grace"
        description: "How long the island stays out after the cursor leaves."
        from: 0; to: 1200; stepSize: 50; suffix: " ms"
        value: Config.island.hoverGrace
        onMoved: function(v) { Config.island.hoverGrace = v }
    }

    SliderRow {
        configKey: "island.revealZone"
        label: "Reveal zone"
        from: 4; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.revealZone
        onMoved: function(v) { Config.island.revealZone = v }
    }

    ToggleRow {
        configKey: "island.hideOnFullscreen"
        label: "Hide when fullscreen"
        description: "Keep the island out of the way of video and games."
        checked: Config.island.hideOnFullscreen
        onToggled: function(v) { Config.island.hideOnFullscreen = v }
    }

    SliderRow {
        configKey: "island.collapseDelay"
        label: "Collapse delay"
        description: "0 keeps it open until you click again."
        from: 0; to: 2000; stepSize: 50; suffix: " ms"
        value: Config.island.collapseDelay
        onMoved: function(v) { Config.island.collapseDelay = v }
    }

    SectionHeader { text: "Media" }

    ToggleRow {
        configKey: "island.expandOnTrackChange"
        label: "Expand on track change"
        description: "Briefly open the island when a new song starts."
        checked: Config.island.expandOnTrackChange
        onToggled: function(v) { Config.island.expandOnTrackChange = v }
    }

    SliderRow {
        configKey: "island.attentionDuration"
        label: "Attention duration"
        from: 500; to: 6000; stepSize: 250; suffix: " ms"
        value: Config.island.attentionDuration
        onMoved: function(v) { Config.island.attentionDuration = v }
    }

    SectionHeader { text: "Faces" }

    ChoiceRow {
        configKey: "island.face"
        label: "Collapsed pill shows"
        description: "Scroll over the pill to cycle."
        current: Config.island.face
        options: [
            { value: "clock", label: "Clock" },
            { value: "media", label: "Media" },
            { value: "tray",  label: "Tray" }
        ]
        onSelected: function(v) { Config.island.face = v }
    }

    ToggleRow {
        configKey: "island.faceIndicator"
        label: "Face indicator"
        description: "Dots on hover showing which face is active."
        checked: Config.island.faceIndicator
        onToggled: function(v) { Config.island.faceIndicator = v }
    }

    SectionHeader { text: "Appearance" }

    SliderRow {
        configKey: "island.fontSize"
        label: "Font size"
        description: "The clock and date in the collapsed pill."
        from: 9; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.fontSize
        onMoved: function(v) { Config.island.fontSize = v }
    }

    SliderRow {
        configKey: "island.fontWeight"
        label: "Font weight"
        from: 300; to: 900; stepSize: 100
        value: Config.island.fontWeight
        onMoved: function(v) { Config.island.fontWeight = v }
    }

    ToggleRow {
        configKey: "island.showWorkspaces"
        label: "Show workspaces"
        description: "Dashes in the pill; click one to switch."
        checked: Config.island.showWorkspaces
        onToggled: function(v) { Config.island.showWorkspaces = v }
    }

    SliderRow {
        configKey: "island.tileIconOffset"
        label: "Tile icon nudge"
        description: "Shifts control-centre glyphs up or down, for icon fonts whose metrics sit off-centre."
        from: -12; to: 12; stepSize: 1; suffix: " px"
        value: Config.island.tileIconOffset
        onMoved: function(v) { Config.island.tileIconOffset = v }
    }

    SectionHeader { text: "Shape" }

    SliderRow {
        configKey: "island.radius"
        label: "Corner radius"
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.island.radius
        onMoved: function(v) { Config.island.radius = v }
    }

    SliderRow {
        configKey: "island.topMargin"
        label: "Top margin"
        from: 0; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.topMargin
        onMoved: function(v) { Config.island.topMargin = v }
    }

    SliderRow {
        configKey: "island.opacity"
        label: "Opacity"
        description: "Below 1.0 the wallpaper shows through and is blurred by the compositor."
        from: 0.5; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.island.opacity
        onMoved: function(v) { Config.island.opacity = v }
    }

    SliderRow {
        configKey: "island.padding"
        label: "Padding"
        description: "Space inside the pill. The collapsed width is derived from the content plus this."
        from: 8; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.padding
        onMoved: function(v) { Config.island.padding = v }
    }

    SliderRow {
        configKey: "island.idleWidth"
        label: "Minimum width"
        description: "The pill never narrows past this, even with little in it."
        from: 100; to: 320; stepSize: 4; suffix: " px"
        value: Config.island.idleWidth
        onMoved: function(v) { Config.island.idleWidth = v }
    }

    SliderRow {
        configKey: "island.controlWidth"
        label: "Control centre width"
        from: 420; to: 720; stepSize: 4; suffix: " px"
        value: Config.island.controlWidth
        onMoved: function(v) { Config.island.controlWidth = v }
    }

    SliderRow {
        configKey: "island.controlHeight"
        label: "Control centre height"
        from: 240; to: 460; stepSize: 4; suffix: " px"
        value: Config.island.controlHeight
        onMoved: function(v) { Config.island.controlHeight = v }
    }

    SectionHeader { text: "Everything" }

    Item {
        width: parent.width
        height: 52

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 130
            text: "Restore every page to its shipped values. Icon, cursor and GTK themes and the wallpaper directory are kept."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Rectangle {
            id: resetAll
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 118
            height: 32
            radius: 8

            property bool confirming: false

            color: confirming ? Theme.error
                : (allHover.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer)
            border.width: 1
            border.color: confirming ? Theme.error : Theme.outlineVariant

            Behavior on color { ColorAnimation { duration: 120 } }

            Timer {
                id: allArmed
                interval: 2500
                onTriggered: resetAll.confirming = false
            }

            Text {
                anchors.centerIn: parent
                text: resetAll.confirming ? "Confirm" : "Reset all"
                color: resetAll.confirming ? Theme.textOnError : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: allHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!resetAll.confirming) {
                        resetAll.confirming = true;
                        allArmed.restart();
                        return;
                    }
                    resetAll.confirming = false;
                    allArmed.stop();
                    Config.resetAll();
                }
            }
        }
    }
}
