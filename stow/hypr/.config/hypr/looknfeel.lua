-- Change the default Omarchy look'n'feel.
-- Shared across all devices (per-device monitor/scale lives in monitors.lua).
-- https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    layout = "master",
  },

  decoration = {
    rounding = 0,
    -- careful! you might make this window disappear
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1.0,

    blur = {
      enabled = false,
    },
  },
})

-- Omarchy tags every window `default-opacity` and then applies 0.985/0.96 to
-- that tag (default/hypr/windows.lua), which overrides the opacity settings
-- above on a per-window basis. Drop the rule so fully opaque actually sticks.
o.window({ tag = "default-opacity" }, { opacity = "1.0 1.0" })

-- Master-layout orientation is device-specific (centered column on the ultrawide,
-- full-screen on the laptop) and lives in the per-device hypr-<device>/layout-device.lua,
-- required after this file. See docs/devices/<host>.md.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.
