pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool ready: false

    function apply() {
        if (!ready) return;
        proc.command = ["sh", "-c", buildCommand()];
        proc.running = true;
    }

    function buildLua() {
        const a = Config.appearance;
        const i = Config.input;
        return "hl.config({"
            + "  input = {"
            + "    repeat_rate = "   + i.repeatRate + ","
            + "    repeat_delay = "  + i.repeatDelay + ","
            + "    touchpad = {"
            + "      tap_to_click = "         + (i.tapToClick ? "true" : "false") + ","
            + "      natural_scroll = "       + (i.naturalScroll ? "true" : "false") + ","
            + "      drag_lock = "            + (i.dragLock ? "true" : "false") + ","
            + "      disable_while_typing = " + (i.disableWhileTyping ? "true" : "false") + ","
            + "      scroll_factor = "        + i.scrollFactor
            + "    }"
            + "  },"
            + "  decoration = {"
            + "    rounding = "         + a.windowRounding + ","
            + "    inactive_opacity = " + a.inactiveOpacity + ","
            + "    shadow = { enabled = " + (a.shadows ? "true" : "false") + " },"
            + "    blur = {"
            + "      size = "       + a.blurSize + ","
            + "      passes = "     + a.blurPasses + ","
            + "      brightness = " + a.blurBrightness + ","
            + "      contrast = "   + a.blurContrast + ","
            + "      new_optimizations = "
            + (a.blurOptimize ? "true" : "false")
            + "    }"
            + "  }"
            + "})";
    }

    // Sensitivity and acceleration are set per device rather than
    // globally, so a mouse and a touchpad can differ. Every input
    // option except force_no_accel is valid inside hl.device().
    function buildDevices() {
        const i = Config.input;
        let out = "";

        for (const name of Devices.mice) {
            out += "hl.device({ name = \"" + name + "\","
                +  " sensitivity = " + i.mouseSensitivity + ","
                +  " accel_profile = \"" + i.mouseAccel + "\","
                +  " natural_scroll = " + (i.naturalScrollMouse ? "true" : "false")
                +  " }) ";
        }

        for (const name of Devices.touchpads) {
            out += "hl.device({ name = \"" + name + "\","
                +  " enabled = " + (i.touchpadEnabled ? "true" : "false") + ","
                +  " sensitivity = " + i.touchpadSensitivity + ","
                +  " accel_profile = \"" + i.touchpadAccel + "\","
                +  " natural_scroll = " + (i.naturalScroll ? "true" : "false") + ","
                +  " tap_to_click = " + (i.tapToClick ? "true" : "false") + ","
                +  " drag_lock = " + (i.dragLock ? "true" : "false") + ","
                +  " disable_while_typing = " + (i.disableWhileTyping ? "true" : "false") + ","
                +  " scroll_factor = " + i.scrollFactor
                +  " }) ";
        }

        return out;
    }

    function buildCommand() {
        const lua = buildLua() + " " + buildDevices();
        return "hyprctl eval " + JSON.stringify(lua);
    }

    Process {
        id: proc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[Compositor]", this.text.trim());
            }
        }
    }

    // Debounced: dragging a slider fires dozens of changes a second,
    // and each one would otherwise spawn ten hyprctl processes.
    Timer {
        id: debounce
        interval: 120
        onTriggered: root.apply()
    }

    // One binding that touches every value. Any change re-evaluates
    // it, which is more reliable than guessing the signal name for
    // each property on a JsonObject.
    // Includes the palette, so a wallpaper change re-sends the
    // border colours without waiting for an appearance setting to move.
    // Not readonly, and re-read on every change. A readonly binding
    // that nothing reads is evaluated lazily, so its change signal
    // never fired — which left stored appearance settings unapplied
    // until a slider was touched.
    property string watched: root.buildLua() + root.buildDevices()

    onWatchedChanged: {
        if (ready) debounce.restart();
    }

    // Config loads asynchronously, so the startup apply can run before
    // the file is in. This re-applies once it is.
    Connections {
        target: Config
        function onMergedChanged() {
            if (Config.merged) {
                root.ready = true;
                root.apply();
            }
        }
    }

    // Apply once at startup, after Config has loaded from disk.
    // Fallback for the case where Config was already loaded before
    // this singleton was instantiated, so onMergedChanged never fires.
    Timer {
        running: true
        interval: 600
        onTriggered: {
            root.ready = true;
            root.apply();
        }
    }

    IpcHandler {
        target: "appearance"
        function apply(): void { root.apply() }
        function preview(): string { return root.buildLua() + "\n" + root.buildDevices() }
    }
}
