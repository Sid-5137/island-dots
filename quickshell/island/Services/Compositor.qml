pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────
// Compositor
//
// Pushes Config.appearance into Hyprland at runtime with
// `hyprctl eval`, so a slider in the settings app changes blur or
// gaps immediately without editing look.lua or reloading.
//
// `hyprctl keyword` does NOT work with the Lua config parser — it
// errors with "keyword can\'t work with non-legacy parsers". eval
// takes Lua instead, which means the whole appearance block goes in
// one call rather than ten separate processes.
//
// These are runtime overrides — they do NOT persist to look.lua.
// On the next Hyprland restart the .lua values apply again, and
// then this reapplies Config on top. That's deliberate: look.lua
// stays the checked-in default, settings.json is this machine.
// ─────────────────────────────────────────────────────────────

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
            + "    sensitivity = "   + i.mouseSensitivity + ","
            + "    accel_profile = \"" + i.mouseAccel + "\","
            + "    natural_scroll = " + (i.naturalScrollMouse ? "true" : "false") + ","
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
            + "  general = {"
            + "    gaps_in = "      + a.gapsIn + ","
            + "    gaps_out = "     + a.gapsOut + ","
            + "    border_size = "  + a.borderSize + ","
            // Border colours come from Theme, which tracks
            // colors.json — so a new wallpaper retints window borders
            // along with everything else. look.lua's hardcoded values
            // remain the checked-in fallback for when the shell
            // isn't running.
            + "    col = {"
            + "      active_border = \"" + Theme.primary + "\","
            + "      inactive_border = \"" + Theme.outlineVariant + "\""
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
            + "      contrast = "   + a.blurContrast
            + "    }"
            + "  }"
            + "})";
    }

    function buildCommand() {
        return "hyprctl eval " + JSON.stringify(buildLua());
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
    readonly property string watched: root.buildLua()
    onWatchedChanged: debounce.restart()

    // Apply once at startup, after Config has loaded from disk.
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
        function preview(): string { return root.buildLua() }
    }
}
