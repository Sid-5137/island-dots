import QtQuick
import "root:/Services"
import "root:/Widgets"

// The pill: when it shows, what it shows, and what shape it is.
//
// The handful of settings anyone actually changes are up top; the
// pixel sizes that tune the shape once are behind a fold. A few keys
// are deliberately not in the window at all — still in settings.json
// and still editable by hand, just not charged to every reader of
// this page.
//
// Each setting lives on the page that draws the thing, and only
// there.

Column {
    id: page
    spacing: 4

    SectionHeader { text: "Preview"; section: "island" }

    IslandPreview { width: parent.width }

    SectionHeader { text: "Visibility" }

    ChoiceRow {
        configKey: "island.visibility"
        label: "On screen"
        description: "Always reserves the strip. Smart moves aside instead."
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
        description: "Out of the way of video and games."
        checked: Config.island.hideOnFullscreen
        onToggled: function(v) { Config.island.hideOnFullscreen = v }
    }

    SectionHeader { text: "Pods" }

    ToggleRow {
        configKey: "island.showWorkspaces"
        label: "Workspace pod"
        description: "Left of the island. Click a chip to switch."
        checked: Config.island.showWorkspaces
        onToggled: function(v) { Config.island.showWorkspaces = v }
    }

    ChoiceRow {
        configKey: "island.workspaceStyle"
        label: "Workspaces at rest"
        description: "What the pod draws when you are not pointing at it."
        current: Config.island.workspaceStyle
        options: [
            { value: "dashes",  label: "Dashes" },
            { value: "dots",    label: "Dots" },
            { value: "numbers", label: "Numbers" },
            { value: "icons",   label: "Icons" }
        ]
        onSelected: function(v) { Config.island.workspaceStyle = v }
    }

    ToggleRow {
        configKey: "island.showTray"
        label: "Tray pod"
        description: "Right of the island. Collapses when the tray is empty."
        checked: Config.island.showTray
        onToggled: function(v) { Config.island.showTray = v }
    }

    ToggleRow {
        configKey: "island.podPeek"
        advanced: true
        label: "Peek on change"
        description: "A pod opens for a moment when what it shows changes."
        checked: Config.island.podPeek
        onToggled: function(v) { Config.island.podPeek = v }
    }

    SliderRow {
        configKey: "island.trayRestMax"
        advanced: true
        label: "Tray icons at rest"
        description: "The rest wait behind a count until it opens."
        from: 1; to: 8; stepSize: 1
        value: Config.island.trayRestMax
        onMoved: function(v) { Config.island.trayRestMax = v }
    }

    ChoiceRow {
        configKey: "island.scrollAction"
        label: "Scroll over the island"
        description: "An OSD on screen always takes the gesture instead."
        current: Config.island.scrollAction
        options: [
            { value: "workspace", label: "Workspace" },
            { value: "volume",    label: "Volume" },
            { value: "none",      label: "Nothing" }
        ]
        onSelected: function(v) { Config.island.scrollAction = v }
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
        description: "Below 1.0 the wallpaper shows through, blurred."
        from: 0.5; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.island.opacity
        onMoved: function(v) { Config.island.opacity = v }
    }

    SliderRow {
        configKey: "island.padding"
        advanced: true
        label: "Padding"
        description: "Space inside the pill."
        from: 8; to: 40; stepSize: 1; suffix: " px"
        value: Config.island.padding
        onMoved: function(v) { Config.island.padding = v }
    }

    SliderRow {
        configKey: "island.fontSize"
        advanced: true
        label: "Font size"
        from: 9; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.fontSize
        onMoved: function(v) { Config.island.fontSize = v }
    }

    Disclosure {
        width: parent.width
        advanced: true
        text: "Geometry"
        hint: "widths and margins"

        SliderRow {
            configKey: "island.topMargin"
            label: "Top margin"
            from: 0; to: 40; stepSize: 1; suffix: " px"
            value: Config.island.topMargin
            onMoved: function(v) { Config.island.topMargin = v }
        }

        SliderRow {
            configKey: "island.podGap"
            label: "Pod gap"
            description: "Space between a pod and the pill."
            from: 0; to: 24; stepSize: 1; suffix: " px"
            value: Config.island.podGap
            onMoved: function(v) { Config.island.podGap = v }
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
            configKey: "island.searchWidth"
            label: "Launcher width"
            from: 380; to: 900; stepSize: 10; suffix: " px"
            value: Config.island.searchWidth
            onMoved: function(v) { Config.island.searchWidth = v }
        }

        SliderRow {
            configKey: "island.searchMaxRows"
            label: "Launcher results"
            description: "How many matches it grows to show."
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

    }

    Disclosure {
        width: parent.width
        advanced: true
        text: "Timing"
        hint: "hover, collapse, notifications"

        SliderRow {
            configKey: "island.hoverGrace"
            label: "Hover grace"
            description: "How long it stays out after the cursor leaves."
            from: 0; to: 1200; stepSize: 50; suffix: " ms"
            value: Config.island.hoverGrace
            onMoved: function(v) { Config.island.hoverGrace = v }
        }

        SliderRow {
            configKey: "island.collapseDelay"
            label: "Collapse delay"
            description: "0 keeps the control centre open until you click"
                + " again."
            from: 0; to: 2000; stepSize: 50; suffix: " ms"
            value: Config.island.collapseDelay
            onMoved: function(v) { Config.island.collapseDelay = v }
        }

        SliderRow {
            configKey: "island.revealZone"
            label: "Reveal zone"
            description: "The strip at the top edge that brings it back."
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

    }

    Disclosure {
        width: parent.width
        text: "Media"
        hint: "3 settings"

        ToggleRow {
            configKey: "island.pillTitle"
            label: "Track title in the pill"
            description: "Off, a playing track is three bars beside the date."
            checked: Config.island.pillTitle
            onToggled: function(v) { Config.island.pillTitle = v }
        }

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

    SectionHeader { text: "Motion" }

    ChoiceRow {
        label: "Tempo"
        // Eleven numbers, three answers. Tempo writes all eleven; the
        // two rows below are the ones you can feel without a
        // stopwatch, and the other nine are settings.json only.
        // Moving any of them puts this row on "Custom", which is how
        // you can tell from here that one has been moved.
        description: "Fluid is Dynamite V3's spring. Springy trades damping"
            + " for it."
        current: Motion.tempo
        options: Motion.tempo === "custom"
            ? [{ value: "fluid",   label: "Fluid" },
               { value: "calm",    label: "Calm" },
               { value: "springy", label: "Springy" },
               { value: "custom",  label: "Custom" }]
            : [{ value: "fluid",   label: "Fluid" },
               { value: "calm",    label: "Calm" },
               { value: "springy", label: "Springy" }]
        // "custom" is not a tempo you can pick, only one you can be
        // in, so setTempo ignores it rather than this having to.
        onSelected: function(v) { Motion.setTempo(v) }
    }

    ToggleRow {
        configKey: "motion.reduceMotion"
        label: "Reduce motion"
        description: "Drops the springs and the morphs, keeps the cross-fades."
        checked: Config.motion.reduceMotion
        onToggled: function(v) { Config.motion.reduceMotion = v }
    }

    SliderRow {
        configKey: "motion.expandDuration"
        advanced: true
        label: "Open"
        description: "How long the shape takes to arrive."
        from: 160; to: 900; stepSize: 10; suffix: " ms"
        value: Config.motion.expandDuration
        onMoved: function(v) { Config.motion.expandDuration = v }
    }

    SliderRow {
        configKey: "motion.collapseDuration"
        advanced: true
        label: "Close"
        description: "Shorter than opening, and without the spring."
        from: 120; to: 600; stepSize: 10; suffix: " ms"
        value: Config.motion.collapseDuration
        onMoved: function(v) { Config.motion.collapseDuration = v }
    }
}
