import QtQuick
import Quickshell
import "root:/Services"
import "root:/Widgets"

// Everything that decides what the desktop looks like, in the order
// it actually happens: pick a wallpaper, pick how the palette is
// derived from it, see the palette, then say what it gets applied to.
//
// This used to be two pages — Wallpaper and Appearance — with the
// wallpaper grid at the bottom of one and the themes it drives at the
// top of the other, and nothing anywhere showing a colour. Choosing a
// scheme meant picking between four words and then leaving to find out
// what they did.

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
        description: "Which screen the wallpaper below is set on."
        visible: Screens.multi && Config.wallpaper.perMonitor
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

    SectionHeader { text: "Palette" }

    ChoiceRow {
        configKey: "wallpaper.scheme"
        label: "Derived as"
        description: "How far the palette is allowed to stray from the"
            + " wallpaper's own colours. The swatches below update as"
            + " soon as matugen has run."
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
                  + " Hyprland's window borders together."
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

    SectionHeader { text: "Applied to"; section: "appearance" }

    SelectRow {
        configKey: "appearance.gtkTheme"
        label: "GTK theme"
        description: "The palette is layered on top of whichever theme"
            + " you pick, so either adw-gtk3 variant works."
        options: Theming.gtkThemes
        current: Config.appearance.gtkTheme
        onSelected: function(v) { Config.appearance.gtkTheme = v }
    }

    SelectRow {
        configKey: "appearance.iconTheme"
        label: "Icons"
        description: "Applied to GTK, Qt and the shell together."
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

    SectionHeader { text: "Panels" }

    SliderRow {
        configKey: "appearance.panelOpacity"
        label: "Panel opacity"
        description: "Below 1.0 the desktop shows through and the"
            + " compositor blurs it."
        from: 0.4; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.appearance.panelOpacity
        onMoved: function(v) { Config.appearance.panelOpacity = v }
    }

    SliderRow {
        configKey: "appearance.panelRadius"
        label: "Panel radius"
        description: "Shapes this window, the control centre, the"
            + " launcher and every card, row and button in them."
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.panelRadius
        onMoved: function(v) { Config.appearance.panelRadius = v }
    }

    SliderRow {
        configKey: "appearance.panelScrim"
        label: "Backdrop dim"
        description: "How far the desktop darkens behind this window."
        from: 0.0; to: 0.8; stepSize: 0.05; decimals: 2
        value: Config.appearance.panelScrim
        onMoved: function(v) { Config.appearance.panelScrim = v }
    }

    Disclosure {
        width: parent.width
        text: "Wallpaper behaviour"
        hint: Screens.multi ? "4 settings" : "3 settings"

        ToggleRow {
            configKey: "wallpaper.perMonitor"
            label: "One per monitor"
            description: "Give each screen its own wallpaper. The"
                + " palette still comes from the focused screen's —"
                + " there is one GTK theme and one set of window"
                + " borders to drive."
            visible: Screens.multi
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
            description: "0 disables automatic rotation."
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
}
