-- ─────────────────────────────────────────────────────────────
-- Window rules
-- https://wiki.hypr.land/Configuring/Window-Rules/
-- Find a window's class and title with: hyprctl clients
-- ─────────────────────────────────────────────────────────────

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

-- ── Floating ─────────────────────────────────────────────────

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

-- ── Opacity ──────────────────────────────────────────────────
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
    opacity = "0.92 override 0.88 override",
})

hl.window_rule({
    name    = "nautilus-opacity",
    match   = { class = "org.gnome.Nautilus" },
    opacity = "0.94 override 0.90 override",
})

-- ── Privacy ──────────────────────────────────────────────────
-- Hide credential managers from screen capture.

-- hl.window_rule({
--     name       = "block-secrets",
--     match      = { class = "org.gnome.World.Secrets" },
--     no_screen_share = true,
-- })

-- ─────────────────────────────────────────────────────────────
-- Layer rules
--
-- Namespaces come from the `namespace` property on each PanelWindow
-- in QML. Verify what actually registers with: hyprctl layers
--
-- ONE rule per namespace. Declaring a namespace twice makes the
-- later rule fight the earlier one, and neither applies cleanly.
-- ─────────────────────────────────────────────────────────────

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
    ignore_alpha = 0.1,
})

-- The settings window draws its own opaque panel and dims the desktop
-- itself, so there's nothing here to blur — a blur behind a solid
-- surface is wasted GPU, and blurring the desktop as well made the
-- whole screen soft rather than just dimmed.
for _, ns in ipairs({ "island-launcher", "island-settings" }) do
    hl.layer_rule({
        name    = ns,
        match   = { namespace = "^" .. ns .. "$" },
        no_anim = true,
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

for _, ns in ipairs({ "island-notifications", "island-osd" }) do
    hl.layer_rule({
        name         = ns,
        match        = { namespace = "^" .. ns .. "$" },
        blur         = true,
        ignore_alpha = 0.1,
        no_anim      = true,
    })
end
