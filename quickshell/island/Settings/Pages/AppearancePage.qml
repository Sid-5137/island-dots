import QtQuick
import Quickshell
import "root:/Services"
import "root:/Widgets"

// Everything that decides what the desktop looks like, in the order it
// happens: pick a wallpaper, pick how the palette derives from it, see
// the palette, then shape the surfaces it lands on.
//
// Window and panel rounding live here together rather than a page
// apart, under one control that moves them with the pill.

Column {
    id: page
    spacing: 4

    // Which screen the wallpaper grid assigns to. Reset whenever
    // per-monitor is turned off, so a stale target cannot make a click
    // appear to do nothing.
    property string target: ""

    Connections {
        target: Config.wallpaper
        function onPerMonitorChanged() {
            if (!Config.wallpaper.perMonitor) page.target = "";
        }
    }

    SectionHeader { text: "Wallpaper"; section: "wallpaper" }

    // Only worth showing with somewhere to send it. On one monitor
    // there is nothing to choose between.
    ChoiceRow {
        label: "Applies to"
        description: "Which screen this wallpaper is for."
        shown: Screens.multi && Config.wallpaper.perMonitor
        height: visible ? implicitHeight : 0
        current: page.target
        options: [{ value: "", label: "All" }].concat(
            Quickshell.screens.map(s => ({ value: s.name, label: s.name })))
        onSelected: function(v) { page.target = v }
    }

    WallpaperGrid {
        width: parent.width
        columns: 4
        maxRows: 2
        targetScreen: page.target
    }

    // Only shown when there is something to say. A note about image
    // codecs on a machine that has them all is noise.
    Item {
        width: parent.width
        height: visible ? 40 : 0
        visible: Wallpaper.unsupported > 0

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Wallpaper.unsupported + " file"
                + (Wallpaper.unsupported === 1 ? " is" : "s are")
                + " not shown: this Qt build has no decoder for them."
                + " Install qt6-qtimageformats for WebP, AVIF and JPEG XL."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

    Disclosure {
        width: parent.width
        text: "Wallpaper behaviour"
        hint: Screens.multi ? "4 settings" : "3 settings"

        ToggleRow {
            configKey: "wallpaper.perMonitor"
            label: "One per monitor"
            description: "Each screen its own. The palette follows the focused"
                + " one."
            shown: Screens.multi
            height: visible ? implicitHeight : 0
            checked: Config.wallpaper.perMonitor
            onToggled: function(v) { Config.wallpaper.perMonitor = v }
        }

        SliderRow {
            configKey: "wallpaper.crossfadeDuration"
            label: "Crossfade"
            from: 0; to: 2000; stepSize: 50; suffix: " ms"
            value: Config.wallpaper.crossfadeDuration
            onMoved: function(v) { Config.wallpaper.crossfadeDuration = v }
        }

        SliderRow {
            configKey: "wallpaper.rotateMinutes"
            label: "Rotate every"
            description: "0 turns rotation off."
            from: 0; to: 120; stepSize: 5; suffix: " min"
            value: Config.wallpaper.rotateMinutes
            onMoved: function(v) { Config.wallpaper.rotateMinutes = v }
        }

        Item {
            width: parent.width
            height: 52

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 2

                Text {
                    text: "Source directory"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    text: Config.wallpaper.directory
                        + "  ·  " + Wallpaper.list.length + " usable"
                    color: Theme.outline
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideMiddle
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    SectionHeader { text: "Palette" }

    ChoiceRow {
        configKey: "wallpaper.scheme"
        label: "Derived as"
        description: "How far the palette may stray from the wallpaper."
        current: Config.wallpaper.scheme
        options: [
            { value: "scheme-monochrome", label: "Mono" },
            { value: "scheme-neutral",    label: "Neutral" },
            { value: "scheme-tonal-spot", label: "Tonal" },
            { value: "scheme-vibrant",    label: "Vibrant" },
            { value: "scheme-expressive", label: "Expressive" }
        ]
        onSelected: function(v) {
            Config.wallpaper.scheme = v;
            // Re-derive immediately: the point of the swatches is that
            // the answer arrives without leaving this page.
            if (Wallpaper.current !== "") Wallpaper.generate(Wallpaper.current);
        }
    }

    Swatches {
        width: parent.width
        columns: 4
    }

    Item {
        width: parent.width
        height: 44

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 110
            text: Wallpaper.busy
                ? "Deriving the palette…"
                : "These colours drive the shell, GTK3, GTK4 and"
            color: Wallpaper.busy ? Theme.primary : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Regenerate"
            onClicked: Wallpaper.reapply()
        }
    }

    SectionHeader { text: "Themes"; section: "appearance" }

    SelectRow {
        configKey: "appearance.gtkTheme"
        label: "GTK theme"
        description: "The palette is layered over whichever you pick."
        options: Theming.gtkThemes
        current: Config.appearance.gtkTheme
        onSelected: function(v) { Config.appearance.gtkTheme = v }
    }

    SelectRow {
        configKey: "appearance.iconTheme"
        label: "Icons"
        description: "GTK, Qt and the shell together."
        options: Theming.available
        current: Config.appearance.iconTheme
        onSelected: function(v) { Config.appearance.iconTheme = v }
    }

    SelectRow {
        configKey: "appearance.cursorTheme"
        label: "Cursor"
        options: Theming.cursors
        current: Config.appearance.cursorTheme
        onSelected: function(v) { Config.appearance.cursorTheme = v }
    }

    SliderRow {
        configKey: "appearance.cursorSize"
        label: "Cursor size"
        from: 16; to: 48; stepSize: 4; suffix: " px"
        value: Config.appearance.cursorSize
        onMoved: function(v) { Config.appearance.cursorSize = v }
    }

    // Fonts sit with the themes rather than in a section of their
    // own: this is the same question the three rows above it ask —
    // what the palette gets applied to — and a typeface is not a
    // different kind of answer from an icon set.
    SectionHeader { text: "Fonts" }

    SelectRow {
        configKey: "appearance.fontFamily"
        label: "Interface"
        description: "Windows and panels, and the GTK and Qt apps on the"
            + " rest of the desktop. Any family — the icons no longer"
            + " come out of this one."
        options: Theming.fonts
        current: Config.appearance.fontFamily
        onSelected: function(v) { Config.appearance.fontFamily = v }
    }

    SelectRow {
        configKey: "appearance.fontIsland"
        label: "Island"
        description: "The pill and the control centre. Monospace keeps"
            + " the clock from changing width as the time changes."
        options: Theming.fonts
        current: Config.appearance.fontIsland
        onSelected: function(v) { Config.appearance.fontIsland = v }
    }

    SelectRow {
        configKey: "appearance.fontMono"
        label: "Monospace"
        description: "Clipboard entries, workspace numbers, the password"
            + " field and the value beside a slider."
        options: Theming.monoFonts
        current: Config.appearance.fontMono
        onSelected: function(v) { Config.appearance.fontMono = v }
    }

    SelectRow {
        configKey: "appearance.fontIcons"
        label: "Icons"
        // Says why this list is short before the shortness reads as a
        // missing font.
        description: "Only fonts carrying the shell's icon glyphs are"
            + " listed — they are codepoints, not images. A font without"
            + " them draws boxes."
        options: Theming.iconFonts
        current: Config.appearance.fontIcons
        onSelected: function(v) { Config.appearance.fontIcons = v }
    }

    SectionHeader { text: "Corners" }

    CornerPreview { width: parent.width }

    ToggleRow {
        configKey: "appearance.radiusLink"
        label: "Match everything"
        description: "One corner for the pill, the panels and your windows."
        checked: Config.appearance.radiusLink
        onToggled: function(v) { Config.setRadiusLink(v) }
    }

    // One slider or three, never both: a master that stays visible
    // beside the values it drives is a control that looks like it
    // disagrees with them.
    SliderRow {
        configKey: "appearance.panelRadius"
        label: "Corner radius"
        description: "Panels, cards and window corners."
        shown: Config.appearance.radiusLink
        height: visible ? implicitHeight : 0
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.panelRadius
        onMoved: function(v) { Config.setRadius(v) }
    }

    SliderRow {
        configKey: "island.radius"
        label: "Island"
        description: "The pill's own corner."
        shown: !Config.appearance.radiusLink
        height: visible ? implicitHeight : 0
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.island.radius
        onMoved: function(v) { Config.island.radius = v }
    }

    SliderRow {
        configKey: "appearance.panelRadius"
        label: "Panels"
        description: "This window, the control centre and the launcher."
        shown: !Config.appearance.radiusLink
        height: visible ? implicitHeight : 0
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.panelRadius
        onMoved: function(v) { Config.appearance.panelRadius = v }
    }

    SliderRow {
        configKey: "appearance.windowRounding"
        label: "Windows"
        shown: !Config.appearance.radiusLink
        height: visible ? implicitHeight : 0
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.appearance.windowRounding
        onMoved: function(v) { Config.appearance.windowRounding = v }
    }

    // How the corner is drawn, next to how big it is. It reaches the
    // pill, the panels and your windows together: Hyprland takes it as
    // decoration:rounding_power and packages/qml-squircle draws the
    // shell's surfaces from the same number.
    SliderRow {
        configKey: "appearance.cornerSmoothing"
        advanced: true
        label: "Smoothing"
        description: "2.0 is a circular corner; 4.0 is roughly macOS."
        from: 2.0; to: 8.0; stepSize: 0.5; decimals: 1
        value: Config.appearance.cornerSmoothing
        onMoved: function(v) { Config.appearance.cornerSmoothing = v }
    }

    SectionHeader { text: "Panels" }

    SliderRow {
        configKey: "appearance.panelOpacity"
        label: "Panel opacity"
        description: "Below 1.0 the desktop shows through, blurred."
        from: 0.4; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.appearance.panelOpacity
        onMoved: function(v) { Config.appearance.panelOpacity = v }
    }

    SliderRow {
        configKey: "appearance.panelScrim"
        advanced: true
        label: "Backdrop dim"
        description: "How far the desktop darkens behind it."
        from: 0.0; to: 0.8; stepSize: 0.05; decimals: 2
        value: Config.appearance.panelScrim
        onMoved: function(v) { Config.appearance.panelScrim = v }
    }

    SectionHeader { text: "Windows" }

    GapsPreview { width: parent.width }

    SliderRow {
        configKey: "appearance.gapsIn"
        label: "Inner gaps"
        description: "Between tiled windows."
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.gapsIn
        onMoved: function(v) { Config.appearance.gapsIn = v }
    }

    SliderRow {
        configKey: "appearance.gapsOut"
        label: "Outer gaps"
        description: "Between the tiling area and the screen."
        from: 0; to: 48; stepSize: 1; suffix: " px"
        value: Config.appearance.gapsOut
        onMoved: function(v) { Config.appearance.gapsOut = v }
    }

    SliderRow {
        configKey: "appearance.inactiveOpacity"
        advanced: true
        label: "Inactive opacity"
        description: "How far unfocused windows fade back."
        from: 0.6; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.appearance.inactiveOpacity
        onMoved: function(v) { Config.appearance.inactiveOpacity = v }
    }

    ToggleRow {
        configKey: "appearance.shadows"
        label: "Window shadows"
        checked: Config.appearance.shadows
        onToggled: function(v) { Config.appearance.shadows = v }
    }

    Disclosure {
        width: parent.width
        text: "Blur"
        hint: "behind panels and translucent windows"

        BlurPreview { width: parent.width }

        SliderRow {
            configKey: "appearance.blurSize"
            label: "Size"
            description: "Windows, and everything drawn translucently."
            from: 1; to: 20; stepSize: 1
            value: Config.appearance.blurSize
            onMoved: function(v) { Config.appearance.blurSize = v }
        }

        SliderRow {
            configKey: "appearance.blurPasses"
            label: "Passes"
            description: "Smoother, and more GPU. 3 is a good default."
            from: 1; to: 5; stepSize: 1
            value: Config.appearance.blurPasses
            onMoved: function(v) { Config.appearance.blurPasses = v }
        }

        ToggleRow {
            configKey: "appearance.blurOptimize"
            label: "Cache the blur"
            description: "Off, it is recomputed every frame."
            checked: Config.appearance.blurOptimize
            onToggled: function(v) { Config.appearance.blurOptimize = v }
        }

        SliderRow {
            configKey: "appearance.blurBrightness"
            label: "Brightness"
            from: 0.5; to: 1.2; stepSize: 0.05; decimals: 2
            value: Config.appearance.blurBrightness
            onMoved: function(v) { Config.appearance.blurBrightness = v }
        }

        SliderRow {
            configKey: "appearance.blurContrast"
            label: "Contrast"
            from: 0.5; to: 1.5; stepSize: 0.05; decimals: 2
            value: Config.appearance.blurContrast
            onMoved: function(v) { Config.appearance.blurContrast = v }
        }

        SliderRow {
            configKey: "appearance.borderSize"
            label: "Border size"
            description: "In the palette's own colours."
            from: 0; to: 6; stepSize: 1; suffix: " px"
            value: Config.appearance.borderSize
            onMoved: function(v) { Config.appearance.borderSize = v }
        }
    }

    // Came over from System with the sliders above it. A full
    // `hyprctl reload` re-reads look.lua and puts every one of them
    // back to the checked-in default, so there has to be a way to
    // send them again that is not "move a slider and move it back".
    Item {
        width: parent.width
        height: 44

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            text: "Window and blur settings are applied to Hyprland as"
                + " you move a slider, and not written to look.lua —"
                + " that stays the checked-in default."
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Reapply"
            onClicked: Compositor.apply()
        }
    }
}
