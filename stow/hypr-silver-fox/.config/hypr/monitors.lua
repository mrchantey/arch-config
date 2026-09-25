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

-- scale 1, NOT omarchy's "auto". On this panel auto picks 1.5, which leaves a
-- 1280x720 logical desktop -- unusably cramped. At scale 1 the logical desktop is
-- 1920x1080, near-identical to what the retired XPS gave (4K panel at scale 2 =
-- 1920x1200), so the workspace stays the size it has always been. This is a
-- 1080p panel, so there is no HiDPI to serve and no fractional-scaling blur to
-- accept. Bump to 1.25 if the text is too small; do not go back to "auto".
hl.env("GDK_SCALE", "1")

local desk = "desc:Samsung Electric Company Odyssey G5"

hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "auto", scale = 1 })

-- The desk monitor, matched by description rather than port so it does not
-- matter which cable or which GPU it lands on (today it enumerates as HDMI-A-1,
-- which is on the NVIDIA card). 2560x1440@144 is its top mode; 16:9 at ~109 DPI,
-- so scale 1, same as the panel.
--
-- Naming it explicitly is what opts it OUT of the mirror fallback below: this is
-- a second desktop, not a duplicate of the laptop panel. A monitor with its own
-- rule never falls through to the empty-output rule, whatever the order here.
hl.monitor({ output = desk, mode = "2560x1440@144", position = "auto", scale = 1 })

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

-- Turning the laptop panel off while docked is NOT done here. A `disabled = true`
-- on eDP-1 would leave this machine with no display at all when it is unplugged,
-- so it is a runtime toggle instead: `omarchy hyprland monitor internal off`
-- (Super+Ctrl+Delete), which writes hl.monitor({ output = "eDP-1", disabled =
-- true }) into ~/.local/state/omarchy/toggles/hypr/internal-monitor-disable.lua.
-- default.hypr.toggles loads that directory last, so it lands on top of this
-- file. The state survives reboots, and two things undo it automatically:
-- omarchy-recover-internal-monitor.service clears the flag at login when no
-- external is connected, and omarchy-hyprland-monitor-watch clears it when the
-- monitor is unplugged. Refusing to disable the only active display is built in.
--
-- Closing the lid needs nothing configured either. logind reports Docked while
-- any external display is connected, and HandleLidSwitchDocked defaults to
-- ignore, so a docked lid close does not suspend; omarchy-system-lid-close
-- checks the same condition and skips the lock. Hyprland's own
-- switch:on:Lid Switch bind then runs omarchy-hyprland-monitor-clamshell, which
-- disables eDP-1 for as long as the lid is shut. Undocked, the lid still
-- suspends, which is the behaviour you want for a laptop going into a bag.
