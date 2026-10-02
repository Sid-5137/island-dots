-- Window rules
-- https://wiki.hypr.land/Configuring/Window-Rules/
-- Find a window's class and title with: hyprctl clients

hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland drag surfaces steal focus without this.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name   = "calculator",
    match  = { class = "org.gnome.Calculator" },
    float  = true,
    size   = { 400, 580 },
    center = true,
})

hl.window_rule({
    name  = "firefox-pip",
    match = { class = "org.mozilla.firefox", title = "^Picture-in-Picture$" },
    float = true,
    pin   = true,
})

hl.window_rule({
    name   = "pavucontrol",
    match  = { class = "pavucontrol" },
    float  = true,
    size   = { 720, 560 },
    center = true,
})

for _, class in ipairs({ "nm-connection-editor", "blueman-manager" }) do
    hl.window_rule({
        name  = "float-" .. class,
        match = { class = class },
        float = true,
    })
end

for _, title in ipairs({ "^Open File$", "^Save File$", "^Authentication Required$" }) do
    hl.window_rule({
        name  = "float-dialog-" .. title,
        match = { title = title },
        float = true,
    })
end

-- The two numbers are active and inactive. Firefox is fully opaque
-- while focused so page content renders honestly, and only dims
-- slightly when it isn't the active window.

-- Class names come from `hyprctl clients`, not from the app's name.
-- Fedora's Firefox reports org.mozilla.firefox; other builds differ.
hl.window_rule({
    name    = "firefox-opacity",
    match   = { class = "org.mozilla.firefox" },
    opacity = "1.0 override 0.96 override",
})

-- Image and video need true colour in both states.
for _, class in ipairs({ "org.gnome.Loupe", "mpv", "org.gnome.Papers" }) do
    hl.window_rule({
        name    = "opaque-" .. class,
        match   = { class = class },
        opacity = "1.0 override 1.0 override",
    })
end

hl.window_rule({
    name    = "kitty-opacity",
    match   = { class = "kitty" },
    opacity = "1.0 override 1.0 override",
})

hl.window_rule({
    name    = "nautilus-opacity",
    match   = { class = "org.gnome.Nautilus" },
    opacity = "0.85 override 0.80 override",
})

-- Hide credential managers from screen capture.

-- hl.window_rule({
--     name       = "block-secrets",
--     match      = { class = "org.gnome.World.Secrets" },
--     no_screen_share = true,
-- })

-- Layer rules
--
-- Namespaces come from the `namespace` property on each PanelWindow
-- in QML. Verify what actually registers with: hyprctl layers
--
-- ONE rule per namespace. Declaring a namespace twice makes the
-- later rule fight the earlier one, and neither applies cleanly.

-- Wallpaper: it IS the background, so nothing to blur and nothing
-- to animate.
hl.layer_rule({
    name    = "island-wallpaper",
    match   = { namespace = "^island-wallpaper$" },
    no_anim = true,
})

-- The island animates its own geometry in QML; Hyprland's layer
-- animations fight that.
hl.layer_rule({
    name         = "island-bar",
    match        = { namespace = "^island-bar$" },
    no_anim      = true,
    blur         = true,
    -- The blur mask is all or nothing per pixel: above the threshold
    -- a pixel gets the blurred background, below it gets none. At 0.03
    -- the soft antialiased edge of every shape was over the line, so
    -- each one wore a hard-stepped ring of blurred background just
    -- outside its outline. 0.35 puts the mask's edge inside the
    -- shape's own, under the border, and still under every fill the
    -- shell can be set to: the lowest is the popup slider's 0.4. It
    -- was low once because the control centre's cards floated with no
    -- panel behind them; the panel is the surface now.
    ignore_alpha = 0.35,
    -- No xray: blur what is actually underneath. xray blurred the
    -- wallpaper instead, so the island looked the same over any window
    -- — but an edge pixel the shape only partly covers still gets the
    -- blur at full strength, and with xray that blur is the wallpaper.
    -- Every curve wore a wallpaper-coloured line wherever the island
    -- sat over a window, red over a dark terminal, and no threshold
    -- removes it: measured on screen, only blurring the real
    -- background did. The island now takes its tint from what is
    -- under it, the way a macOS material does.
    xray         = false,
})

-- Under the lowest panel opacity (0.6) so a panel is always blurred,
-- and well over its antialiased edge so the edge is not — see the
-- island's rule above for what a low threshold does to an outline.
for _, ns in ipairs({ "island-settings", "island-shortcuts" }) do
    hl.layer_rule({
        name         = ns,
        match        = { namespace = "^" .. ns .. "$" },
        blur         = true,
        ignore_alpha = 0.5,
        no_anim      = true,
    })
end

-- hyprshot's freeze overlay and slurp's selection surface. No blur or
-- animation: a blurred freeze frame is the wrong thing to select from,
-- and a fade makes the selection lag the keypress.
for _, ns in ipairs({ "hyprshot", "selection", "slurp" }) do
    hl.layer_rule({
        name    = "shot-" .. ns,
        match   = { namespace = "^" .. ns .. "$" },
        no_anim = true,
    })
end

-- There is no island-notifications, island-osd or island-launcher
-- surface and there has not been since those became modes of the pill
-- rather than windows of their own. `hyprctl layers` lists exactly
-- two: island-wallpaper and island-bar. Rules for the other three sat
-- here matching nothing, which is worse than absent — they read as
-- the notification popup having its own blur settings, so the place
-- you would go to fix its blur was the one place that could not.
