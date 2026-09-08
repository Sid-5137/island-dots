-- ─────────────────────────────────────────────────────────────
-- Look and feel
-- https://wiki.hypr.land/Configuring/Basics/Variables/
--
-- Monochrome: near-white active border, near-black inactive.
-- Colors accept "#rrggbb", "#rrggbbaa" or "rgba(rrggbbaa)".
-- ─────────────────────────────────────────────────────────────

local mono = {
    active   = "#e8e8ec",
    inactive = "#26262c",
    urgent   = "#ffffff",
}

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 1,

        col = {
            active_border   = mono.active,
            inactive_border = mono.inactive,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 0,
        rounding_power   = 2,
        active_opacity   = 0.85,
        inactive_opacity = 0.94,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = "rgba(00000066)",
        },

        blur = {
            enabled            = true,
            size               = 8,
            passes             = 3,
            noise              = 0.02,
            contrast           = 0.9,
            brightness         = 0.85,
            vibrancy           = 0.0,
            popups             = true,
            popups_ignorealpha = 0.2,
            new_optimizations  = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
    },

    master = {
        new_status = "master",
        mfact      = 0.55,
        new_on_top = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        focus_on_activate        = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,
    },
})

-- ─────────────────────────────────────────────────────────────
-- Animations
-- https://wiki.hypr.land/Configuring/Animations/
-- ─────────────────────────────────────────────────────────────

hl.curve("spring",   { type = "bezier", points = { {0.46, 1.0},  {0.29, 1} } })
hl.curve("closeOut", { type = "bezier", points = { {0.08, 0.92}, {0, 1}    } })
hl.curve("linear",   { type = "bezier", points = { {0, 0},       {1, 1}    } })

hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "spring",   style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 8, bezier = "closeOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "spring" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "layers",      enabled = true, speed = 4, bezier = "spring",   style = "fade" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4, bezier = "spring",   style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 3, bezier = "closeOut", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "spring",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 5, bezier = "linear" })
