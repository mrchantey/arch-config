#!/bin/bash
# Super+Shift+W counts highlighted text via Wayland's primary selection, leaving
# the regular clipboard untouched. Apps must publish their selection, as for TTS.
# Words are whitespace-separated, like wc -w, including any Markdown markup.
# Dependencies: wl-clipboard, libnotify (just install-apps) and base coreutils.
set -euo pipefail

# A clipboard owner can stop responding. Bound the read and never fall back to
# the regular clipboard, which could silently count unrelated or sensitive text.
if ! count=$(timeout 2s wl-paste --primary --no-newline --type text 2>/dev/null | wc -w); then
  notify-send -a "Word count" -t 5000 "No selection available" \
    "Highlight text in an app that supports Linux's selection clipboard."
  exit 0
fi

count=$((count))
if ((count == 0)); then
  notify-send -a "Word count" -t 5000 "No words selected" "Highlight some text first."
else
  word="words"
  if ((count == 1)); then
    word="word"
  fi
  notify-send -a "Word count" -t 5000 "$count $word selected"
fi
