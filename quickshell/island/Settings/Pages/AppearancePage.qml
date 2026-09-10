import QtQuick
import "root:/Services"
import "root:/Widgets"

Column {
    spacing: 4

    SectionHeader { text: "Themes"; section: "appearance" }

    // Populated from what's actually installed, so this can't offer
    // a theme that doesn't exist.
    SelectRow {
        configKey: "appearance.iconTheme"
        label: "Icons"
        description: "Applied to GTK, Qt and the shell together."
        options: Theming.available
        current: Config.appearance.iconTheme
        onSelected: function(v) { Config.appearance.iconTheme = v }
    }

    SelectRow {
        configKey: "appearance.gtkTheme"
        label: "GTK theme"
        options: Theming.gtkThemes
        current: Config.appearance.gtkTheme
        onSelected: function(v) { Config.appearance.gtkTheme = v }
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
        description: "1.0 is solid. Below that the desktop shows through, which needs the blur layer rule in hypr/rules.lua to look right."
        from: 0.4; to: 1.0; stepSize: 0.02; decimals: 2
        value: Config.appearance.panelOpacity
        onMoved: function(v) { Config.appearance.panelOpacity = v }
    }

    SliderRow {
        configKey: "appearance.panelScrim"
        label: "Backdrop dim"
        description: "How far the desktop darkens behind the settings window."
        from: 0.0; to: 0.8; stepSize: 0.05; decimals: 2
        value: Config.appearance.panelScrim
        onMoved: function(v) { Config.appearance.panelScrim = v }
    }

    SliderRow {
        configKey: "appearance.panelRadius"
        label: "Panel radius"
        description: "Shapes the settings window and the control centre tiles together."
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.panelRadius
        onMoved: function(v) { Config.appearance.panelRadius = v }
    }

    SectionHeader { text: "Blur" }

    SliderRow {
        configKey: "appearance.blurSize"
        label: "Size"
        description: "Blur radius. Applies to windows and shell panels."
        from: 0; to: 20; stepSize: 1
        value: Config.appearance.blurSize
        onMoved: function(v) { Config.appearance.blurSize = v }
    }

    SliderRow {
        configKey: "appearance.blurPasses"
        label: "Passes"
        description: "More passes is smoother but costs GPU. 3 is a good default."
        from: 1; to: 6; stepSize: 1
        value: Config.appearance.blurPasses
        onMoved: function(v) { Config.appearance.blurPasses = v }
    }

    SliderRow {
        configKey: "appearance.blurBrightness"
        label: "Brightness"
        from: 0.3; to: 1.5; stepSize: 0.05; decimals: 2
        value: Config.appearance.blurBrightness
        onMoved: function(v) { Config.appearance.blurBrightness = v }
    }

    SliderRow {
        configKey: "appearance.blurContrast"
        label: "Contrast"
        from: 0.3; to: 2.0; stepSize: 0.05; decimals: 2
        value: Config.appearance.blurContrast
        onMoved: function(v) { Config.appearance.blurContrast = v }
    }

    SectionHeader { text: "Windows" }

    SliderRow {
        configKey: "appearance.windowRounding"
        label: "Corner radius"
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.appearance.windowRounding
        onMoved: function(v) { Config.appearance.windowRounding = v }
    }

    SliderRow {
        configKey: "appearance.borderSize"
        label: "Border size"
        from: 0; to: 6; stepSize: 1; suffix: " px"
        value: Config.appearance.borderSize
        onMoved: function(v) { Config.appearance.borderSize = v }
    }

    SliderRow {
        configKey: "appearance.inactiveOpacity"
        label: "Inactive opacity"
        description: "How much unfocused windows fade back."
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

    SectionHeader { text: "Gaps" }

    SliderRow {
        configKey: "appearance.gapsIn"
        label: "Inner"
        from: 0; to: 32; stepSize: 1; suffix: " px"
        value: Config.appearance.gapsIn
        onMoved: function(v) { Config.appearance.gapsIn = v }
    }

    SliderRow {
        configKey: "appearance.gapsOut"
        label: "Outer"
        from: 0; to: 48; stepSize: 1; suffix: " px"
        value: Config.appearance.gapsOut
        onMoved: function(v) { Config.appearance.gapsOut = v }
    }

    SectionHeader { text: "" }

    Item {
        width: parent.width
        height: 44

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            text: "These apply to Hyprland immediately but aren't written to look.lua — that stays the checked-in default."
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            height: 30
            radius: 8
            color: reapplyHover.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Reapply"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: reapplyHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Compositor.apply()
            }
        }
    }
}
