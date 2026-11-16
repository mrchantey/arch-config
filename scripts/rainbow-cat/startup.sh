echo "starting up"
sleep 0.1
# the Logitech BRIO 4K is the dictation mic. It powers on at full-scale capture gain
# (wpctl 1.0 = hardware +54dB), which clips hard and wrecks voxtype accuracy. The
# BRIO's gain is cubic: total dB = 54 + 60*log10(vol), clamped at the +18dB hardware
# floor below ~0.25. 0.30 maps to hardware +22.6dB, calibrated against real speech
# (emphatic peaks ~-12dBFS, ample headroom) at 0.35, then dropped a further 4dB on
# 2026-09-17 after clipping resurfaced. Browser calls raised it mid-session until
# their AGC was flagged off, see docs/chromium-flags.md; this re-asserts it at every
# login. mic-gain.sh has why it is set through WirePlumber and by node name: the
# motherboard's analog input is also a source here.
"$(dirname "$(realpath "$0")")/../mic-gain.sh" '^alsa_input\.usb-046d_Logitech_BRIO_' 0.30 &
sleep 0.1
# quattro's hyprctl takes Lua, not the old bare-word dispatcher syntax.
hyprctl dispatch "hl.dsp.focus({ workspace = '1' })"
sleep 0.1
zed ~/me/beet
