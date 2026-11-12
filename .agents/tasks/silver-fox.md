# Handoff: silver-fox

## 2026-11-12 updated shell layout (from rainbow-cat)

`files/omarchy/shell.json` now uses Omarchy's split `centerBegin` / `center` / `centerEnd` layout instead of `centerAnchor`, keeping the clock centered. It preserves rainbow-cat's updated Elsewhen cities and Voxtype settings plugin, restores `pete.workspaces`, and keeps the repo's idle timings. The compose source also preserves rainbow-cat's local `poopie` expansion. See AGENTS.md, "The bar, launcher, and idle are one Quickshell process".

- [ ] `omarchy-version`, check the installed version; rainbow-cat validated this config on 4.5.0-3
- [ ] (ask first, only if this machine still predates the split-center layout) `omarchy update`, then reconcile with the `os-update` skill before copying the newer shell config
- [ ] Compare `~/.config/omarchy/shell.json` with `files/omarchy/shell.json`, preserving any deliberate local settings before replacement
- [ ] `just stow-files`, applies the copied shell config
- [ ] `omarchy restart shell`, reloads the bar and plugins
- [ ] `omarchy-restart-xcompose`, reloads the compose expansion
- [ ] `hyprctl reload && hyprctl configerrors`, expect no errors

Verify: `omarchy-shell shell ping` prints `ok`; the clock is centered and the synced-workspace buttons appear. Check `omarchy-shell shell listPlugins` for enabled `pete.workspaces` and, if installed, `io.voxtype.settings`. CapsLock space p types `poopie`.
