-- island-dots — a Hyprland shell built around a morphing pill.
-- Copyright (C) 2026 Siddhartha Mallavolu
--
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version. See LICENSE.

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
