#!/bin/bash
# Take a photo with the webcam, save it, copy it to the clipboard and notify.
#
#   webcam-snap.sh [output.jpg]
#
# Saves to ~/Pictures/Webcam/webcam-<timestamp>.jpg unless given a path. The
# camera is the first capture-capable device from omarchy-capture-webcam-list,
# override with WEBCAM_DEVICE=/dev/videoN.
#
# Captures MJPEG at the camera's largest MJPEG size: YUYV is uncompressed and
# too slow over USB at full resolution (the Brio 100 only does 1080p as MJPEG),
# and the largest size differs per camera (1080p on silver-fox's Brio 100, 4K
# on rainbow-cat's BRIO). The first WARMUP seconds of frames are dropped so
# auto exposure and white balance can settle; a cold camera's first frame is
# close to black.
set -euo pipefail

readonly WARMUP=1.5

# resolves the camera, the first capture-capable device unless overridden
device="${WEBCAM_DEVICE:-$(omarchy-capture-webcam-list | awk 'NR == 1 { print $1 }')}"
if [[ -z $device ]]; then
	notify-send -u critical "Webcam" "No webcam found"
	exit 1
fi

# largest MJPEG frame size, by area
size="$(v4l2-ctl -d "$device" --list-formats-ext |
	awk '/\[[0-9]+\]:/ { mjpeg = /MJPG/ } mjpeg && /Size: Discrete/ { split($3, dims, "x"); print dims[1] * dims[2], $3 }' |
	sort -n | awk 'END { print $2 }')"

out="${1:-$HOME/Pictures/Webcam/webcam-$(date +%F_%H-%M-%S).jpg}"
mkdir -p "$(dirname "$out")"

# one capture at a time, a second press while the camera is busy is dropped
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/webcam-snap.lock"
flock -n 9 || exit 0

format_args=(-input_format mjpeg)
[[ -n $size ]] && format_args+=(-video_size "$size")
if ! err="$(ffmpeg -hide_banner -loglevel error -y -f v4l2 "${format_args[@]}" -i "$device" \
	-ss "$WARMUP" -frames:v 1 -update 1 -q:v 2 "$out" 2>&1)"; then
	notify-send -u critical "Webcam" "Capture from $device failed: $err"
	exit 1
fi

exec 9>&- # releases the camera lock, or the notification below would hold it
wl-copy --type image/jpeg <"$out"
echo "$out"

# clicking the notification opens the photo, without holding up the caller
(
	action="$(notify-send -i "$out" -A default=Open "Webcam photo saved" "$out, copied to clipboard")"
	[[ $action == default ]] && xdg-open "$out"
) >/dev/null 2>&1 &
