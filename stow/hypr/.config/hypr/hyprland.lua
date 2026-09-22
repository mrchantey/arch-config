-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/
--
-- Omarchy 4 (quattro) moved Hyprland config from *.conf to native Lua. The old
-- `source = ...` chain is gone: this file is the entry point, and everything
-- below is a Lua module resolved off package.path (~/.config/?.lua, then
-- $OMARCHY_PATH/?.lua -- see default/hypr/bootstrap.lua).
--
-- Naming: *.lua is shared (common `hypr` package); *-device.lua is per-device
-- and lives in a package named after the machine (stow/hypr-rainbow-cat,
-- stow/hypr-silver-fox), stowed by `just stow-device <name>`. Device modules
-- load AFTER their shared counterpart so the device always wins.

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Omarchy defaults first, so every override below lands on top of them.
require("default.hypr.omarchy")

-- Device modules are optional: a machine whose hypr-<device> package isn't
-- stowed yet still gets a working session instead of a hard config error.
local require_optional = require("default.hypr.require_optional")

-- Cursor theme/size, shared across devices.
require("hypr.envs")
-- Per-device env overrides. silver-fox forces the Intel VA-API driver on top of
-- Omarchy's nvidia.lua, which only checks that an NVIDIA GPU exists and would
-- otherwise send Chrome's video decode to the dGPU (see envs-device.lua).
require_optional.module("hypr.envs-device")

-- Monitors, GDK_SCALE, and workspace pinning are entirely per-device.
require_optional.module("hypr.monitors")

-- Shared input (keyboard, trackball), then this device's overrides.
require("hypr.input")
require_optional.module("hypr.input-device")

require("hypr.bindings")

-- Shared look'n'feel, then this device's master-layout orientation.
require("hypr.looknfeel")
require_optional.module("hypr.layout-device")

require("hypr.windows")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")
