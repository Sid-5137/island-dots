-- Keybinds
-- https://wiki.hypr.land/Configuring/Binds/
--
-- Shell actions go through Quickshell IPC (see env.lua's Shell).
-- They fail harmlessly until the matching IpcHandler exists.
-- List what's available with: qs -c island ipc show

local mod = "SUPER"

hl.bind(mod .. " + X", hl.dsp.exec_cmd(Apps.terminal),    { description = "Apps: Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(Apps.fileManager), { description = "Apps: File manager" })
hl.bind(mod .. " + B", hl.dsp.exec_cmd(Apps.browser),     { description = "Apps: Browser" })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Session: Reload config" })

hl.bind(mod .. " + R",         hl.dsp.exec_cmd(Shell .. "launcher toggle"), { description = "Shell: Launcher" })
hl.bind("ALT + Space",         hl.dsp.exec_cmd(Shell .. "launcher toggle"), { description = "Shell: Launcher" })
hl.bind(mod .. " + N",         hl.dsp.exec_cmd(Shell .. "notifications-ui toggle"), { description = "Shell: Notifications" })
hl.bind(mod .. " + S",         hl.dsp.exec_cmd(Shell .. "settings toggle"), { description = "Shell: Settings" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(Shell .. "control toggle"), { description = "Shell: Control centre" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(Shell .. "picker wallpapers"), { description = "Shell: Wallpaper picker" })
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(Shell .. "picker palettes"), { description = "Shell: Palette picker" })
hl.bind(mod .. " + SHIFT + I", hl.dsp.exec_cmd(Shell .. "picker icons"), { description = "Shell: Icon theme (Settings)" })
hl.bind(mod .. " + CTRL + W",  hl.dsp.exec_cmd(Shell .. "wallpaper next"), { description = "Shell: Next wallpaper" })
hl.bind(mod .. " + L",         hl.dsp.exec_cmd(Shell .. "lock activate"), { description = "Shell: Lock" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd(Shell .. "session toggle"), { description = "Shell: Power menu" })

hl.bind(mod .. " + Q",         hl.dsp.window.close(), { description = "Windows: Close" })
hl.bind(mod .. " + Space",     hl.dsp.window.float({ action = "toggle" }), { description = "Windows: Float" })
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Windows: Fullscreen" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Windows: Maximise" })
-- Alt+Tab steps through the switcher; it commits itself once you stop
-- tabbing. There is deliberately no bind on the bare Alt key: binding
-- a modifier alone makes the compositor capture it, which breaks every
-- other Alt shortcut and leaves the session feeling frozen.
hl.bind("ALT + Tab",         hl.dsp.exec_cmd(Shell .. "switcher next"),     { repeating = true, description = "Windows: Switch window"})
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(Shell .. "switcher previous"), { repeating = true, description = "Windows: Switch back"})
hl.bind("ALT + Escape",      hl.dsp.exec_cmd(Shell .. "switcher cancel"), { description = "Windows: Cancel switching" })


hl.bind(mod .. " + W",         hl.dsp.exec_cmd(Shell .. "overview toggle"), { description = "Shell: Overview" })
hl.bind(mod .. " + Tab",       hl.dsp.window.cycle_next(), { description = "Windows: Cycle" })

hl.bind("ALT + left",  hl.dsp.focus({ direction = "left" }), { description = "Windows: Focus left" })
hl.bind("ALT + right", hl.dsp.focus({ direction = "right" }), { description = "Windows: Focus right" })
hl.bind("ALT + up",    hl.dsp.focus({ direction = "up" }), { description = "Windows: Focus up" })
hl.bind("ALT + down",  hl.dsp.focus({ direction = "down" }), { description = "Windows: Focus down" })

hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }), { description = "Windows: Swap left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), { description = "Windows: Swap right" })
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }), { description = "Windows: Swap up" })
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }), { description = "Windows: Swap down" })

hl.bind("CTRL + SHIFT + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { description = "Windows: Nudge left" })
hl.bind("CTRL + SHIFT + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { description = "Windows: Nudge right" })
hl.bind("CTRL + SHIFT + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { description = "Windows: Nudge up" })
hl.bind("CTRL + SHIFT + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { description = "Windows: Nudge down" })

hl.bind("CTRL + ALT + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { description = "Windows: Narrower" })
hl.bind("CTRL + ALT + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { description = "Windows: Wider" })
hl.bind("CTRL + ALT + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { description = "Windows: Shorter" })
hl.bind("CTRL + ALT + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { description = "Windows: Taller" })

-- Only the first of each run carries a description, and it names the
-- whole run. Nine near-identical rows in the shortcuts window is a
-- column of noise saying one thing; see Services/Shortcuts.qml, which
-- shows exactly what it is told and nothing it had to guess.
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }),
        i == 1 and { description = "Workspaces: Go to workspace 1-9" } or nil)
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }),
        i == 1 and { description = "Workspaces: Send window to 1-9" } or nil)
end

hl.bind(mod .. " + left",  hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous" })
hl.bind(mod .. " + right", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next" })
hl.bind("CTRL + left",     hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspaces: Take window back" })
hl.bind("CTRL + right",    hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspaces: Take window on" })

hl.bind("CTRL + " .. mod .. " + left",  hl.dsp.window.move({ workspace = "e-1", follow = false }), { description = "Workspaces: Send window back" })
hl.bind("CTRL + " .. mod .. " + right", hl.dsp.window.move({ workspace = "e+1", follow = false }), { description = "Workspaces: Send window on" })

hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratchpad"), { description = "Workspaces: Scratchpad" })
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }), { description = "Workspaces: Send to scratchpad" })

hl.bind("ALT + SHIFT + left",  hl.dsp.focus({ monitor = "l" }), { description = "Workspaces: Focus left monitor" })
hl.bind("ALT + SHIFT + right", hl.dsp.focus({ monitor = "r" }), { description = "Workspaces: Focus right monitor" })
hl.bind(mod .. " + ALT + left",  hl.dsp.window.move({ monitor = "l" }), { description = "Workspaces: Send to left monitor" })
hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ monitor = "r" }), { description = "Workspaces: Send to right monitor" })

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- locked = fires while the screen is locked
-- repeating = repeats while held

-- Routed through the shell so the change and the readout happen
-- together. Calling wpctl directly leaves the OSD waiting on Audio's
-- 2s poll, which is far too slow to read as feedback.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(Shell .. "osd volumeUp"),       { locked = true, repeating = true, description = "Media: Volume up"})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(Shell .. "osd volumeDown"),     { locked = true, repeating = true, description = "Media: Volume down"})
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(Shell .. "osd volumeMute"),     { locked = true, description = "Media: Mute"})
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(Shell .. "osd micMute"),        { locked = true, description = "Media: Mute microphone"})

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(Shell .. "osd brightnessUp"),   { locked = true, repeating = true, description = "Media: Brighter"})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(Shell .. "osd brightnessDown"), { locked = true, repeating = true, description = "Media: Dimmer"})

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause"})
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Media: Next track"})
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Media: Previous track"})

hl.bind(mod .. " + V", hl.dsp.exec_cmd(Shell .. "clipboard-ui toggle"), { description = "Shell: Clipboard history" })

hl.bind("Print",               hl.dsp.exec_cmd("hyprshot -z -m region -o ~/Pictures/Screenshots"), { description = "Screen: Shot a region" })
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd("hyprshot -z -m output -o ~/Pictures/Screenshots"), { description = "Screen: Shot the screen" })
hl.bind("CTRL + Print",        hl.dsp.exec_cmd("hyprshot -z -m window -o ~/Pictures/Screenshots"), { description = "Screen: Shot a window" })

-- Clipboard only, when you're pasting straight into something.
hl.bind("ALT + Print",         hl.dsp.exec_cmd("hyprshot -z -m region --clipboard-only"), { description = "Screen: Region to clipboard" })

-- Same set on SUPER, since Print is awkward on some laptop layouts.
hl.bind(mod .. " + Print",     hl.dsp.exec_cmd("hyprshot -z -m region -o ~/Pictures/Screenshots"), { description = "Screen: Shot a region" })

hl.bind(mod .. " + SHIFT + E", hl.dsp.exit(), { description = "Session: Log out" })

-- The list of everything above, drawn from `hyprctl binds` rather than
-- written out a second time. Two keys because two habits: the one the
-- user asked for, and the slash every other cheat sheet is under.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(Shell .. "shortcuts toggle"),
    { description = "Shell: Shortcuts" })
hl.bind(mod .. " + slash",     hl.dsp.exec_cmd(Shell .. "shortcuts toggle"))
