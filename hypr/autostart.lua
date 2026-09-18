-- Autostart

hl.on("hyprland.start", function()
    -- Without this, systemd user units and D-Bus-activated services
    -- (the portal above all) never see XDG_CURRENT_DESKTOP and pick
    -- the wrong backend, or fail to start.
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP"
    )

    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- Polkit agent.
    -- hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")

    -- Clipboard history daemon.
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Continuous four-finger gestures. Needs the input group; exits
    -- quietly if it cannot read the devices.
    --
    -- PATH is set because Hyprland's own is /usr/local/bin:/usr/bin
    -- with no ~/.local/bin, so anything install.sh linked is not found
    -- by a bare name — silently, with no error and no log.
    hl.exec_cmd('PATH="$HOME/.local/bin:$PATH"; exec island-gestures')

    -- The shell itself.
    hl.exec_cmd("quickshell -c island")

end)
