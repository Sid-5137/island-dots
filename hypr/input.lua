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

-- Four-finger swipes are handled by bin/island-gestures, which reads
-- libinput directly. Hyprland's gesture action fires once on release;
-- reading the events gives a value that follows the fingers instead.
-- A gesture defined here as well would fire on top of it.


