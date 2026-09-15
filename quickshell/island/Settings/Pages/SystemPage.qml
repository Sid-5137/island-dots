import QtQuick
import "root:/Services"
import "root:/Widgets"

// What the compositor does with windows, and what happens when you
// stop using the machine.
//
// These were two pages, Appearance and Session, split along the lines
// of which config section a value happens to live in rather than what
// it does. Window rounding and idle timeouts have nothing in common
// with each other but both are "the system", and neither belongs next
// to a colour scheme.
//
// Everything on this page is applied to Hyprland live, and to hypridle
// by regenerating its config and restarting it.

Column {
    id: page
    spacing: 4

    SectionHeader { text: "Windows"; section: "appearance" }

    SliderRow {
        configKey: "appearance.windowRounding"
        label: "Corner radius"
        from: 0; to: 24; stepSize: 1; suffix: " px"
        value: Config.appearance.windowRounding
        onMoved: function(v) { Config.appearance.windowRounding = v }
    }

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
        description: "Between the tiling area and the screen edge."
        from: 0; to: 48; stepSize: 1; suffix: " px"
        value: Config.appearance.gapsOut
        onMoved: function(v) { Config.appearance.gapsOut = v }
    }

    SliderRow {
        configKey: "appearance.inactiveOpacity"
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

    SectionHeader { text: "Blur" }

    SliderRow {
        configKey: "appearance.blurSize"
        label: "Size"
        description: "Applies to windows and to everything the shell"
            + " draws translucently."
        from: 0; to: 20; stepSize: 1
        value: Config.appearance.blurSize
        onMoved: function(v) { Config.appearance.blurSize = v }
    }

    SliderRow {
        configKey: "appearance.blurPasses"
        label: "Passes"
        description: "Smoother, and more GPU. 3 is a good default."
        from: 1; to: 6; stepSize: 1
        value: Config.appearance.blurPasses
        onMoved: function(v) { Config.appearance.blurPasses = v }
    }

    Disclosure {
        width: parent.width
        text: "Blur tone"
        hint: "brightness, contrast"

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

        SliderRow {
            configKey: "appearance.borderSize"
            label: "Border size"
            from: 0; to: 6; stepSize: 1; suffix: " px"
            value: Config.appearance.borderSize
            onMoved: function(v) { Config.appearance.borderSize = v }
        }
    }

    Item {
        width: parent.width
        height: 44

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            text: "Applied to Hyprland as you move a slider, and not"
                + " written to look.lua — that stays the checked-in"
                + " default."
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
            color: reapplyHover.containsMouse ? Theme.surfaceHigh
                                              : Theme.surfaceContainer
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

    SectionHeader { text: "Idle"; section: "idle" }

    ToggleRow {
        configKey: "idle.enabled"
        label: "Idle actions"
        description: "Dim, lock, blank and suspend after inactivity."
            + " Off stops hypridle entirely."
        checked: Config.idle.enabled
        onToggled: function(v) { Config.idle.enabled = v }
    }

    SliderRow {
        configKey: "idle.dimTimeout"
        label: "Dim after"
        description: "Lowers the backlight as a warning. 0 to skip."
        from: 0; to: 900; stepSize: 30; suffix: " s"
        value: Config.idle.dimTimeout
        onMoved: function(v) { Config.idle.dimTimeout = v }
    }

    SliderRow {
        configKey: "idle.lockTimeout"
        label: "Lock after"
        from: 0; to: 1800; stepSize: 30; suffix: " s"
        value: Config.idle.lockTimeout
        onMoved: function(v) { Config.idle.lockTimeout = v }
    }

    SliderRow {
        configKey: "idle.screenOffTimeout"
        label: "Screen off after"
        from: 0; to: 1800; stepSize: 30; suffix: " s"
        value: Config.idle.screenOffTimeout
        onMoved: function(v) { Config.idle.screenOffTimeout = v }
    }

    SliderRow {
        configKey: "idle.suspendTimeout"
        label: "Suspend after"
        description: "0 never suspends."
        from: 0; to: 7200; stepSize: 300; suffix: " s"
        value: Config.idle.suspendTimeout
        onMoved: function(v) { Config.idle.suspendTimeout = v }
    }

    Disclosure {
        width: parent.width
        text: "Dim level"
        hint: "1 setting"

        SliderRow {
            configKey: "idle.dimLevel"
            label: "Dim to"
            from: 1; to: 50; stepSize: 1; suffix: "%"
            value: Config.idle.dimLevel
            onMoved: function(v) { Config.idle.dimLevel = v }
        }
    }

    SectionHeader { text: "Lock" }

    // The lock screen is a real ext-session-lock surface with PAM
    // behind it. If PAM is misconfigured the only way out is a TTY, so
    // this says so where the button is rather than in a README.
    Item {
        width: parent.width
        height: 58

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: lockBtn.left
            anchors.rightMargin: 16
            spacing: 2

            Text {
                text: "PAM configuration"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: "Authenticating against /etc/pam.d/"
                    + Config.island.pamConfig
                    + ". Test the lock before relying on it: if PAM"
                    + " rejects a correct password you will need a TTY"
                    + " to recover."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            id: lockBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            height: 32
            radius: 8
            color: lockHover.containsMouse ? Theme.surfaceHigh
                                           : Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Lock now"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: lockHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lock.lock()
            }
        }
    }

    SectionHeader { text: "Everything" }

    Item {
        width: parent.width
        height: 54

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 130
            text: "Restore every page to its shipped values. Icon,"
                + " cursor and GTK themes and the wallpaper directory"
                + " are kept, since those describe this machine rather"
                + " than a preference."
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

            // Two presses. A reset is not undoable.
            property bool confirming: false

            color: confirming ? Theme.error
                : (allHover.containsMouse ? Theme.surfaceHigh
                                          : Theme.surfaceContainer)
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
