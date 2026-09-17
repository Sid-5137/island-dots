pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every keybind, read from the compositor rather than written down.
//
// A cheat sheet kept beside the config is a cheat sheet that is wrong
// by the second week: somebody rebinds a key, the list still says what
// it used to be, and the list is the thing people trust because it is
// the thing that claims to be the answer. `hyprctl binds` is what
// Hyprland is actually holding, so a bind added to hypr/binds.lua
// appears here with nothing else edited, and one that is removed
// disappears.
//
// The cost of that is the label: Hyprland stores a description per
// bind and nothing else, so anything with no description is a bind
// nobody wrote a name for, and it is left out rather than guessed at.
// Under the Lua config the dispatcher comes back as "__lua" and the
// argument as an integer — there is nothing in there to infer a name
// from even if guessing were a good idea.
//
// Groups come from the description, "Windows: Close", because the
// alternative is a second table somewhere that has to be kept in step
// with the first.

Singleton {
    id: root

    property bool open: false
    property var groups: []
    property string problem: ""

    function toggle() { open = !open; if (open) refresh(); }

    // ── Modifiers ────────────────────────────────────────────
    //
    // Hyprland reports the mask as the X11 bits. Named here because a
    // bit test spelled out at the use site is not readable, and
    // because the order they are printed in is the order people say
    // them in — "Super + Shift + S", never "Shift + Super + S".
    readonly property var mods: [
        { bit: 64, name: "Super" },
        { bit: 4,  name: "Ctrl" },
        { bit: 8,  name: "Alt" },
        { bit: 1,  name: "Shift" }
    ]

    // The keys whose names are not what you would call them out loud.
    readonly property var keyNames: ({
        "slash": "/",
        "minus": "−",
        "equal": "=",
        "comma": ",",
        "period": ".",
        "Return": "Enter",
        "Escape": "Esc",
        "Print": "PrtSc",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic mute",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright −",
        "XF86AudioPlay": "Play",
        "XF86AudioNext": "Next",
        "XF86AudioPrev": "Prev"
    })

    function chord(bind) {
        const parts = [];
        for (const m of mods)
            if (bind.modmask & m.bit) parts.push(m.name);

        const key = bind.key || "";
        parts.push(keyNames[key] || (key.length === 1 ? key.toUpperCase() : key));
        return parts;
    }

    function refresh() {
        if (proc.running) return;
        problem = "";
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let binds;
                try {
                    binds = JSON.parse(this.text);
                } catch (e) {
                    root.problem = "hyprctl binds returned something that is"
                        + " not JSON.";
                    return;
                }

                // Hyprland lists a bind once per submap it is live in,
                // so the same chord can come back more than once. Keyed
                // by chord and description together: two different binds
                // on one chord is a real thing to show, the same bind
                // twice is not.
                const seen = {};
                const byGroup = {};

                for (const b of binds) {
                    const desc = b.description || "";
                    if (desc === "") continue;

                    const parts = root.chord(b);
                    const id = parts.join("+") + "|" + desc;
                    if (seen[id]) continue;
                    seen[id] = true;

                    const cut = desc.indexOf(":");
                    const group = cut > 0 ? desc.slice(0, cut) : "Other";
                    const label = cut > 0 ? desc.slice(cut + 1).trim() : desc;

                    if (!byGroup[group]) byGroup[group] = [];
                    byGroup[group].push({ keys: parts, label: label });
                }

                // A fixed order, because the order hyprctl returns is
                // the order they were parsed in, and "what you press
                // most" is not "what binds.lua happens to declare
                // first". Anything not named here follows, so a group
                // invented in binds.lua still appears.
                const order = ["Shell", "Apps", "Windows", "Workspaces",
                               "Media", "Screen", "Session"];
                const names = Object.keys(byGroup).sort((a, b) => {
                    const ia = order.indexOf(a), ib = order.indexOf(b);
                    if (ia !== ib) return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
                    return a.localeCompare(b);
                });

                root.groups = names.map(n => ({ name: n, binds: byGroup[n] }));
            }
        }

        onExited: function(code) {
            if (code !== 0 && root.problem === "")
                root.problem = "hyprctl binds exited with " + code + ".";
        }
    }

    IpcHandler {
        target: "shortcuts"

        function toggle(): void { root.toggle() }
        function open(): void { root.open = true; root.refresh() }
        function hide(): void { root.open = false }

        function list(): string {
            if (root.groups.length === 0) return "not read yet";
            return root.groups.map(g =>
                g.name + "\n" + g.binds.map(b =>
                    "  " + b.keys.join(" + ") + "  —  " + b.label).join("\n")
            ).join("\n\n");
        }
    }
}
