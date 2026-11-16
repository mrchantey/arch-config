echo "starting up"
sleep 0.1
# always come up at full brightness. systemd-backlight@ saves the panel level at
# shutdown (/var/lib/systemd/backlight/) and restores it early in the next boot, so
# a laptop shut down at 47% wakes at 47% forever after. Nothing in omarchy touches
# display brightness at login (the shell only DPMS-blanks on idle), so setting it
# here, once Hyprland is up, is the last word. Runs as the user through logind's
# SetBrightness (we are not in `video`, and sysfs is root 644), which is the same
# path the XF86MonBrightness keybinds take. -d pins the internal panel so a docked
# monitor with a DDC backlight is never the one picked.
brightnessctl -d intel_backlight set 100% >/dev/null
# NOTE: mirror-watch.sh used to be launched here, to force both displays to 1080p
# when a projector was plugged in. That existed only to stop the XPS's 16:10 4K
# panel being squished onto a 16:9 projector. The Precision panel is natively
# 16:9 1080p, so the plain mirror rule in monitors.lua is already 1:1 and both
# scripts were deleted.
#
# the Logitech Brio 100 is the dictation mic here: the chassis has no working mic
# (camera-less SKU, see docs/devices/silver-fox.md), so voxtype hears through the
# webcam. It powers on at full-scale capture gain (wpctl 1.0 = hardware +30dB), and at
# that level the empty room alone sits at -25dBFS RMS, so speech clips hard and wrecks
# voxtype accuracy. The gain is cubic: total dB = 30 + 60*log10(vol), reaching the +6dB hardware floor at
# 0.40; below that WirePlumber adds software attenuation, which scales the noise floor
# down with the voice and buys nothing. 0.4 is the mic's minimum analog gain, a 24dB
# cut from power-on (measured 2026-09-11; re-tune procedure in docs/devices/silver-fox.md).
# Browser calls raised it mid-session until their AGC was flagged off, see
# docs/chromium-flags.md.
# mic-gain.sh has why it is set through WirePlumber and by node name.
"$(dirname "$(realpath "$0")")/../mic-gain.sh" '^alsa_input\.usb-046d_Brio_100_' 0.4 &
sleep 0.1
# quattro's hyprctl takes Lua, not the old bare-word dispatcher syntax.
hyprctl dispatch "hl.dsp.focus({ workspace = '1' })"
sleep 0.1
zed ~/me/beet
sleep 1
echo "done"
