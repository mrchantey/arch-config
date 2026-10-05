#!/usr/bin/env bash
# ExecStart for kokoro-tts.service: launch the Kokoro-FastAPI server, choosing GPU vs
# CPU by power state the same way voxtype-render-config.sh does for whisper. On AC (or a
# desktop with no Mains adapter) run on the dGPU for instant synth; on battery force CPU
# (USE_GPU=false) so the NVIDIA dGPU can stay suspended — the laptop battery win that the
# voxtype gpu_isolation trick also protects. The torch build is the same CUDA wheel either
# way; only the device flag changes, so there is ONE venv, decided fresh at each service
# start (login, or `just restart-tts`), mirroring voxtype exactly.
set -uo pipefail

cd "${HOME}/.local/share/kokoro-fastapi" || exit 1

export USE_ONNX=false
export PYTHONPATH="${PWD}:${PWD}/api"
export MODEL_DIR=src/models
export VOICES_DIR=src/voices/v1_0
export WEB_PLAYER_PATH="${PWD}/web"
# Arch ships espeak-ng data here (the upstream CPU script hardcodes a Debian path);
# espeakng-loader bundles a fallback, but point at the system data when present.
[ -d /usr/share/espeak-ng-data ] && export ESPEAK_DATA_PATH=/usr/share/espeak-ng-data

# off-Mains detection: a type=Mains adapter reporting online=0. Wireless peripherals also
# report type=Battery and desktops have no Mains adapter, so both resolve to "not battery".
on_battery=0
for ps in /sys/class/power_supply/*; do
	[ -r "$ps/type" ] || continue
	[ "$(cat "$ps/type")" = "Mains" ] || continue
	[ -r "$ps/online" ] || continue
	[ "$(cat "$ps/online")" = "0" ] && on_battery=1
done

if [ "$on_battery" = "1" ]; then
	export USE_GPU=false
else
	export USE_GPU=true
	# free VRAM as soon as each tensor dies: torch's caching allocator otherwise holds the
	# peak of the longest read forever and starves voxtype's transcribe buffers (AGENTS.md)
	export PYTORCH_NO_CUDA_MEMORY_CACHING=1
fi

exec uv run --no-sync uvicorn api.src.main:app --host 127.0.0.1 --port 9000
