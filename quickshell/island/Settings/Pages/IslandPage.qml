import QtQuick
import "root:/Services"
import "root:/Widgets"

// The pill: when it shows, what it shows, and what shape it is.
//
// Everything below the preview used to be one flat list of eighteen
// rows, of which three are settings anyone changes twice and the rest
// are pixel sizes that exist so the shape can be tuned once. The
// tuning is still all here, one fold down.

Column {
    id: page
    spacing: 4

    SectionHeader { text: "Preview"; section: "island" }

    IslandPreview { width: parent.width }

    SectionHeader { text: "Visibility" }

    ChoiceRow {
        configKey: "island.visibility"
        label: "On screen"
        description: "Always keeps the strip reserved, so windows start"
            + " below the island. Smart gives windows the whole screen"
            + " and moves the island aside when one reaches it."
        current: Config.island.visibility
        options: [
            { value: "always", label: "Always" },
            { value: "smart",  label: "Smart" }
        ]
        onSelected: function(v) { Config.island.visibility = v }
    }

    ToggleRow {
        configKey: "island.hideOnFullscreen"
        label: "Hide when fullscreen"
        description: "Keeps it out of the way of video and games."
        checked: Config.island.hideOnFullscreen
        onToggled: function(v) { Config.island.hideOnFullscreen = v }
    }

    SectionHeader { text: "Collapsed face" }

    ChoiceRow {
        configKey: "island.face"
        label: "Shows"
        description: "Scroll over the pill to cycle without coming here."
        current: Config.island.face
        options: [
            { value: "clock", label: "Clock" },
            { value: "media", label: "Media" },
            { value: "tray",  label: "Tray" }
        ]
        onSelected: function(v) { Config.island.face = v }
    }

    ToggleRow {
        configKey: "island.showWorkspaces"
        label: "Show workspaces"
        description: "Dashes on hover; click one to switch."
        checked: Config.island.showWorkspaces
        onToggled: function(v) { Config.island.showWorkspaces = v }
    }

    ToggleRow {
        configKey: "island.faceIndicator"
        label: "Face indicator"
        description: "Dots on hover showing which face is active."
        checked: Config.island.faceIndicator
        onToggled: function(v) { Config.island.faceIndicator = v }
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
        configKey: "island.opacity"
        label: "Opacity"
        description: "Below 1.0 the wallpaper shows through and the"
            + " compositor blurs it."
        from: 0.5; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.island.opacity
        onMoved: function(v) { Config.island.opacity = v }
    }

    SliderRow {
        configKey: "island.padding"
        label: "Padding"
        description: "Space inside the pill. The collapsed width is its"
            + " contents plus this, so the pill grows to fit."
        from: 8; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.padding
        onMoved: function(v) { Config.island.padding = v }
    }

    SliderRow {
        configKey: "island.fontSize"
        label: "Font size"
        from: 9; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.fontSize
        onMoved: function(v) { Config.island.fontSize = v }
    }

    Disclosure {
        width: parent.width
        text: "Geometry"
        hint: "sizes for each mode"

        SliderRow {
            configKey: "island.topMargin"
            label: "Top margin"
            from: 0; to: 40; stepSize: 1; suffix: " px"
            value: Config.island.topMargin
            onMoved: function(v) { Config.island.topMargin = v }
        }

        SliderRow {
            configKey: "island.fontWeight"
            label: "Font weight"
            from: 300; to: 900; stepSize: 100
            value: Config.island.fontWeight
            onMoved: function(v) { Config.island.fontWeight = v }
        }

        SliderRow {
            configKey: "island.idleWidth"
            label: "Minimum width"
            description: "The pill never narrows past this."
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

        SliderRow {
            configKey: "island.searchWidth"
            label: "Launcher width"
            from: 380; to: 900; stepSize: 10; suffix: " px"
            value: Config.island.searchWidth
            onMoved: function(v) { Config.island.searchWidth = v }
        }

        SliderRow {
            configKey: "island.searchMaxRows"
            label: "Launcher results"
            description: "How many matches the launcher grows to show."
            from: 3; to: 14; stepSize: 1
            value: Config.island.searchMaxRows
            onMoved: function(v) { Config.island.searchMaxRows = v }
        }

        SliderRow {
            configKey: "island.clipMaxRows"
            label: "Clipboard rows"
            from: 3; to: 16; stepSize: 1
            value: Config.island.clipMaxRows
            onMoved: function(v) { Config.island.clipMaxRows = v }
        }

        SliderRow {
            configKey: "island.tileIconOffset"
            label: "Tile icon nudge"
            description: "Shifts control-centre glyphs, for icon fonts"
                + " whose metrics sit off-centre."
            from: -12; to: 12; stepSize: 1; suffix: " px"
            value: Config.island.tileIconOffset
            onMoved: function(v) { Config.island.tileIconOffset = v }
        }
    }

    Disclosure {
        width: parent.width
        text: "Timing"
        hint: "hover, collapse, notifications"

        SliderRow {
            configKey: "island.hoverGrace"
            label: "Hover grace"
            description: "How long it stays out after the cursor leaves."
                + " Without this the pill moves out from under the"
                + " cursor, loses hover, and hides."
            from: 0; to: 1200; stepSize: 50; suffix: " ms"
            value: Config.island.hoverGrace
            onMoved: function(v) { Config.island.hoverGrace = v }
        }

        SliderRow {
            configKey: "island.collapseDelay"
            label: "Collapse delay"
            description: "0 keeps the control centre open until you"
                + " click again, which is the default."
            from: 0; to: 2000; stepSize: 50; suffix: " ms"
            value: Config.island.collapseDelay
            onMoved: function(v) { Config.island.collapseDelay = v }
        }

        SliderRow {
            configKey: "island.revealZone"
            label: "Reveal zone"
            description: "Height of the strip at the top edge that"
                + " brings a hidden island back."
            from: 4; to: 40; stepSize: 1; suffix: " px"
            value: Config.island.revealZone
            onMoved: function(v) { Config.island.revealZone = v }
        }

        SliderRow {
            configKey: "island.notifyDuration"
            label: "Notification time"
            from: 1000; to: 15000; stepSize: 500; suffix: " ms"
            value: Config.island.notifyDuration
            onMoved: function(v) { Config.island.notifyDuration = v }
        }

        SliderRow {
            configKey: "island.notifyCriticalDuration"
            label: "Critical time"
            from: 2000; to: 30000; stepSize: 1000; suffix: " ms"
            value: Config.island.notifyCriticalDuration
            onMoved: function(v) { Config.island.notifyCriticalDuration = v }
        }

        SliderRow {
            configKey: "island.switcherCommitDelay"
            label: "Alt+Tab commit"
            description: "How long after the last Tab the switcher acts."
            from: 200; to: 1500; stepSize: 50; suffix: " ms"
            value: Config.island.switcherCommitDelay
            onMoved: function(v) { Config.island.switcherCommitDelay = v }
        }
    }

    Disclosure {
        width: parent.width
        text: "Media"
        hint: "2 settings"

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
    }

    Disclosure {
        width: parent.width
        text: "Motion"
        hint: "how the shape moves"

        SliderRow {
            configKey: "motion.morphDuration"
            label: "Morph duration"
            from: 100; to: 800; stepSize: 10; suffix: " ms"
            value: Config.motion.morphDuration
            onMoved: function(v) { Config.motion.morphDuration = v }
        }

        SliderRow {
            configKey: "motion.morphOvershoot"
            label: "Overshoot"
            description: "How far the shape springs past its target."
                + " 0 is a flat decelerate. The preview above uses the"
                + " same curve."
            from: 0; to: 2; stepSize: 0.05; decimals: 2
            value: Config.motion.morphOvershoot
            onMoved: function(v) { Config.motion.morphOvershoot = v }
        }

        SliderRow {
            configKey: "motion.contentThreshold"
            label: "Reveal threshold"
            description: "How far the pill must grow before its contents"
                + " appear. Higher means the shape leads more."
            from: 0.3; to: 1.0; stepSize: 0.05; decimals: 2
            value: Config.motion.contentThreshold
            onMoved: function(v) { Config.motion.contentThreshold = v }
        }

        SliderRow {
            configKey: "motion.fadeIn"
            label: "Content fade in"
            from: 40; to: 400; stepSize: 10; suffix: " ms"
            value: Config.motion.fadeIn
            onMoved: function(v) { Config.motion.fadeIn = v }
        }

        SliderRow {
            configKey: "motion.fadeOut"
            label: "Content fade out"
            from: 20; to: 300; stepSize: 10; suffix: " ms"
            value: Config.motion.fadeOut
            onMoved: function(v) { Config.motion.fadeOut = v }
        }
    }
}
