-- ─────────────────────────────────────────────────────────────
-- Hyprland — root config
-- https://wiki.hypr.land/Configuring/Start/
--
-- This file only pulls in the modules. Put nothing else here.
-- Order matters: env before anything spawns, autostart last.
--
-- require() resolves against this directory, so each module is
-- just its filename without the .lua extension.
-- ─────────────────────────────────────────────────────────────

require("env")
require("monitors")
require("input")
require("look")
require("rules")
require("binds")
require("autostart")
