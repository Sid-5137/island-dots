-- Autostart
--
-- Lua has no exec-once; you subscribe to the session start event.
-- Required last so everything it spawns sees env.lua's variables.
--
-- The shell owns wallpaper, notifications, OSD and the launcher, so
-- there is deliberately no swaybg / mako / fuzzel here.

hl.on("hyprland.start", function()
    -- Export the session environment to systemd and D-Bus. Without
    -- this, systemd user units and D-Bus-activated services (the
    -- portal above all) never see XDG_CURRENT_DESKTOP and pick the
    -- wrong backend — or fail to start at all.
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP"
    )

    -- Reach graphical-session.target. Hyprland launched from a display
    -- manager has no session manager, so nothing pulls this target up,
    -- and xdg-desktop-portal (which Requires= it) never starts.
    -- Needs ~/.config/systemd/user/hyprland-session.target — see README.
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- Polkit agent. Without one, anything needing authorization fails
    -- silently instead of prompting. GNOME's agent lives inside
    -- gnome-shell and is unavailable here, hence mate-polkit.
    hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")

    -- Clipboard history daemon. The shell reads from cliphist rather
    -- than replacing it, so history survives shell reloads.
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- The shell itself.
    hl.exec_cmd("quickshell -c island")

    -- Idle, dimming and suspend. Its config is hypr/hypridle.conf.
    hl.exec_cmd("hypridle -c ~/.config/hypr/hypridle.conf")
end)
