#!/usr/bin/env bash
# transcribe — capture mic audio and transcribe it for later review.
#
# Records 16kHz/mono WAV (the format `voxtype transcribe` expects, so no resampling)
# to <name>.wav in the current directory, then writes the transcript to <name>.txt.
#
#   transcribe          -> out.wav  + out.txt
#   transcribe myclip    -> myclip.wav + myclip.txt
#
# Controls while running:
#   SPACE  pause / resume
#   ENTER  stop, then transcribe
#
# Pause is implemented by recording discrete segments and concatenating them on stop,
# so the saved clip (and the length reported below) contains only actually-recorded
# audio — paused time is excluded.
#
# GPU note: the voxtype daemon keeps the Whisper model resident on the discrete GPU,
# and on a 4GB card a second copy won't fit — so a bare `voxtype transcribe` silently
# falls back to the (much slower) integrated GPU. The transcribe step runs under
# gpu-exclusive (scripts/gpu-exclusive.sh), which stops the daemon, and brings it back
# when the step exits; we pin the same GPU the daemon uses (read from its systemd drop-in).
# For transcribing existing files, use `transcribe-file` instead.

set -euo pipefail

name="${1:-out}"
name="${name%.wav}"            # tolerate `transcribe foo.wav`
out="${name}.wav"
txt="${name}.txt"

workdir="$(mktemp -d)"
segments=()
seg_index=0
rec_pid=""
paused=0

cleanup() {
	[[ -n "$rec_pid" ]] && kill -INT "$rec_pid" 2>/dev/null || true
	rm -rf "$workdir"
}
trap cleanup EXIT

start_segment() {
	seg_index=$((seg_index + 1))
	local seg
	seg="$(printf '%s/seg-%03d.wav' "$workdir" "$seg_index")"
	segments+=("$seg")
	pw-record --rate 16000 --channels 1 --format s16 "$seg" >/dev/null 2>&1 &
	rec_pid=$!
}

stop_segment() {
	[[ -z "$rec_pid" ]] && return
	kill -INT "$rec_pid" 2>/dev/null || true
	wait "$rec_pid" 2>/dev/null || true
	rec_pid=""
}

printf 'Recording to %s — SPACE = pause/resume, ENTER = stop.\n' "$out"
start_segment
printf '\xe2\x97\x8f recording...\n'

while true; do
	IFS= read -rsn1 key || true
	if [[ -z "$key" ]]; then
		break                                   # ENTER
	elif [[ "$key" == " " ]]; then
		if [[ "$paused" -eq 0 ]]; then
			stop_segment
			paused=1
			printf '\xe2\x8f\xb8 paused — SPACE to resume, ENTER to stop.\n'
		else
			start_segment
			paused=0
			printf '\xe2\x97\x8f recording...\n'
		fi
	fi
done

stop_segment

# Keep only segments that actually captured audio.
real_segments=()
for s in "${segments[@]}"; do
	[[ -s "$s" ]] && real_segments+=("$s")
done

if [[ ${#real_segments[@]} -eq 0 ]]; then
	printf 'No audio captured.\n' >&2
	exit 1
fi

if [[ ${#real_segments[@]} -eq 1 ]]; then
	cp -f "${real_segments[0]}" "$out"
else
	concat_list="$workdir/concat.txt"
	: > "$concat_list"
	for s in "${real_segments[@]}"; do
		printf "file '%s'\n" "$s" >> "$concat_list"
	done
	ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$concat_list" -c copy "$out"
fi

dur="$(ffprobe -hide_banner -loglevel error -show_entries format=duration -of csv=p=0 "$out")"
printf 'Saved %s (%.1fs)\n' "$out" "$dur"

# Pin the same GPU the daemon uses (its drop-in is generated per device, so this
# stays correct across machines). Use exactly ONE selector: GGML_VK_VISIBLE_DEVICES
# if present, else VOXTYPE_VULKAN_DEVICE. Passing both poisons the CLI's GPU pick and
# silently drops it to CPU (~15x slower). Empty array => plain `env`, harmless.
gpu_conf="$HOME/.config/systemd/user/voxtype.service.d/gpu.conf"
gpu_env=()
if [[ -f "$gpu_conf" ]]; then
	ggml="$(sed -n 's/^Environment="\(GGML_VK_VISIBLE_DEVICES=[^"]*\)"$/\1/p' "$gpu_conf" | head -1)"
	vox="$(sed -n 's/^Environment="\(VOXTYPE_VULKAN_DEVICE=[^"]*\)"$/\1/p' "$gpu_conf" | head -1)"
	if [[ -n "$ggml" ]]; then
		gpu_env=("$ggml")
	elif [[ -n "$vox" ]]; then
		gpu_env=("$vox")
	fi
fi

printf 'Transcribing...\n'
# only voxtype needs to go: the CLI's turbo model fits beside kokoro, and stopping kokoro
# would cut off any speech it is playing.
GPU_EXCLUSIVE_SERVICES=voxtype.service \
	"$(dirname "$(readlink -f "$0")")/gpu-exclusive.sh" env "${gpu_env[@]}" voxtype -q transcribe "$out" 2>/dev/null \
	| awk 'flag; /^[[:space:]]*$/{flag=1}' > "$txt"

printf 'Transcript -> %s\n' "$txt"
