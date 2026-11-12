# Handoff: rainbow-cat

## 2026-10-07 synced workspaces (from silver-fox)

Switching workspace now switches both monitors together: the ultrawide (leftmost, so primary) shows 1-10 and the side monitor 11-20. See "Workspaces switch on every monitor together" in AGENTS.md. Until step 1 runs, Hyprland's auto-reload fails on the missing `hypr.workspaces` module, which drops every bind after it in `bindings.lua`.

- [x] `just stow-symlinks`, links the new `~/.config/hypr/workspaces.lua`, creates `~/.config/omarchy/plugins` and links the `pete.workspaces` bar widget into it
- [x] `just stow-files`, copies `shell.json`, which now puts `pete.workspaces` on the bar in place of `omarchy.workspaces`
- [x] `hyprctl reload && hyprctl configerrors`, expect no errors
- [x] `omarchy restart shell`, the shell does not reliably hot-load a new plugin

2026-11-12: applied on Omarchy 4.5.0-3. Config errors are empty, the shell reports `pete.workspaces` loaded and visible, and switching workspace then restoring it passes. Only the C49RG9x is connected, so the two-monitor checks below remain pending.

Verify:

- `hyprctl monitors -j | jq -c '.[] | {description, x, ws: .activeWorkspace.id}'` shows the C49RG9x at x 0 and the C24F390 at x 4096, with the side monitor on the ultrawide's workspace + 10.
- Super+3 shows 3 on the ultrawide and 13 on the side monitor, with focus staying on whichever monitor had it, and the bar marks 3 on both screens even with focus on the side monitor.
- With two windows on the side monitor, the master column is on the left. This comes from the new `workspace = "m[desc:Samsung Electric Company C24F390]"` rule in `monitors.lua`, which was only syntax-checked on silver-fox. If it does not apply, report it rather than going back to pinned workspace ids.
- Windows that were on the side monitor's old workspaces 7-10 now come up on the ultrawide when those numbers are shown; Super+Shift+Alt+Right swaps them back onto the side monitor.

## 2026-10-07 codex CLI (from silver-fox)

The Codex CLI is now kept alongside claude and gh rather than stripped as a preinstall, see "Dev tooling goes through mise" in AGENTS.md. The desktop app (`openai-codex-desktop`) stays uninstalled. Codex and Claude Code now both read the shared global instructions through links in the `agents` package, see "Agent instructions and skills live in `.agents`" in AGENTS.md.

- [ ] `just install-mise-tools`, rewrites the mise wrappers, now including `~/.local/bin/codex`
- [ ] `codex --version`, first run installs the binary through mise
- [x] `just stow-symlinks`, links `~/.codex/AGENTS.md` and moves `~/.claude/CLAUDE.md` from the `claude` package to the `agents` package (stow unlinks the old, now dangling, link itself)

Verify:

- `codex --version` prints `codex-cli <version>`, and `pacman -Q openai-codex-desktop` reports it is not installed.
- `readlink ~/.codex/AGENTS.md ~/.claude/CLAUDE.md` shows both under `stow/agents/`, and `cmp ~/.codex/AGENTS.md ~/.agents/AGENTS.md` is silent.
- `cd /tmp && codex debug prompt-input hi | grep -c 'Beet is an Atmospheric'` prints at least 1, ie Codex loads the global instructions.

## 2026-10-07 codex voice capture fix (from silver-fox)

Codex's `/voice` dropped most of the mic audio whenever the PipeWire graph ran above a 1024 quantum, so the model never answered. A new `pipewire` stow package caps Codex's voice host at 1024-frame periods. See "Codex voice needs small capture chunks" in AGENTS.md.

- [x] `ls -la ~/.config/pipewire`, confirmed missing before linking on 2026-11-12
- [x] `just stow-symlinks`, links `~/.config/pipewire` to the new package

Verify: start `codex`, run `/voice`, and while it listens `pw-top -b -n 3 | grep codex-voice-host` shows quantum 1024 (not 2048 or 2400). Then say something and confirm it transcribes and answers. This machine's mic differs from silver-fox's Brio, so the end-to-end check is the real test here.

## 2026-10-07 restore LibreOffice (from silver-fox)

The shared preinstall cleanup no longer removes LibreOffice, and fresh installs explicitly install it. Existing machines need to restore it if a previous cleanup removed it, see "Preinstalls are removed, by one flag" in AGENTS.md.

- [ ] (ask first) `just install-libreoffice`, installs `libreoffice-fresh` and its dependencies if missing; may require a sudo password
- [ ] `pacman -Q libreoffice-fresh && libreoffice --headless --version`, confirms the package is installed and the executable starts

Verify: LibreOffice appears in the launcher and opens normally. Future runs of the repo's preinstall cleanup leave it installed.

## 2026-10-09 Beet shortcut and Bluesky launcher (from silver-fox)

Super+Ctrl+B now opens the Beet repo again. Bluesky moves to the Super+Alt+Space Apps menu through a desktop launcher and icon tracked in `stow/mimeapps`, with `bsky` as a search keyword.

- [x] Checked `~/.local/share/applications/Bluesky.desktop` and `~/.local/share/icons/hicolor/256x256/apps/bluesky.png` before linking on 2026-11-12; both were absent, so no generated copies needed removing
- [x] `just stow-symlinks`, links the Bluesky launcher and icon and refreshes the desktop database
- [x] `readlink ~/.local/share/applications/Bluesky.desktop ~/.local/share/icons/hicolor/256x256/apps/bluesky.png`, both point into `stow/mimeapps`
- [x] `desktop-file-validate ~/.local/share/applications/Bluesky.desktop`, expect no errors
- [x] `hyprctl reload && hyprctl configerrors`, expect no errors

Verify: Super+Ctrl+B opens `~/me/beet` in the configured editor. Super+Alt+Space finds Bluesky when searching either `bluesky` or `bsky`, and selecting it opens `https://bsky.app` as a web app.

## 2026-10-11 browser AGC stops moving the mic gain (from silver-fox)

Chrome, Chromium and Element now run with `--disable-features=WebRtcAllowInputVolumeAdjustment`, so a call can no longer raise the OS mic gain and leave dictation clipping afterwards. See "Browser calls must not move the mic gain" in AGENTS.md. Chrome's flag is a new `chrome` stow package, Element's is a new line in the already stowed `electron-flags.conf`, and Chromium's is appended to omarchy's own copy.

- [x] `ls -la ~/.config/chrome-flags.conf`, confirmed missing before linking on 2026-11-12
- [x] `just stow-symlinks`, links `~/.config/chrome-flags.conf` to the new package
- [x] `just stow-files`, appends the flag to `~/.config/chromium-flags.conf` if missing
- [ ] (ask first) quit Chrome and Element completely, PWAs included, and reopen them; flags only apply when the main process starts, and a call may be in progress
- [ ] `wpctl get-volume @DEFAULT_AUDIO_SOURCE@`, and if it reads higher than the level dictation was tuned for, set it back with `wpctl set-volume`; a past call may already have raised it

Verify: `pgrep -a chrome | grep -c WebRtcAllowInputVolumeAdjustment` and `pgrep -a electron | grep -c WebRtcAllowInputVolumeAdjustment` both print more than 0 (Electron merges the feature into its own `--disable-features` list for child processes, so match the name, not the whole switch). After a real call in Chrome or Element, `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` reads the same as before it.

## 2026-10-15 caps lock compose restored (from silver-fox)

`~/.XCompose` included Omarchy 3's `~/.local/share/omarchy/default/xcompose`, which no longer exists, so xkbcommon rejected the whole file and every CapsLock compose sequence was dead. The include now points at `/usr/share/omarchy/default/xcompose`. fcitx5 reads the file only at startup.

- [x] `/usr/lib/xkbcommon/xkbcli-compile-compose ~/.XCompose | grep -E '<m> <s>|<space> <n>'`, both sequences compile without errors, checked 2026-11-12
- [x] `omarchy-restart-xcompose`, restarts fcitx5 onto the fixed file

2026-11-12: restored the detached `.XCompose` to a stow link, preserving its local `poopie` expansion in the source. `omarchy-fcitx5.service` is active. Interactive typing below remains to be checked.

Verify: CapsLock m s types 😄 and CapsLock space n types "Peter Hayman".

## 2026-10-21 daily backup (from silver-fox)

This device now backs itself up to its own prefix of the private `arch-config--shared--backup` bucket, once a day whenever it is on. See "Backups" in AGENTS.md and the `backup` skill. Claude Code now keeps transcripts for 3650 days rather than 30 (`stow/claude/.claude/settings.json`), which is live as soon as this pull lands.

The bucket is created from silver-fox by `just assets deploy --elevated`, which needs the administrator's code. If the upload below fails with `NoSuchBucket` or `AccessDenied`, that has not happened yet: stop and report, leaving the remaining steps unticked.

- [ ] `just backup --dry-run`, stages `target/backup/rainbow-cat` and prints a report without pushing or uploading. Check the staged tree is this machine's `~/me` and `~/Downloads`, with no `target/` or `.agents/tmp` in it.
- [ ] `just backup --first`, the first real run: pushes branches that are ahead, ingests this machine's Claude Code sessions into beet_egress and pushes them, then uploads. `--first` is right here because rainbow-cat has never had a backup to restore.
- [ ] `just install-backup-timer`, enables the hourly `backup.timer`, which runs a backup once it is due.

Verify:

- `cat ~/.local/state/backup/last-run` prints `ok`.
- `systemctl --user list-timers backup.timer` shows the next firing within the hour.
- Act on the report's "Needs attention" section as the `backup` skill describes.
