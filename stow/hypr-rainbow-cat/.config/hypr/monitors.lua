-- rainbow-cat (desktop) — C49RG9x ultrawide + C24F390 side.
-- Monitors are matched by description, not port, so replugging cables to
-- different DP/HDMI ports (or motherboard vs GPU) does not break the config.
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and resolutions possible: hyprctl monitors all
-- You must relaunch Hyprland after changing any envs (Super+Shift+H).
--
-- The old envs-device.conf (NVD_BACKEND / LIBVA_DRIVER_NAME /
-- __GLX_VENDOR_LIBRARY_NAME) is gone: quattro detects the NVIDIA GPU and sets
-- those same three vars itself (see $OMARCHY_PATH/default/hypr/nvidia.lua).

local ultrawide = "desc:Samsung Electric Company C49RG9x"
local side = "desc:Samsung Electric Company C24F390"

-- Straight 1x setup for low-resolution displays like 1080p or 1440p
hl.env("GDK_SCALE", "1")

-- ultrawide (centered, scaled 1.25 -> logical 4096x1152)
hl.monitor({
  output = ultrawide,
  mode = "5120x1440@119.97",
  position = "0x0",
  scale = 1.25,
  -- scale = 1.333333,
  transform = 0,
  -- additional settings
  -- bitdepth = 10,
  -- cm = "hdr",
  sdrbrightness = 1.2,
  sdrsaturation = 1.0,
})

-- side monitor (on the RIGHT of the ultrawide; logical width 4096)
hl.monitor({
  output = side,
  mode = "1920x1080@60",
  position = "4096x0",
  scale = 1,
  transform = 0,
})

-- Workspaces switch on both monitors together (see workspaces.lua): the
-- ultrawide is leftmost, so it is the primary and shows 1-10, while the side
-- monitor shows 11-20. Workspace 1 is named "beet". The side monitor is narrow
-- enough to want a left-oriented master column, so that rule matches whatever
-- workspace it is showing rather than a range of ids.
hl.workspace_rule({ workspace = "1", default_name = "beet" })
hl.workspace_rule({ workspace = "m[" .. side .. "]", layout_opts = { orientation = "left" } })
