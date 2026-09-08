-- ─────────────────────────────────────────────────────────────
-- Environment
-- https://wiki.hypr.land/Configuring/Environment-variables/
-- ─────────────────────────────────────────────────────────────

-- Default programs. Lua has no hyprlang-style $variables, so these
-- live in a global table that binds.lua reads.
Apps = {
    terminal    = "kitty",
    fileManager = "nautilus",
    browser     = "firefox",
}

-- Quickshell IPC prefix. Shell actions go through this rather than
-- spawning separate programs.
Shell = "qs -c island ipc call "

-- ── Session ──────────────────────────────────────────────────

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- ── Toolkits ─────────────────────────────────────────────────
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
