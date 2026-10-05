-- silver-fox (Dell Precision 7560) — internal 1080p panel + the desk 1440p monitor.
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Panel is a BOE 0x08CF, eDP-1, 1920x1080 at 340x190mm (~143 DPI, 16:9). Its
-- only other mode is 1920x1080@48, so there is nothing to choose between; the
-- mode is spelled out rather than left as "preferred" because it doubles as the
-- record of what this machine actually has.
--
-- The GPUs are an Intel TigerLake-H iGPU (drives the compositor on eDP-1) and an
-- NVIDIA RTX A2000 Mobile for CUDA + per-app PRIME render offload, e.g.
--   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>
-- LIBVA_DRIVER_NAME must NOT be nvidia here. Quattro's nvidia.lua does NOT
-- detect hybrids: it only checks that an NVIDIA GPU exists and then forces the
-- nvidia VA-API driver session-wide, which broke Chrome video (every decoded
-- frame failed to import into Chrome's Intel GL context and the window went
-- blank). envs-device.lua overrides it to iHD; the full story is in there.
--
-- One real difference from the retired XPS, whose dGPU drove no displays at all:
-- here the external ports are SPLIT across the two GPUs. From /sys/class/drm --
--   NVIDIA (card1): HDMI-A-1, DP-1, DP-2, DP-3   <- the physical HDMI + mDP ports
--   Intel  (card2): eDP-1, DP-4, DP-5            <- the panel + USB-C DP-alt
-- so plugging into the HDMI/mDP side wakes the dGPU and keeps it awake, which
-- matters for battery and for the on-battery dGPU-suspend behaviour that voxtype
-- and the TTS server both key off. Prefer USB-C for a projector when on battery.
--
-- There is a second, sharper reason to prefer the Intel side, found on
-- 2026-09-25. An output on the NVIDIA card is not rendered there: Hyprland
-- composites on the Intel iGPU and then BLITS every frame across to the dGPU for
-- scanout, because that is the card the connector is wired to. That blit path is
-- rebuilt from scratch whenever the monitor sleeps and wakes (the log says
-- "Deinitializing secondary renderer on /dev/dri/card1"), and it can come back
-- broken: `EGL (blit): glCheckFramebufferStatus failed: 1282` on every cursor
-- move, with stale unrepainted regions left on screen until something forces
-- full damage. A monitor on DP-4/DP-5 (USB-C DP-alt, Intel side) has no blit at
-- all. See the "rendering corrupts after the monitor sleeps" trap in the
-- info-silver-fox skill.

-- scale 1, NOT omarchy's "auto". On this panel auto picks 1.5, which leaves a
-- 1280x720 logical desktop -- unusably cramped. At scale 1 the logical desktop is
-- 1920x1080, near-identical to what the retired XPS gave (4K panel at scale 2 =
-- 1920x1200), so the workspace stays the size it has always been. This is a
-- 1080p panel, so there is no HiDPI to serve and no fractional-scaling blur to
-- accept. Bump to 1.25 if the text is too small; do not go back to "auto".
hl.env("GDK_SCALE", "1")

local desk_description = "Samsung Electric Company Odyssey G5"
local desk = "desc:" .. desk_description

hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "auto", scale = 1 })

-- The desk monitor, matched by description rather than port so it does not
-- matter which cable or which GPU it lands on: HDMI-A-1 on the NVIDIA card over
-- a plain HDMI cable, DP-4 on the Intel side through a USB-C dongle. 16:9 at
-- ~108 DPI. Its fastest 1440p mode depends on the route: @144 over direct
-- HDMI, @180 over USB-C to DisplayPort, @59.95 through the USB-C to HDMI dongle.
-- "highres" takes the largest advertised mode and the fastest refresh at it, so
-- every route gets its best. A fixed "2560x1440@144" is not safe: where @144 is
-- not advertised, Hyprland fell back to @59.95 at boot but synthesised a custom
-- @144 mode when the output was re-enabled, past the limit that kept the dongle
-- from advertising it.
--
-- scale 1.25 (125% zoom) -> a 2048x1152 logical desktop. Both axes divide
-- exactly at 1.25, so this is a clean fractional scale: no half-pixel logical
-- size for Hyprland to round, which is what makes some fractional scales blur
-- or leave a seam. It matches rainbow-cat's ultrawide, so text is the same
-- physical size on both desks. 2048x1152 is still wider than the laptop panel's
-- 1920x1080, so nothing on screen gets smaller than it was undocked.
--
-- Naming it explicitly is what opts it OUT of the mirror fallback below: this is
-- a second desktop, not a duplicate of the laptop panel. A monitor with its own
-- rule never falls through to the empty-output rule, whatever the order here.
hl.monitor({ output = desk, mode = "highres", position = "auto", scale = 1.25 })

-- Fallback auto-mirror: any UNKNOWN external plugged in mirrors the internal
-- panel, which is what you want from a projector in a meeting room. The
-- empty-output rule is Hyprland's fallback -- it applies to any monitor without
-- its own rule, so it catches whatever the cable enumerates as (DP-1..DP-5
-- depending on which port and which GPU). eDP-1 and the desk monitor keep their
-- explicit rules above and are not mirrored.
--
-- Hyprland mirroring copies the SOURCE framebuffer and stretches it to fill the
-- target, so a mismatched aspect ratio distorts the image. On the XPS that was a
-- real problem (16:10 3840x2400 panel -> 16:9 projector, squished ~11%) and
-- scripts/silver-fox/present-mirror existed purely to force both ends to 1080p.
-- This panel is natively 16:9 1080p, so the plain rule below already produces a
-- 1:1 image on any 16:9 projector or TV; the script was deleted with the XPS.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })

-- The desk monitor is the main screen: workspaces 1-6 live on it and 7-10 on the
-- laptop panel, as on rainbow-cat. Undocked, every workspace falls back to the
-- panel.
hl.workspace_rule({ workspace = "1", monitor = desk, default = true })
for workspace = 2, 6 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = desk })
end
hl.workspace_rule({ workspace = "7", monitor = "eDP-1", default = true })
for workspace = 8, 10 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = "eDP-1" })
end

-- Docking turns the laptop panel off, lid open or shut. Super+Ctrl+Delete brings
-- it back for a two-screen session, until the desk monitor next reconnects.
--
-- A `disabled = true` on eDP-1 here would leave no display at all once
-- unplugged, and omarchy-hyprland-monitor-clamshell re-enables any panel it
-- finds disabled without one of its own flags. So this goes through Omarchy's
-- manual toggle, `omarchy hyprland monitor internal off`, which writes
-- hl.monitor({ output = "eDP-1", disabled = true }) into
-- ~/.local/state/omarchy/toggles/hypr/internal-monitor-disable.lua.
-- default.hypr.toggles loads that directory last, so it lands on top of this
-- file, and the clamshell script leaves the panel alone while that flag and an
-- external monitor are both present. Two things undo it automatically:
-- omarchy-recover-internal-monitor.service clears the flag at login when no
-- external is connected, and omarchy-hyprland-monitor-watch clears it the
-- moment the external goes away, including when the G5 drops off in standby.
-- Refusing to disable the only active display is built in. Unknown externals do
-- not trigger it, so a projector still mirrors the panel.
hl.on("monitor.added", function(monitor)
  if monitor.description:sub(1, #desk_description) == desk_description then
    hl.exec_cmd("omarchy-hyprland-monitor-internal off")
  end
end)

-- Closing the lid DOES need something configured, contrary to what this comment
-- claimed until 2026-09-25. logind reports Docked while an external display is
-- connected and HandleLidSwitchDocked defaults to ignore, so the lid close
-- itself is harmless -- but logind does not then forget the closed lid. It
-- installs a repeating re-check timer and re-asks "still docked?" roughly every
-- 30s for as long as the lid stays shut. Locking the screen turns the display
-- off, this monitor drops HDMI hot-plug detect a few seconds later, and the next
-- re-check finds no external display and applies HandleLidSwitch (stock default:
-- suspend). So locking the machine slept it, and an unattended agent run died at
-- the idle lock. files/systemd/logind.conf.d/30-lid-external-power.conf fixes it
-- with HandleLidSwitchExternalPower=ignore, installed by `just install-logind`.
-- Undocked and on battery the lid still suspends, which is what you want for a
-- laptop going into a bag.
--
-- The rest still holds: omarchy-system-lid-close skips the lock while docked,
-- and Hyprland's switch:on:Lid Switch bind runs omarchy-hyprland-monitor-clamshell,
-- which disables eDP-1 for as long as the lid is shut.
