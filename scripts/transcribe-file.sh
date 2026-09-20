#!/usr/bin/env bash
# transcribe-file — transcribe an audio or video file with faster-whisper on the GPU.
#
#   transcribe-file <file> [--out BASE] [--title TEXT] [--model NAME] [--language xx] [--keep-gpu]
#
# Writes three files next to the input (or at --out BASE, a path without extension):
#   BASE.md             paragraphs of about a minute, each prefixed **[hh:mm:ss]**; the
#                       header names the model used. This is the one for agents to read.
#   BASE.srt            the same text as subtitles
#   BASE.segments.json  the same text as [{start, end, text}]
#
#   --title TEXT   heading for the markdown (default: the input filename)
#   --model NAME   skip the ladder and use one model: a faster-whisper size (large-v3,
#                  large-v3-turbo, medium, small.en, ...) or a local CTranslate2 model dir
#   --language xx  ISO 639-1 code (default: en; Whisper does not auto-detect here on purpose)
#   --keep-gpu     do not stop voxtype / kokoro first; transcribe with whatever VRAM is free
#
# The GPU is shared with the voxtype and kokoro daemons, so by default this re-runs itself
# under gpu-exclusive, which stops them and restarts them when this exits.
#
# Model ladder (unless --model): large-v3 int8_float16, large-v3-turbo float16, medium
# int8_float16, small.en float16. Rungs that need more VRAM than nvidia-smi reports free are
# skipped and a CUDA out-of-memory error moves to the next rung. On a 4 GB card the winner
# is large-v3-turbo: large-v3 shares turbo's encoder, whose working memory alone peaks near
# 3.5 GB, and its extra decoder weights do not fit; measured on the A2000, every large-v3
# configuration OOMs. Turbo does a 75 minute recording in about 2.5 minutes there.
#
# Setup is `just setup-transcribe-file` in ~/me/arch-config: a uv venv at
# ~/.local/share/whisper-venv with faster-whisper and the CUDA 12 runtime wheels (about
# 1.5 GB), plus the large-v3-turbo model in ~/.cache/huggingface (1.6 GB). Other models
# download on first use. This script builds the venv itself if it is missing.
set -euo pipefail

in=""; out=""; title=""; model=""; lang="en"; keep_gpu=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--title) title="$2"; shift 2 ;;
		--model) model="$2"; shift 2 ;;
		--language) lang="$2"; shift 2 ;;
		--keep-gpu) keep_gpu=1; shift ;;
		-h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) in="$1"; shift ;;
	esac
done
[[ -n "$in" ]] || { echo "usage: transcribe-file <file> [--out BASE] [--title TEXT] [--model NAME] [--language xx] [--keep-gpu]" >&2; exit 2; }
[[ -f "$in" ]] || { echo "no such file: $in" >&2; exit 2; }
[[ -n "$out" ]] || out="${in%.*}"
[[ -n "$title" ]] || title="$(basename "$in")"

here="$(dirname "$(readlink -f "$0")")"
if [[ "$keep_gpu" -eq 0 && -z "${GPU_EXCLUSIVE:-}" ]]; then
	exec "$here/gpu-exclusive.sh" "$0" "$in" --out "$out" --title "$title" --model "$model" --language "$lang" --keep-gpu
fi

venv="${WHISPER_VENV:-$HOME/.local/share/whisper-venv}"
if [[ ! -x "$venv/bin/python" ]]; then
	echo "transcribe-file: building $venv (first run; run \`just setup-transcribe-file\` to do this ahead of time)" >&2
	uv venv --quiet "$venv" -p 3.12
	uv pip install --quiet -p "$venv/bin/python" faster-whisper nvidia-cublas-cu12 nvidia-cudnn-cu12
fi
# CTranslate2 dlopens libcublas.so.12 and libcudnn*.so.9; point it at the wheel copies so the
# system CUDA install (or its absence) does not matter.
sp="$venv/lib/python3.12/site-packages/nvidia"
export LD_LIBRARY_PATH="$sp/cublas/lib:$sp/cudnn/lib:$sp/cuda_nvrtc/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# hf_xet transfers stalled indefinitely here (75 MB then nothing); plain HTTP is fine.
export HF_HUB_DISABLE_XET=1

wav="$(mktemp --suffix=.wav)"
trap 'rm -f "$wav"' EXIT
ffmpeg -v error -y -i "$in" -vn -ac 1 -ar 16000 "$wav"

"$venv/bin/python" - "$wav" "$out" "$title" "$model" "$lang" <<'PY' 2> >(grep -v HF_TOKEN >&2)
import gc, json, subprocess, sys, time
import ctranslate2
from faster_whisper import WhisperModel

wav, out, title, forced, lang = sys.argv[1:6]
gpu = ctranslate2.get_cuda_device_count() > 0

def free_vram_mib():
    try:
        return int(subprocess.check_output(["nvidia-smi", "--query-gpu=memory.free",
                                            "--format=csv,noheader,nounits"]).decode().split()[0])
    except Exception:
        return None

# (model, compute type, approx peak MiB with beam_size=5, measured on the A2000; large-v3 is
# an estimate since it never fit there)
if forced:
    ladder = [(forced, "float16" if gpu else "int8", 0)]
elif gpu:
    ladder = [("large-v3", "int8_float16", 4600), ("large-v3-turbo", "float16", 3300),
              ("medium", "int8_float16", 1800), ("small.en", "float16", 900)]
else:
    ladder = [("large-v3-turbo", "int8", 0), ("medium", "int8", 0), ("small.en", "int8", 0)]
free = free_vram_mib() if gpu else None

def srt_ts(s):
    h, r = divmod(s, 3600); m, s = divmod(r, 60)
    return f"{int(h):02d}:{int(m):02d}:{s:06.3f}".replace(".", ",")

def md_ts(s):
    h, r = divmod(int(s), 3600); m, s = divmod(r, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"

segs, used = None, None
for size, compute, need in ladder:
    if free is not None and need > free:
        print(f"skipping {size}: needs about {need} MiB free, have {free}", file=sys.stderr, flush=True)
        continue
    print(f"trying {size} ({compute}) on {'gpu' if gpu else 'cpu'}", file=sys.stderr, flush=True)
    t0 = time.time()
    try:
        model = WhisperModel(size, device="cuda" if gpu else "cpu", compute_type=compute)
        # VAD (Silero) cuts at silences so Whisper never sees a window of dead air, which is
        # where it hallucinates; beam 5 costs decoder memory but is worth it.
        gen, info = model.transcribe(wav, language=lang, beam_size=5, vad_filter=True,
                                     vad_parameters=dict(min_silence_duration_ms=500))
        segs = []
        for seg in gen:
            segs.append({"start": round(seg.start, 2), "end": round(seg.end, 2), "text": seg.text.strip()})
            if len(segs) % 100 == 0:
                print(f"  {seg.end/60:5.1f} min transcribed ({time.time()-t0:.0f}s)", file=sys.stderr, flush=True)
        used = (size, compute)
        break
    except RuntimeError as e:
        if "out of memory" not in str(e).lower():
            raise
        print(f"  {size} ran out of GPU memory, falling back", file=sys.stderr, flush=True)
        segs = None
        try: del model
        except NameError: pass
        gc.collect()
if segs is None:
    sys.exit("transcribe-file: no model in the ladder fit in GPU memory")
size, compute = used
print(f"transcribed with {size} ({compute}): {len(segs)} segments in {time.time()-t0:.0f}s", file=sys.stderr, flush=True)

with open(out + ".srt", "w") as srt:
    for i, s in enumerate(segs, 1):
        srt.write(f"{i}\n{srt_ts(s['start'])} --> {srt_ts(s['end'])}\n{s['text']}\n\n")
json.dump(segs, open(out + ".segments.json", "w"), indent=1)

# Markdown: one paragraph per ~60 s window (or at a question mark after 30 s), each
# prefixed with its start time so a reader can quote a position in the recording.
lines = [f"# Transcript: {title}", "",
         f"Auto-generated with faster-whisper ({size}, {compute}). Timestamps are hh:mm:ss from the start of the recording. Expect the usual speech-to-text errors in names and acronyms.", ""]
para, start = [], None
for s in segs:
    start = s["start"] if start is None else start
    para.append(s["text"])
    if s["end"] - start >= 60 or (s["text"].endswith(("?", "!")) and s["end"] - start >= 30):
        lines += [f"**[{md_ts(start)}]** " + " ".join(para), ""]
        para, start = [], None
if para:
    lines += [f"**[{md_ts(start)}]** " + " ".join(para), ""]
open(out + ".md", "w").write("\n".join(lines))
print(f"{out}.md")
PY
