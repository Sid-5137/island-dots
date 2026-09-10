-- Keybinds
-- https://wiki.hypr.land/Configuring/Binds/
--
-- Shell actions go through Quickshell IPC (see env.lua's Shell).
-- They fail harmlessly until the matching IpcHandler exists.
-- List what's available with: qs -c island ipc show

local mod = "SUPER"

hl.bind(mod .. " + X", hl.dsp.exec_cmd(Apps.terminal),    { description = "Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(Apps.fileManager), { description = "File manager" })
hl.bind(mod .. " + B", hl.dsp.exec_cmd(Apps.browser),     { description = "Browser" })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload config" })

hl.bind(mod .. " + R",         hl.dsp.exec_cmd(Shell .. "launcher toggle"))
hl.bind("ALT + Space",         hl.dsp.exec_cmd(Shell .. "launcher toggle"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd(Shell .. "notifications-ui toggle"))
hl.bind(mod .. " + S",         hl.dsp.exec_cmd(Shell .. "settings toggle"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(Shell .. "control toggle"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(Shell .. "picker wallpapers"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(Shell .. "picker palettes"))
hl.bind(mod .. " + SHIFT + I", hl.dsp.exec_cmd(Shell .. "picker icons"))
hl.bind(mod .. " + CTRL + W",  hl.dsp.exec_cmd(Shell .. "wallpaper next"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd(Shell .. "lock activate"))
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd(Shell .. "session toggle"))

hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + Space",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
-- Alt+Tab steps through the switcher; it commits itself once you stop
-- tabbing. There is deliberately no bind on the bare Alt key: binding
-- a modifier alone makes the compositor capture it, which breaks every
-- other Alt shortcut and leaves the session feeling frozen.
hl.bind("ALT + Tab",         hl.dsp.exec_cmd(Shell .. "switcher next"),     { repeating = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(Shell .. "switcher previous"), { repeating = true })
hl.bind("ALT + Escape",      hl.dsp.exec_cmd(Shell .. "switcher cancel"))


hl.bind(mod .. " + W",         hl.dsp.exec_cmd(Shell .. "overview toggle"))
hl.bind(mod .. " + Tab",       hl.dsp.window.cycle_next())

hl.bind("ALT + left",  hl.dsp.focus({ direction = "left" }))
hl.bind("ALT + right", hl.dsp.focus({ direction = "right" }))
hl.bind("ALT + up",    hl.dsp.focus({ direction = "up" }))
hl.bind("ALT + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

hl.bind("CTRL + SHIFT + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }))
hl.bind("CTRL + SHIFT + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }))
hl.bind("CTRL + SHIFT + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }))
hl.bind("CTRL + SHIFT + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }))

hl.bind("CTRL + ALT + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }))
hl.bind("CTRL + ALT + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }))
hl.bind("CTRL + ALT + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }))
hl.bind("CTRL + ALT + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }))

for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mod .. " + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + left",     hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("CTRL + right",    hl.dsp.window.move({ workspace = "e+1" }))

hl.bind("CTRL + " .. mod .. " + left",  hl.dsp.window.move({ workspace = "e-1", follow = false }))
hl.bind("CTRL + " .. mod .. " + right", hl.dsp.window.move({ workspace = "e+1", follow = false }))

hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))

hl.bind("ALT + SHIFT + left",  hl.dsp.focus({ monitor = "l" }))
hl.bind("ALT + SHIFT + right", hl.dsp.focus({ monitor = "r" }))
hl.bind(mod .. " + ALT + left",  hl.dsp.window.move({ monitor = "l" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ monitor = "r" }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- locked = fires while the screen is locked
-- repeating = repeats while held

-- Routed through the shell so the change and the readout happen
-- together. Calling wpctl directly leaves the OSD waiting on Audio's
-- 2s poll, which is far too slow to read as feedback.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(Shell .. "osd volumeUp"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(Shell .. "osd volumeDown"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(Shell .. "osd volumeMute"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(Shell .. "osd micMute"),        { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(Shell .. "osd brightnessUp"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(Shell .. "osd brightnessDown"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind(mod .. " + V", hl.dsp.exec_cmd(Shell .. "clipboard-ui toggle"))

hl.bind("Print",               hl.dsp.exec_cmd("hyprshot -z -m region -o ~/Pictures/Screenshots"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd("hyprshot -z -m output -o ~/Pictures/Screenshots"))
hl.bind("CTRL + Print",        hl.dsp.exec_cmd("hyprshot -z -m window -o ~/Pictures/Screenshots"))

-- Clipboard only, when you're pasting straight into something.
hl.bind("ALT + Print",         hl.dsp.exec_cmd("hyprshot -z -m region --clipboard-only"))

-- Same set on SUPER, since Print is awkward on some laptop layouts.
hl.bind(mod .. " + Print",     hl.dsp.exec_cmd("hyprshot -z -m region -o ~/Pictures/Screenshots"))

hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))
