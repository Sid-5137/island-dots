-- Input
-- https://wiki.hypr.land/Configuring/Basics/Variables/
-- Hyphens are invalid in Lua keys, so tap-to-click is tap_to_click.

hl.config({
    input = {
        kb_layout          = "us",
        kb_rules           = "evdev",
        follow_mouse       = 1,
        sensitivity        = 0.8,
        numlock_by_default = true,
        repeat_rate        = 25,
        repeat_delay       = 600,
        force_no_accel     = false,
        -- accel_profile   = "flat",

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            drag_lock            = true,
            disable_while_typing = true,
            scroll_factor        = 0.6,
        },
    },

    cursor = {
        no_warps          = false,
        hide_on_key_press = true,
        inactive_timeout  = 5,
    },
})

-- Gestures
-- https://wiki.hypr.land/Configuring/Gestures/
-- `action` takes a Lua function, not a dispatcher string.

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.gesture({
    fingers   = 4,
    direction = "up",
    action    = function()
        hl.dispatch(hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0"))
    end,
})

hl.gesture({
    fingers   = 4,
    direction = "down",
    action    = function()
        hl.dispatch(hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
    end,
})
