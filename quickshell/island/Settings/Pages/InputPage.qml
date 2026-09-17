import QtQuick
import "root:/Services"
import "root:/Widgets"

// Mouse, touchpad and keyboard. Pointer settings are applied per
// device via hl.device(), so the two pointers are independent.

Column {
    spacing: 4

    SectionHeader { text: "Mouse"; section: "input" }

    Item {
        width: parent.width
        height: 34
        visible: !Devices.hasMouse

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "No mouse detected. These apply when one is connected."
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }
    }

    ChoiceRow {
        configKey: "input.mouseAccel"
        advanced: true
        label: "Acceleration"
        description: "Flat is 1:1. Adaptive speeds up as you move faster."
        current: Config.input.mouseAccel
        options: [
            { value: "flat",     label: "Flat" },
            { value: "adaptive", label: "Adaptive" }
        ]
        onSelected: function(v) { Config.input.mouseAccel = v }
    }

    SliderRow {
        configKey: "input.mouseSensitivity"
        label: "Speed"
        description: "0 is the driver's own rate."
        from: -1.0; to: 1.0; stepSize: 0.05; decimals: 2
        value: Config.input.mouseSensitivity
        onMoved: function(v) { Config.input.mouseSensitivity = v }
    }

    ToggleRow {
        configKey: "input.naturalScrollMouse"
        label: "Natural scrolling"
        checked: Config.input.naturalScrollMouse
        onToggled: function(v) { Config.input.naturalScrollMouse = v }
    }

    SectionHeader { text: "Touchpad" }

    ToggleRow {
        configKey: "input.touchpadEnabled"
        label: "Touchpad"
        description: Devices.hasTouchpad
            ? Devices.touchpads[0]
            : "None detected"
        checked: Config.input.touchpadEnabled
        onToggled: function(v) { Config.input.touchpadEnabled = v }
    }

    ChoiceRow {
        configKey: "input.touchpadAccel"
        advanced: true
        label: "Acceleration"
        description: "Independent of the mouse above."
        current: Config.input.touchpadAccel
        options: [
            { value: "flat",     label: "Flat" },
            { value: "adaptive", label: "Adaptive" }
        ]
        onSelected: function(v) { Config.input.touchpadAccel = v }
    }

    SliderRow {
        configKey: "input.touchpadSensitivity"
        label: "Speed"
        from: -1.0; to: 1.0; stepSize: 0.05; decimals: 2
        value: Config.input.touchpadSensitivity
        onMoved: function(v) { Config.input.touchpadSensitivity = v }
    }

    ToggleRow {
        configKey: "input.tapToClick"
        label: "Tap to click"
        checked: Config.input.tapToClick
        onToggled: function(v) { Config.input.tapToClick = v }
    }

    ToggleRow {
        configKey: "input.naturalScroll"
        label: "Natural scrolling"
        checked: Config.input.naturalScroll
        onToggled: function(v) { Config.input.naturalScroll = v }
    }

    ToggleRow {
        configKey: "input.dragLock"
        advanced: true
        label: "Drag lock"
        description: "Keeps a drag alive if your finger lifts."
        checked: Config.input.dragLock
        onToggled: function(v) { Config.input.dragLock = v }
    }

    ToggleRow {
        configKey: "input.disableWhileTyping"
        label: "Disable while typing"
        description: "Ignores the touchpad just after a keystroke."
        checked: Config.input.disableWhileTyping
        onToggled: function(v) { Config.input.disableWhileTyping = v }
    }

    SliderRow {
        configKey: "input.scrollFactor"
        advanced: true
        label: "Scroll speed"
        description: "Also how far a two-finger scroll moves."
        from: 0.1; to: 3.0; stepSize: 0.05; decimals: 2
        value: Config.input.scrollFactor
        onMoved: function(v) { Config.input.scrollFactor = v }
    }

    SectionHeader { text: "Keyboard"; advanced: true }

    SliderRow {
        configKey: "input.repeatRate"
        advanced: true
        label: "Repeat rate"
        description: "Characters per second while a key repeats."
        from: 10; to: 60; stepSize: 1; suffix: "/s"
        value: Config.input.repeatRate
        onMoved: function(v) { Config.input.repeatRate = v }
    }

    SliderRow {
        configKey: "input.repeatDelay"
        advanced: true
        label: "Repeat delay"
        from: 150; to: 1000; stepSize: 25; suffix: " ms"
        value: Config.input.repeatDelay
        onMoved: function(v) { Config.input.repeatDelay = v }
    }

    SectionHeader { text: "Detected" }

    Item {
        width: parent.width
        height: devList.implicitHeight + 16

        Text {
            id: devList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Touchpads: " + (Devices.touchpads.join(", ") || "none")
                + "\nMice: " + (Devices.mice.join(", ") || "none")
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall - 1
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }
}
