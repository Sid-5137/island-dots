import QtQuick
import "root:/Services"
import "root:/Widgets"

// The machine rather than the desktop: how loud, when it sleeps, how
// it unlocks, and the way back to the shipped defaults. Anything about
// how the desktop LOOKS is on Appearance.
//
// The volume scale is here rather than with the control centre because
// the OSD, media keys and gestures all read it. Idle is applied by
// regenerating hypridle's config and restarting it.

Column {
    id: page
    spacing: 4

    SectionHeader { text: "Sound"; section: "audio";
                    advanced: true }

    ChoiceRow {
        configKey: "audio.volumeCurve"
        advanced: true
        label: "Volume scale"
        description: "System matches wpctl; perceptual remaps the curve."
        current: Config.audio.volumeCurve
        options: [
            { value: "system",     label: "System" },
            { value: "perceptual", label: "Perceptual" }
        ]
        onSelected: function(v) { Config.audio.volumeCurve = v }
    }

    Item {
        width: parent.width
        height: curveNote.implicitHeight + 16
        visible: Config.ui.advanced

        Text {
            id: curveNote
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            // The numbers, because the difference is not a matter of
            // taste and a sentence about loudness curves is not
            // something anyone should have to take on trust.
            text: Audio.perceptual
                ? "The slider now reads " + Audio.volume + "% where every"
                : "PipeWire applies the cube of this number, so 50% is"

            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

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
        description: "A warning before the rest. 0 to skip."
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

        Button {
            id: lockBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 32
            text: "Lock now"
            onClicked: Lock.lock()
        }
    }

    // Fingerprint unlock needs four separate things to line up and
    // each fails silently on its own, so the page says which one is
    // missing rather than leaving a reader that does nothing.
    ChoiceRow {
        configKey: "island.pamConfig"
        advanced: true
        label: "PAM file"
        description: Biometric.pamFile
            ? "island adds the fingerprint reader; login is password only."
            : "Only login is installed. Re-run install.sh for the other."
        current: Config.island.pamConfig
        options: [
            { value: "login",  label: "login" },
            { value: "island", label: "island" }
        ]
        onSelected: function(v) { Config.island.pamConfig = v }
    }

    Item {
        width: parent.width
        height: 44

        Text {
            id: fpState
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            text: Biometric.ready
                ? "Fingerprint unlock is ready."
                : "Fingerprint: " + Biometric.advice
            color: Biometric.ready ? Theme.primary : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Recheck"
            color: fpHover.containsMouse ? Theme.primary : Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            MouseArea {
                id: fpHover
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Biometric.refresh()
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

        // 118px wide, before, because that is what "Reset all"
        // needed once it had turned into "Confirm" and back. A chip
        // that measures its own label does not need anybody to have
        // worked that out.
        Button {
            id: resetAll
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 32

            // Two presses. A reset is not undoable.
            property bool confirming: false

            text: confirming ? "Confirm" : "Reset all"
            kind: confirming ? "danger" : "plain"

            Timer {
                id: allArmed
                interval: 2500
                onTriggered: resetAll.confirming = false
            }

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
