import QtQuick
import "root:/Services"
import "root:/Widgets"

// Mouse, touchpad and keyboard. Everything here is pushed to Hyprland
// at runtime via Services/Compositor.qml, so changes apply as you move
// the slider rather than on reload.

Column {
    spacing: 4

    SectionHeader { text: "Mouse" }

    ChoiceRow {
        label: "Acceleration"
        description: "Flat is 1:1 — the pointer moves exactly as far as the mouse. Adaptive speeds up as you move faster."
        current: Config.input.mouseAccel
        options: [
            { value: "flat",     label: "Flat" },
            { value: "adaptive", label: "Adaptive" }
        ]
        onSelected: function(v) { Config.input.mouseAccel = v }
    }

    SliderRow {
        label: "Speed"
        description: "0 is the driver's own rate. Negative is slower, positive faster."
        from: -1.0; to: 1.0; stepSize: 0.05; decimals: 2
        value: Config.input.mouseSensitivity
        onMoved: function(v) { Config.input.mouseSensitivity = v }
    }

    ToggleRow {
        label: "Natural scrolling"
        description: "Content follows the wheel rather than the scrollbar."
        checked: Config.input.naturalScrollMouse
        onToggled: function(v) { Config.input.naturalScrollMouse = v }
    }

    SectionHeader { text: "Touchpad" }

    ChoiceRow {
        label: "Acceleration"
        description: "Hyprland applies one acceleration profile to all pointers, so this and the mouse setting above follow whichever you changed last."
        current: Config.input.touchpadAccel
        options: [
            { value: "flat",     label: "Flat" },
            { value: "adaptive", label: "Adaptive" }
        ]
        onSelected: function(v) {
            Config.input.touchpadAccel = v;
            Config.input.mouseAccel = v;
        }
    }

    SliderRow {
        label: "Pointer speed"
        description: "How far the cursor travels per unit of finger movement."
        from: -1.0; to: 1.0; stepSize: 0.05; decimals: 2
        value: Config.input.touchpadSensitivity
        onMoved: function(v) {
            Config.input.touchpadSensitivity = v;
            Config.input.mouseSensitivity = v;
        }
    }

    ToggleRow {
        label: "Tap to click"
        checked: Config.input.tapToClick
        onToggled: function(v) { Config.input.tapToClick = v }
    }

    ToggleRow {
        label: "Natural scrolling"
        checked: Config.input.naturalScroll
        onToggled: function(v) { Config.input.naturalScroll = v }
    }

    ToggleRow {
        label: "Drag lock"
        description: "Keeps a drag alive if your finger lifts briefly."
        checked: Config.input.dragLock
        onToggled: function(v) { Config.input.dragLock = v }
    }

    ToggleRow {
        label: "Disable while typing"
        description: "Ignores the touchpad for a moment after a keystroke, so your palm doesn't move the cursor."
        checked: Config.input.disableWhileTyping
        onToggled: function(v) { Config.input.disableWhileTyping = v }
    }

    SliderRow {
        label: "Scroll speed"
        from: 0.1; to: 2.0; stepSize: 0.05; decimals: 2
        value: Config.input.scrollFactor
        onMoved: function(v) { Config.input.scrollFactor = v }
    }

    SectionHeader { text: "Keyboard" }

    SliderRow {
        label: "Repeat rate"
        description: "Characters per second once a key starts repeating."
        from: 10; to: 60; stepSize: 1; suffix: "/s"
        value: Config.input.repeatRate
        onMoved: function(v) { Config.input.repeatRate = v }
    }

    SliderRow {
        label: "Repeat delay"
        description: "How long a key is held before it starts repeating."
        from: 150; to: 1000; stepSize: 25; suffix: " ms"
        value: Config.input.repeatDelay
        onMoved: function(v) { Config.input.repeatDelay = v }
    }

    SectionHeader { text: "Cursor" }

    SliderRow {
        label: "Size"
        from: 16; to: 48; stepSize: 4; suffix: " px"
        value: Config.appearance.cursorSize
        onMoved: function(v) { Config.appearance.cursorSize = v }
    }
}
