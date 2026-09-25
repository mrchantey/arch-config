#!/usr/bin/env bash
# Text-to-speech via the local Kokoro server. Two ways in:
#
#   1. Keybind/selection flow (mirror of the voxtype dictation flow): highlight
#      text, press the bind, hear it read; press again to stop. This is the
#      `toggle` mode, bound to SHIFT+PAUSE / SHIFT+INSERT in bindings.lua.
#   2. CLI flow: `tts gday mate` speaks the literal arguments; `echo hi | tts`
#      speaks stdin. Symlinked onto PATH as `tts` (see `just install-tts`).
#
# `tts stop` halts whatever is currently playing.
# `tts last` speaks the most recent reply from whichever coding agent is running in Zed,
# no highlighting needed — see scripts/acp-last.sh. Bound to CTRL+PAUSE / CTRL+INSERT.
#
# Kokoro streams raw 24kHz mono PCM, which we pipe straight into pw-play so audio
# starts as soon as the first chunk lands rather than after full synthesis.
#
# Two things sit between the synth and pw-play so the readback is actually audible
# over whatever else the machine is playing:
#
#   * A gain stage. Kokoro's PCM is quiet: measured on am_michael it peaks near
#     -6.7 dBFS and averages -27 dBFS RMS, which is 10-15 dB under typical music,
#     so at matched stream volumes the voice all but vanishes. ffmpeg's `speechnorm`
#     lifts it to about -17 dBFS RMS with peaks at -0.5 and no clipped samples. It is
#     causal (no lookahead), so it costs no measurable start latency. ffmpeg is
#     optional: without it the chain degrades to the old unprocessed audio.
#   * Ducking. Every other playback stream is turned down for the duration and put
#     back afterwards, since nothing else does this for us — Chrome and mpv set no
#     `media.role`, so WirePlumber's role-based linking has nothing to act on.
#
# GOTCHA: `wpctl get-volume`/`set-volume` speak the CUBIC scale, while PipeWire's
# own `channelVolumes` are linear amplitude — a stream wpctl calls 0.58 is 0.195 in
# `pw-dump`. So DUCK below is a cubic multiplier and lands near -13 dB, not -4 dB.
# Halving the wpctl number is a 18 dB cut, which reads as "the music stopped".
set -uo pipefail

PORT=9000
VOICE=am_michael
SPEED=1.5   # playback rate, 0.25-4.0 (1.0 = normal)
NODE_NAME=tts-readback   # our pw-play stream, so ducking can tell it apart from the rest
DUCK=0.6    # cubic multiplier applied to other streams while speaking (see GOTCHA above)
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tts"
mkdir -p "$runtime"
pidfile="$runtime/play.pid"
duckfile="$runtime/ducked"

# Turn every other playback stream down, recording what it was so unduck can put it
# back. Called before our own pw-play exists; the node.name filter is belt-and-braces
# for a previous readback that has not finished dying.
duck() {
	local id vol
	: >"$duckfile"
	while read -r id; do
		vol="$(wpctl get-volume "$id" 2>/dev/null | awk '{print $2}')"
		[ -n "$vol" ] || continue
		printf '%s %s\n' "$id" "$vol" >>"$duckfile"
		wpctl set-volume "$id" "$(awk -v v="$vol" -v d="$DUCK" 'BEGIN{printf "%.4f", v*d}')" 2>/dev/null || true
	done < <(pw-dump 2>/dev/null | jq -r --arg n "$NODE_NAME" '
		.[]
		| select(.info.props["media.class"] == "Stream/Output/Audio")
		| select(.info.props["node.name"] != $n)
		| .id')
}

# Idempotent: restoring twice writes the same numbers, which is what lets both the
# playback subshell's trap and stop() call it without coordinating.
unduck() {
	local id vol
	[ -f "$duckfile" ] || return 0
	while read -r id vol; do
		wpctl set-volume "$id" "$vol" 2>/dev/null || true
	done <"$duckfile"
	rm -f "$duckfile"
}

stop() {
	# kill the pipeline subshell and its children (curl + ffmpeg + pw-play) so sound halts now
	if [ -f "$pidfile" ]; then
		local pid
		pid="$(head -1 "$pidfile" 2>/dev/null)"
		if [ -n "$pid" ]; then
			pkill -TERM -P "$pid" 2>/dev/null || true
			kill -TERM "$pid" 2>/dev/null || true
		fi
		rm -f "$pidfile"
	fi
	unduck
}

playing() {
	[ -f "$pidfile" ] && kill -0 "$(head -1 "$pidfile" 2>/dev/null)" 2>/dev/null
}

# `exec` so ffmpeg replaces this pipeline subshell rather than sitting under it: that
# keeps it a direct child of the subshell, which is what stop()'s `pkill -P` reaches.
gain() {
	if command -v ffmpeg >/dev/null 2>&1; then
		# fatal, not error: tearing the pipe down on `tts stop` otherwise logs a
		# broken-pipe wall of text, while a genuine failure to start still speaks up.
		exec ffmpeg -hide_banner -loglevel fatal -f s16le -ar 24000 -ac 1 -i - \
			-af "speechnorm=e=6.25:r=0.0001:l=1" -f s16le -flush_packets 1 -
	fi
	exec cat
}

# fire the synth->playback pipeline in the background; clear the pidfile when it ends
# on its own so the next invocation starts fresh rather than thinking it's still playing.
speak() {
	local text="$1"
	{
		# TERM/INT exit, and exiting runs the EXIT trap, so every way out unducks
		trap unduck EXIT
		trap 'exit' TERM INT
		duck
		curl -sS -N -X POST "http://127.0.0.1:${PORT}/v1/audio/speech" \
			-H "Content-Type: application/json" \
			-d "$(jq -n --arg t "$text" --arg v "$VOICE" --argjson s "$SPEED" \
				'{model:"kokoro", input:$t, voice:$v, speed:$s, response_format:"pcm"}')" |
			gain |
			pw-play --raw --format=s16 --rate=24000 --channels=1 \
				-P "node.name=$NODE_NAME" -
		rm -f "$pidfile"
	} &
	echo "$!" >"$pidfile"
}

# Bare `tts` defaults to the keybind's toggle/selection flow, EXCEPT when stdin is
# piped in (`echo hi | tts`), in which case we speak that.
mode="${1:-toggle}"
if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
	mode="__cli__"
fi

case "$mode" in
	stop)
		stop
		exit 0
		;;
	last)
		# same toggle feel as the selection bind, but the text comes from the agent
		# transcript instead of the X selection: press to hear the last reply, press
		# again to shut it up.
		if playing; then
			stop
			exit 0
		fi
		text="$("$(dirname "$(readlink -f "$0")")/acp-last.sh" 2>/dev/null)"
		if [ -z "${text// /}" ]; then
			notify-send -a TTS "No agent reply" "Nothing captured yet from the Zed agent panel." 2>/dev/null || true
			exit 0
		fi
		;;
	toggle)
		# second press while still playing = stop; otherwise read the selection
		if playing; then
			stop
			exit 0
		fi
		text="$(wl-paste --primary --no-newline 2>/dev/null)"
		if [ -z "${text// /}" ]; then
			notify-send -a TTS "Nothing selected" "Highlight some text first." 2>/dev/null || true
			exit 0
		fi
		;;
	__cli__)
		# bare invocation with piped stdin: speak it
		text="$(cat)"
		if [ -z "${text// /}" ]; then
			echo "usage: tts <text>   |   <cmd> | tts   |   tts stop" >&2
			exit 1
		fi
		stop   # halt any in-flight playback before starting a new phrase
		;;
	*)
		# CLI: speak the literal arguments
		text="$*"
		if [ -z "${text// /}" ]; then
			echo "usage: tts <text>   |   <cmd> | tts   |   tts stop" >&2
			exit 1
		fi
		stop   # halt any in-flight playback before starting a new phrase
		;;
esac

speak "$text"
