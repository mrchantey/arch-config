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
# (camera-less SKU, see the info-silver-fox skill), so voxtype hears through the
# webcam. It powers on at full-scale capture gain (wpctl 1.0 = hardware +30dB), and at
# that level the empty room alone sits at -25dBFS RMS, so speech clips hard and wrecks
# voxtype accuracy. amixer can't fix this: WirePlumber owns the gain and re-applies its
# saved value when it initializes the card, clobbering any amixer call that races ahead
# of it. Set the gain THROUGH WirePlumber instead -- it persists per device
# (~/.local/state/wireplumber/default-routes) and restores it on every boot AND replug.
# The gain is cubic: total dB = 30 + 60*log10(vol), reaching the +6dB hardware floor at
# 0.40; below that WirePlumber adds software attenuation, which scales the noise floor
# down with the voice and buys nothing. 0.4 is the mic's minimum analog gain, a 24dB
# cut from power-on (measured 2026-09-11; re-tune procedure in the info-silver-fox skill).
# Browser calls raised it mid-session until their AGC was flagged off, see "Browser calls
# must not move the mic gain" in AGENTS.md.
#
# Targeted by node NAME, not @DEFAULT_AUDIO_SOURCE@. The old line set the default source
# to 0.13, the internal Realtek calibration carried over from the XPS, and with the Brio
# now the default source that would have landed it 29dB below its own hardware floor.
# The Realtek line is gone: there is no mic behind that codec on this machine. wpctl
# only takes IDs, so the name is resolved through pw-dump. The serial is left out of the
# match so a replacement unit is covered too. Backgrounded so a login without the camera
# plugged in (10s of polling) does not hold up the rest of startup.
(
	for _ in $(seq 1 50); do
		id="$(pw-dump 2>/dev/null | jq -r '.[] | select(.type == "PipeWire:Interface:Node" and (.info.props["node.name"] // "" | test("^alsa_input\\.usb-046d_Brio_100_"))) | .id' | head -1)"
		[ -n "$id" ] && wpctl set-volume "$id" 0.4 >/dev/null 2>&1 && break
		sleep 0.2
	done
) &
sleep 0.1
# quattro's hyprctl takes Lua, not the old bare-word dispatcher syntax.
hyprctl dispatch "hl.dsp.focus({ workspace = '1' })"
sleep 0.1
zed ~/me/beet
sleep 1
echo "done"
