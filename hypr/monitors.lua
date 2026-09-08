-- ─────────────────────────────────────────────────────────────
-- Monitors
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List outputs and modes with: hyprctl monitors
-- ─────────────────────────────────────────────────────────────

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

-- ─────────────────────────────────────────────────────────────
-- Workspace rules
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- ─────────────────────────────────────────────────────────────

-- Persistent workspaces keep empty slots visible in a bar that only
-- renders workspaces which exist. Uncomment once the island shows them.
--
-- for i = 1, 5 do
--     hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", persistent = true })
-- end

-- Smart gaps: drop gaps when a workspace holds one tiled window,
-- or one fullscreen window.
--
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
