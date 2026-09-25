-- Shared input config across all devices.
-- Per-device overrides (left_handed, touchpad gestures, etc.) live in each
-- device package's input-device.lua, required AFTER this file so they win.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
--
-- Dropped in the quattro port because Omarchy now sets them by default:
-- cursor.hide_on_key_press and misc.focus_on_activate (default/hypr/looknfeel.lua).

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:caps", -- ,grp:alts_toggle for layout switching

    -- Keyboard repeat
    repeat_rate = 40,
    repeat_delay = 600,

    touchpad = {
      -- Scroll speed (shared); per-device gestures live in input-device.lua
      scroll_factor = 0.4,
    },
  },

  misc = {
    mouse_move_focuses_monitor = false,
  },
})

-- Pointer speed, one hl.device block per pointer. A block only overrides what it
-- names: unset fields fall back to the global `input` section above, verified by
-- giving a keyboard a device block that sets only repeat_rate and watching it
-- keep the global kb_options in `hyprctl devices`. So rainbow-cat's global
-- left_handed still reaches any pointer configured below.
--
-- libinput normalises mouse motion against MOUSE_DPI from udev's hwdb and assumes
-- 1000 DPI when there is no entry. None of the pointers below have one (nothing
-- matches 047d:80a6 or 046d:c084 in 70-mouse.hwdb), so raw counts pass through
-- unscaled and `sensitivity` is the whole of the tuning.
--
-- Checking that a block landed is not obvious. `hyprctl devices` prints
-- "default speed: 0.00000" for every mouse; that is libinput's *hardware* default
-- and never tracks what we set here, so it proves nothing either way. "scroll
-- factor" in the same output does track config, which makes it the probe for a
-- device name in doubt:
--   hyprctl eval 'hl.device({ name = "<name>", scroll_factor = 0.5 })'
--   hyprctl devices   # 0.50 means the name matched; hyprctl reload undoes it
-- The same eval is how to try a sensitivity live before committing a number here.

-- Kensington Orbit trackball.
-- flat profile = constant factor, no acceleration (a velocity-based custom curve
-- made the pointer jump on the first move). With flat, the factor is
-- 1 + sensitivity, so -0.8 is a fifth of raw movement.
-- One block per connection type (USB dongle vs Bluetooth); only the block
-- matching the connected device applies, so both are harmless everywhere.
-- left_handed = true swaps the primary/secondary buttons for left-handed use.
--
-- sensitivity is the only speed lever this trackball has, which is why the number
-- is the thing to turn when it feels wrong. Cycling DPI on the device itself does
-- nothing: over the dongle it declares five buttons plus the wheel axes and
-- nothing else (KEY=1f0000 on its evdev node; the second node it creates is plain
-- consumer-control media keys), so no DPI control reaches the host, and the
-- pointer speed does not shift either, so the firmware is not switching in
-- private. DPI selection on these trackballs is a KensingtonWorks (Windows and
-- macOS) feature with no Linux counterpart.

-- USB dongle
hl.device({
  name = "kensington-orbit-wireless-tb-mouse",
  accel_profile = "flat",
  sensitivity = -0.8,
  left_handed = true,
})

-- Bluetooth
hl.device({
  name = "orbit-bt5.0-mouse",
  accel_profile = "flat",
  sensitivity = -0.8,
  left_handed = true,
})

-- Logitech MX Ergo (thumb trackball, 320 DPI): same treatment as the Orbit.
-- The adaptive profile is what makes it feel wild, a thumb flick spins the ball
-- fast enough to trip the acceleration curve, so flat matters more than the
-- factor. -0.6 lands the effective DPI near the Orbit's; tune to taste.
-- Right-hand-only shape, so no left_handed swap.

-- Bluetooth (the Unifying dongle enumerates under a different name; add a
-- second block for it if that ever gets used, same as the Orbit above)
hl.device({
  name = "mx-ergo-mouse",
  accel_profile = "flat",
  sensitivity = 0.5
})

-- Logitech G102/G203 (046d:c084), the plugged-in mouse used left-handed.
-- A plain mouse, so it keeps libinput's adaptive profile rather than going flat
-- like the trackballs above: acceleration is what lets slow precision and fast
-- traverses coexist, and nothing flicks a mouse the way a ball gets flicked, so
-- the curve never runs away. sensitivity shifts that curve down, it does not
-- flatten it.
-- Unlike the Orbit this one does switch DPI in firmware, on the button behind the
-- scroll wheel, with no G HUB involved, and that happens before libinput sees
-- anything. So reach for the button before turning the number below.
-- Buttons are deliberately left unset: that inherits, which keeps rainbow-cat's
-- global swap and leaves this machine unswapped, as it was before this block.
-- The `-keyboard-1` node `hyprctl devices` also lists under mice is this mouse's
-- media-key interface and generates no motion, so there is nothing to set on it.
hl.device({
  name = "logitech-g102-prodigy-gaming-mouse",
  sensitivity = -0.3,
})
