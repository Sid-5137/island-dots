import QtQuick
import "root:/Services"
import "root:/Widgets"

// Idle and lock. The timings here are written to hypridle.conf and the
// daemon restarted, so this is the only place they're set.

Column {
    spacing: 4

    SectionHeader { text: "Idle"; section: "idle" }

    ToggleRow {
        configKey: "idle.enabled"
        label: "Idle actions"
        description: "Dim, lock, blank and suspend after inactivity."
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
        configKey: "idle.dimLevel"
        label: "Dim level"
        from: 1; to: 50; stepSize: 1; suffix: "%"
        value: Config.idle.dimLevel
        onMoved: function(v) { Config.idle.dimLevel = v }
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

    SectionHeader { text: "Lock" }

    Item {
        width: parent.width
        height: 56

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: pamValue.left
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
                text: "A file under /etc/pam.d. A dedicated one lets a fingerprint reader work here without enabling it for tty logins."
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: pamValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Config.island.pamConfig
            color: Theme.primary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }
    }

    Item {
        width: parent.width
        height: 48

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 110
            text: "Test the lock before relying on it. If PAM rejects a correct password you will need a TTY to recover."
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            height: 32
            radius: 8
            color: lockHover.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer
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
}
