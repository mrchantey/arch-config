#!/bin/bash
# Turn the laptop panel back on before suspend, while docking has it off.
#
# Suspending with the desk monitor as the only enabled output does not come
# back: on resume the kernel refuses every frame Hyprland sends to HDMI-A-1
# ("atomic drm request: failed to commit: Invalid argument") and both screens
# stay blank. With eDP-1 enabled at suspend time the same resume is clean (both
# tested 2026-10-06). monitors.lua turns the panel off whenever the desk monitor
# connects, through Omarchy's manual toggle, so this clears that toggle for the
# sleep; the monitor reconnecting on resume turns the panel off again.
#
# Same shape as Omarchy's omarchy-system-sleep-monitor: hold a delay inhibitor,
# act on PrepareForSleep, then exit to release it and let systemd restart us.

toggle=internal-monitor-disable

panel_enabled() {
  hyprctl monitors -j 2>/dev/null | jq -e 'any(.[]; .name == "eDP-1")' >/dev/null
}

# clear the toggle (which reloads Hyprland), then hold the suspend until the
# panel is up, bounded well inside logind's inhibit window
prepare_for_sleep() {
  omarchy-hyprland-toggle-enabled "$toggle" || return 0
  omarchy-hyprland-toggle "$toggle" off >/dev/null

  for _ in $(seq 1 30); do
    panel_enabled && return 0
    sleep 0.1
  done
}

consume_sleep_events() {
  local line

  while IFS= read -r line; do
    if [[ $line == *"boolean true"* ]]; then
      prepare_for_sleep
      return 0
    fi
  done
}

if [[ ${1:-} == --inhibited ]]; then
  coproc SLEEP_EVENTS {
    exec dbus-monitor --system \
      "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
  }
  consume_sleep_events <&"${SLEEP_EVENTS[0]}"
  kill "$SLEEP_EVENTS_PID" 2>/dev/null
  exit 0
fi

exec systemd-inhibit \
  --what=sleep \
  --mode=delay \
  --who=silver-fox \
  --why="Re-enable the laptop panel before suspend" \
  "$0" --inhibited
