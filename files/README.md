# files/

Config that is tracked here but **copied** into place rather than stowed, because the owning app rewrites the file in a way that destroys a symlink, or because it lives outside `~`.

## omarchy/shell.json

The Omarchy shell config. Quattro replaced waybar (bar), walker + elephant (launcher), mako (notifications), swayosd (OSD) and hypridle + hyprlock (idle and lock) with one long-running Quickshell process, `omarchy-shell`, and this file configures all of it: bar layout, widget settings, idle and lock timings (`idle.screensaver`, `idle.lock`, in seconds). It hot-reloads on save. There is no display-off setting: `omarchy-system-lock` turns the display off itself.

It cannot be stowed because `omarchy-shell-config` writes it with `mktemp` + `mv`, which replaces a symlink with a regular file. Anything that edits the bar goes through that path (`omarchy bar move ...`, the bar settings panel, enabling or disabling a plugin), so a stowed copy would silently detach from this repo on the first tweak.

Workflow: edit here and `just stow-files`, or tweak in the GUI and `just pull-files` to capture it.

## systemd/logind.conf.d/

Drop-ins for `/etc/systemd/logind.conf.d/`, installed by `just install-logind` with root. `30-lid-external-power.conf` stops a closed lid on mains power from suspending the laptop; its header has the reasoning, and the diagnosis is in `docs/devices/silver-fox.md`.
