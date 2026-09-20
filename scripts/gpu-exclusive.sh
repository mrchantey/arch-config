#!/usr/bin/env bash
# gpu-exclusive — run a command with the discrete GPU to itself.
#
#   gpu-exclusive <command> [args...]
#
# The voxtype daemon (whisper large-v3-turbo, ~1.5 GB) and the kokoro TTS server (~750 MB)
# keep their models resident on the GPU, which on a 4 GB card leaves no room for anything
# else. This stops whichever of those user services are running, runs the command, and
# restarts exactly the ones it stopped when the command exits, however it exits (error,
# Ctrl-C, kill). The command's exit status is passed through.
#
# Status lines go to stderr so the command's stdout can be piped or parsed. Nested calls
# are a no-op: GPU_EXCLUSIVE=1 is exported to the command, and a gpu-exclusive that sees
# it just execs. Override the service list with GPU_EXCLUSIVE_SERVICES (space separated),
# e.g. GPU_EXCLUSIVE_SERVICES=voxtype.service to leave kokoro playing.
set -uo pipefail

[[ $# -gt 0 ]] || { echo "usage: gpu-exclusive <command> [args...]" >&2; exit 2; }
[[ -n "${GPU_EXCLUSIVE:-}" ]] && exec "$@"

services="${GPU_EXCLUSIVE_SERVICES:-voxtype.service kokoro-tts.service}"
stopped=()

restore() {
	local s
	for s in "${stopped[@]}"; do
		# a stopped kokoro sits in "failed" (uvicorn exits non-zero on SIGTERM); start works from there
		systemctl --user start "$s" && echo "gpu-exclusive: restarted $s" >&2
	done
}
trap restore EXIT

for s in $services; do
	if systemctl --user is-active --quiet "$s"; then
		systemctl --user stop "$s" && stopped+=("$s") && echo "gpu-exclusive: stopped $s" >&2
	fi
done
[[ ${#stopped[@]} -gt 0 ]] && sleep 1   # let the driver release the VRAM

if command -v nvidia-smi >/dev/null 2>&1; then
	others="$(nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader 2>/dev/null || true)"
	[[ -n "$others" ]] && echo "gpu-exclusive: still on the GPU (not touched): ${others//$'\n'/; }" >&2
fi

export GPU_EXCLUSIVE=1
"$@"
