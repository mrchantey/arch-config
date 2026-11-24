#!/usr/bin/env bash
# Render voxtype's runtime config from the shared, stow-managed config.toml plus this
# machine's overrides. The daemon reads the result via -c, never the stowed file, so the
# shared dictionary and settings stay one file while each device and power state can
# differ. Run as voxtype.service's ExecStartPre, so the choice is made each time the
# daemon starts (login, or `just restart-voxtype`), and by `just setup-voxtype` to learn
# which model to download.
#
# Overrides, applied in order through `voxtype config set`, which type-checks each key:
#
# 1. `devices/<hostname>.toml` next to config.toml, if present: dotted `key = value`
#    lines, ie `whisper.model = "small.en"`. Keys come from `voxtype config schema`.
# 2. On battery, `whisper.gpu_isolation = true`: each clip runs in a short-lived worker
#    that releases the dGPU between uses so it can suspend, at the cost of a ~1.7s
#    spin-up that swallows the start of short push-to-talk clips. On AC, or a desktop
#    with no AC adapter, the model stays warm for instant capture.
#
# Battery detection keys off a type=Mains adapter being offline, NOT "a battery exists":
# wireless peripherals (mouse/keyboard) also report as type=Battery, and desktops have no
# Mains adapter at all, so both correctly resolve to "not on battery".
set -euo pipefail

src_dir="${HOME}/.config/voxtype"
dst="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voxtype/config.toml"
device="${src_dir}/devices/$(hostname).toml"

mkdir -p "$(dirname "$dst")"
cp "${src_dir}/config.toml" "$dst"

# set one dotted key in the rendered copy, logging it to the journal
set_key() {
	voxtype -c "$dst" config set "$1" "$2" >/dev/null
	echo "voxtype-render-config: $1 = $2"
}

# 1. device overrides: strip comments, blank lines and quotes around the value
if [ -f "$device" ]; then
	while IFS='=' read -r key value; do
		key="$(echo "$key" | xargs)"
		value="$(echo "$value" | xargs)"
		set_key "$key" "$value"
	done < <(grep -E '^[[:space:]]*[a-z_.]+[[:space:]]*=' "$device")
fi

# 2. power state
on_battery=0
for ps in /sys/class/power_supply/*; do
	[ -r "$ps/type" ] || continue
	[ "$(cat "$ps/type")" = "Mains" ] || continue
	[ -r "$ps/online" ] || continue
	[ "$(cat "$ps/online")" = "0" ] && on_battery=1
done
if [ "$on_battery" = "1" ]; then
	set_key whisper.gpu_isolation true
fi
