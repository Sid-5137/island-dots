import QtQuick
import "root:/Services"
import "root:/Widgets"

Column {
    spacing: 4

    SectionHeader { text: "Morph"; section: "motion" }

    SliderRow {
        configKey: "motion.morphDuration"
        label: "Duration"
        description: "How long the island takes to change shape."
        from: 100; to: 800; stepSize: 10; suffix: " ms"
        value: Config.motion.morphDuration
        onMoved: function(v) { Config.motion.morphDuration = v }
    }

    SliderRow {
        configKey: "motion.morphOvershoot"
        label: "Overshoot"
        description: "How far the shape springs past its target. 0 is a flat decelerate."
        from: 0; to: 2; stepSize: 0.05; decimals: 2
        value: Config.motion.morphOvershoot
        onMoved: function(v) { Config.motion.morphOvershoot = v }
    }

    SectionHeader { text: "Content" }

    SliderRow {
        configKey: "motion.fadeIn"
        label: "Fade in"
        from: 40; to: 400; stepSize: 10; suffix: " ms"
        value: Config.motion.fadeIn
        onMoved: function(v) { Config.motion.fadeIn = v }
    }

    SliderRow {
        configKey: "motion.fadeOut"
        label: "Fade out"
        from: 20; to: 300; stepSize: 10; suffix: " ms"
        value: Config.motion.fadeOut
        onMoved: function(v) { Config.motion.fadeOut = v }
    }

    SliderRow {
        configKey: "motion.contentThreshold"
        label: "Reveal threshold"
        description: "How far the pill must grow before its contents appear. Higher means the shape leads more."
        from: 0.3; to: 1.0; stepSize: 0.05; decimals: 2
        value: Config.motion.contentThreshold
        onMoved: function(v) { Config.motion.contentThreshold = v }
    }

    SectionHeader { text: "Preview" }

    Item {
        width: parent.width
        height: 70

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Hover to test"
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }

        // A miniature of the island using the same curves, so you can
        // feel a change without reaching for the real one.
        Rectangle {
            id: demo
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: demoHover.containsMouse ? 200 : 90
            height: demoHover.containsMouse ? 48 : 28
            radius: Config.island.radius
            color: demoHover.containsMouse ? Theme.surfaceContainer : Theme.surfaceLowest
            border.width: 1
            border.color: Theme.outlineVariant
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Config.motion.morphDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: Config.motion.morphOvershoot
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Config.motion.morphDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: Config.motion.morphOvershoot
                }
            }
            Behavior on color { ColorAnimation { duration: Config.motion.morphDuration } }

            Text {
                anchors.centerIn: parent
                text: demoHover.containsMouse ? "expanded" : "idle"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                opacity: demo.height > 40 || !demoHover.containsMouse ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Config.motion.fadeIn }
                }
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: demoHover
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }
}
