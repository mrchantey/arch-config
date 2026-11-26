## 2026-11-26 WirePlumber state tracked per device (from silver-fox)

WirePlumber's saved per-app volumes now live in the device package, so an app silently turned down shows up in git. silver-fox found Chrome saved at about -28 dB. See the comment on `stow-device` in `justfile`.

- [ ] `just stow-device rainbow-cat`, stops WirePlumber, moves `~/.local/state/wireplumber` into `stow/hypr-rainbow-cat/.local/state/wireplumber`, folds it back as a directory symlink and restarts WirePlumber (audio drops for a moment)
- [ ] (ask first) review `stream-properties` for apps saved well below 1.0 and offer to reset them; reset one by setting its stream to 100% in a mixer while it plays, never by editing the file while WirePlumber runs
- [ ] commit `stow/hypr-rainbow-cat/.local/state/wireplumber/stream-properties`, the package's `.gitignore` keeps the rest untracked

Verify: `readlink ~/.local/state/wireplumber` points into `stow/hypr-rainbow-cat`; after changing an app's volume in a mixer, `git status` shows `stream-properties` modified.
