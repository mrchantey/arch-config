-- silver-fox (Dell Precision 7560) — single internal 1080p panel.
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

hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "auto", scale = 1 })

-- Fallback auto-mirror: any external plugged in mirrors the internal panel. The
-- empty-output rule is Hyprland's fallback -- it applies to any monitor without
-- its own rule, so it catches whatever the cable enumerates as (HDMI-A-1 for the
-- HDMI port, DP-1..DP-5 depending on which port and which GPU). eDP-1 keeps its
-- explicit rule above.
--
-- Hyprland mirroring copies the SOURCE framebuffer and stretches it to fill the
-- target, so a mismatched aspect ratio distorts the image. On the XPS that was a
-- real problem (16:10 3840x2400 panel -> 16:9 projector, squished ~11%) and
-- scripts/silver-fox/present-mirror existed purely to force both ends to 1080p.
-- This panel is natively 16:9 1080p, so the plain rule below already produces a
-- 1:1 image on any 16:9 projector or TV; the script was deleted with the XPS.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })
