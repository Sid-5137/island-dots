import QtQuick
import "root:/Services"
import "root:/Widgets"

Column {
    spacing: 4

    SectionHeader { text: "Visibility" }

    ChoiceRow {
        label: "Mode"
        description: "Auto hides the island until you reach for it, or something needs your attention."
        current: Config.island.visibility
        options: [
            { value: "always", label: "Always" },
            { value: "auto",   label: "Auto" }
        ]
        onSelected: function(v) { Config.island.visibility = v }
    }

    SliderRow {
        label: "Reveal zone"
        from: 4; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.revealZone
        onMoved: function(v) { Config.island.revealZone = v }
    }

    ToggleRow {
        label: "Hide when fullscreen"
        description: "Keep the island out of the way of video and games."
        checked: Config.island.hideOnFullscreen
        onToggled: function(v) { Config.island.hideOnFullscreen = v }
    }

    SliderRow {
        label: "Collapse delay"
        description: "0 keeps it open until you click again."
        from: 0; to: 2000; stepSize: 50; suffix: " ms"
        value: Config.island.collapseDelay
        onMoved: function(v) { Config.island.collapseDelay = v }
    }

    SectionHeader { text: "Media" }

    ToggleRow {
        label: "Expand on track change"
        description: "Briefly open the island when a new song starts."
        checked: Config.island.expandOnTrackChange
        onToggled: function(v) { Config.island.expandOnTrackChange = v }
    }

    SliderRow {
        label: "Attention duration"
        from: 500; to: 6000; stepSize: 250; suffix: " ms"
        value: Config.island.attentionDuration
        onMoved: function(v) { Config.island.attentionDuration = v }
    }

    SectionHeader { text: "Appearance" }

    SliderRow {
        label: "Font size"
        description: "The clock and date in the collapsed pill."
        from: 9; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.fontSize
        onMoved: function(v) { Config.island.fontSize = v }
    }

    SliderRow {
        label: "Font weight"
        from: 300; to: 900; stepSize: 100
        value: Config.island.fontWeight
        onMoved: function(v) { Config.island.fontWeight = v }
    }

    ToggleRow {
        label: "Show workspaces"
        description: "Dashes in the pill; click one to switch."
        checked: Config.island.showWorkspaces
        onToggled: function(v) { Config.island.showWorkspaces = v }
    }

    SliderRow {
        label: "Tile icon nudge"
        description: "Shifts control-centre glyphs up or down, for icon fonts whose metrics sit off-centre."
        from: -12; to: 12; stepSize: 1; suffix: " px"
        value: Config.island.tileIconOffset
        onMoved: function(v) { Config.island.tileIconOffset = v }
    }

    SectionHeader { text: "Shape" }

    SliderRow {
        label: "Corner radius"
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.island.radius
        onMoved: function(v) { Config.island.radius = v }
    }

    SliderRow {
        label: "Top margin"
        from: 0; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.topMargin
        onMoved: function(v) { Config.island.topMargin = v }
    }

    SliderRow {
        label: "Padding"
        description: "Space inside the pill. The collapsed width is derived from the content plus this."
        from: 8; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.padding
        onMoved: function(v) { Config.island.padding = v }
    }

    SliderRow {
        label: "Minimum width"
        description: "The pill never narrows past this, even with little in it."
        from: 100; to: 320; stepSize: 4; suffix: " px"
        value: Config.island.idleWidth
        onMoved: function(v) { Config.island.idleWidth = v }
    }

    SliderRow {
        label: "Control centre width"
        from: 420; to: 720; stepSize: 4; suffix: " px"
        value: Config.island.controlWidth
        onMoved: function(v) { Config.island.controlWidth = v }
    }

    SliderRow {
        label: "Control centre height"
        from: 240; to: 460; stepSize: 4; suffix: " px"
        value: Config.island.controlHeight
        onMoved: function(v) { Config.island.controlHeight = v }
    }
}
