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

## 2026-11-13 backup scope and Claude metadata (from rainbow-cat)

Downloads is temporary and excluded from backups, see AGENTS.md, "Backups". The next successful mirror removes any old Downloads objects from the active device prefix; version history retains them for its existing 90-day period. `beet_egress` commit `21ccf76` preserves Claude Code's `accountUuid`, `organizationUuid` and `tools` fields without relaxing strict validation. All 44 egress tests and real ingestion passed on rainbow-cat, and its full backup succeeded.

- [ ] Check `git -C ~/me/beet status --short`, `git -C ~/me/beet_atproto status --short` and `git -C ~/me/beet_egress status --short`; preserve local work before updating, never reset it
- [ ] `git -C ~/me/beet pull --ff-only`, updates the shared dependency; stop and reconcile if it is dirty or diverged
- [ ] `git -C ~/me/beet_atproto pull --ff-only`, updates the sibling path dependency
- [ ] `git -C ~/me/beet_egress pull --ff-only`, picks up the parser fix
- [ ] `rustc --version`, Bevy 0.20 requires Rust 1.97.1 or newer
- [ ] (ask first, only if the default nightly is too old) `rustup update nightly`, preserves installed components and targets while upgrading the compiler
- [ ] `just backup --dry-run`, verify `target/backup/silver-fox/Downloads` is absent
- [ ] `just backup`, verify egress and upload both succeed; a failed old cached parser triggers a rebuild from the updated source
- [ ] `just install-backup-timer`, ensures the hourly due-check timer is enabled

Verify: `cat ~/.local/state/backup/last-run` prints `ok`, `systemctl --user list-timers backup.timer` shows the next firing, and the staged backup contains no Downloads. The saved stock runner now explicitly changes to the config repo, so it also works when systemd launches it from home.

## 2026-11-14 dynamic Zed workspace labels (from rainbow-cat)

`pete.workspaces` now labels each workspace group with its most recently focused Zed project while retaining numeric shortcuts. See AGENTS.md, "Workspaces switch on every monitor together". The existing `omarchy` stow package includes the helper and tests, so fresh installs need no new recipe.

- [ ] `stow -d stow -t /home/pete -R omarchy`, links the widget's new helper even if the plugin directory is unfolded; run from `~/me/arch-config`
- [ ] `omarchy restart shell`, clears Qt's cached workspace widget
- [ ] `omarchy-shell shell ping`, expect `ok`

Verify: the bar shows labels such as `2 arch-config`, with the active workspace colored and underlined. Changing the file within a Zed project leaves its project label stable; moving its window to another workspace transfers the label. With multiple screens, the same group shows the same label on each bar.
