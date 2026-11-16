#!/bin/bash
# Set a mic's capture gain through WirePlumber, targeting its node by name.
#
#   mic-gain <node-name-regex> <volume>
#
# Through WirePlumber rather than amixer: WirePlumber owns the gain and re-applies
# its saved value when it initializes the card, clobbering any amixer call that
# races ahead of it. What it sets it persists per device
# (~/.local/state/wireplumber/default-routes), so the value also survives replug.
#
# By name rather than @DEFAULT_AUDIO_SOURCE@: with the intended mic unplugged the
# default falls to another source, which would get a gain calibrated for different
# hardware. wpctl only takes IDs, so the name is resolved through pw-dump. Leave
# the serial out of the regex so a replacement unit is covered too.
#
# Polls for up to 10s, since WirePlumber may still be starting at login or the mic
# may not be plugged in; callers background it so that never holds up startup.
set -u

if [[ $# -ne 2 ]]; then
	echo "usage: mic-gain <node-name-regex> <volume>" >&2
	exit 2
fi

name_re=$1
volume=$2

for _ in $(seq 1 50); do
	id="$(pw-dump 2>/dev/null | jq -r --arg re "$name_re" '.[] | select(.type == "PipeWire:Interface:Node" and (.info.props["node.name"] // "" | test($re))) | .id' | head -1)"
	[[ -n $id ]] && wpctl set-volume "$id" "$volume" >/dev/null 2>&1 && exit 0
	sleep 0.2
done
echo "mic-gain: no node matching $name_re" >&2
exit 1
