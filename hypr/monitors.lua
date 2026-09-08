-- Monitors
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List outputs and modes with: hyprctl monitors

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@120",
    position = "0x0",
    scale    = 1,
})

-- Catch-all for anything hotplugged (dock, projector, external panel).
-- Remove it if you'd rather unknown outputs stay dark.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})