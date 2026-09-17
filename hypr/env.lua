-- Environment
-- https://wiki.hypr.land/Configuring/Environment-variables/

-- Default programs. Lua has no hyprlang-style $variables, so these
-- live in a global table that binds.lua reads.
Apps = {
    terminal    = "kitty",
    fileManager = "nautilus",
    browser     = "firefox",
}

-- Settings -> Apps writes what you picked to a generated table under
-- the state directory, and it is overlaid here. It is a separate file
-- rather than an edit to this one because install.sh symlinks
-- ~/.config/hypr to the checkout: a settings window that wrote here
-- would show up as a diff in `git status` every time somebody changed
-- their browser. Anything not picked keeps the value above.
--
-- The whole load is inside one pcall, missing file and all. Nothing
-- has been chosen yet on a fresh install, which is the normal case
-- and not an error — and an error raised here would take the rest of
-- the config down with it, leaving a session with no keybinds at all
-- because of a file that only decides which terminal opens.
local ok, chosen = pcall(function()
    local state = os.getenv("XDG_STATE_HOME")
        or (os.getenv("HOME") .. "/.local/state")
    local chunk = loadfile(state .. "/island/apps.lua")
    return chunk and chunk()
end)

if ok and type(chosen) == "table" then
    for key, value in pairs(chosen) do
        if type(value) == "string" and value ~= "" then Apps[key] = value end
    end
end

-- Quickshell IPC prefix. Shell actions go through this rather than
-- spawning separate programs.
Shell = "qs -c island ipc call "

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT_QPA_PLATFORM keeps an xcb fallback so Qt apps shipped without
-- the Wayland plugin start under XWayland instead of failing.

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Java apps that render a blank window under Wayland.
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
