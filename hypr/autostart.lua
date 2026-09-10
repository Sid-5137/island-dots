-- Autostart

hl.on("hyprland.start", function()
    -- Export the session environment to systemd and D-Bus. Without
    -- this, systemd user units and D-Bus-activated services (the
    -- portal above all) never see XDG_CURRENT_DESKTOP and pick the
    -- wrong backend — or fail to start at all.
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP"
    )

    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- Polkit agent.
    -- hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")

    -- Clipboard history daemon.
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Continuous four-finger gestures. Needs membership of the input
    -- group; it exits quietly if it cannot read the devices.
    hl.exec_cmd("~/island-dots/bin/island-gestures")

    -- The shell itself.
    hl.exec_cmd("quickshell -c island")

end)
