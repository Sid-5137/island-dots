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
    -- install.sh links this into ~/.local/bin, so the clone can live
    -- anywhere. A hardcoded ~/island-dots path meant gestures simply
    -- never started on a machine that cloned it somewhere else.
    --
    -- PATH is set here because Hyprland does not have one worth the
    -- name: its own environment is /usr/local/bin:/usr/bin, with no
    -- ~/.local/bin in it. So a bare name finds quickshell and
    -- wl-paste, which live in /usr/bin, and finds nothing at all for
    -- anything install.sh linked — no error, no log, just a daemon
    -- that was never running. Volume and brightness swipes did
    -- nothing and the socket the shell was serving sat empty.
    hl.exec_cmd('PATH="$HOME/.local/bin:$PATH"; exec island-gestures')

    -- The shell itself.
    hl.exec_cmd("quickshell -c island")

end)
