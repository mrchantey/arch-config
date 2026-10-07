# Handoff: rainbow-cat

## 2026-10-07 synced workspaces (from silver-fox)

Switching workspace now switches both monitors together: the ultrawide (leftmost, so primary) shows 1-10 and the side monitor 11-20. See "Workspaces switch on every monitor together" in AGENTS.md. Until step 1 runs, Hyprland's auto-reload fails on the missing `hypr.workspaces` module, which drops every bind after it in `bindings.lua`.

- [ ] `just stow-symlinks`, links the new `~/.config/hypr/workspaces.lua`, creates `~/.config/omarchy/plugins` and links the `pete.workspaces` bar widget into it
- [ ] `just stow-files`, copies `shell.json`, which now puts `pete.workspaces` on the bar in place of `omarchy.workspaces`
- [ ] `hyprctl reload && hyprctl configerrors`, expect no errors
- [ ] `omarchy restart shell`, the shell does not reliably hot-load a new plugin

Verify:

- `hyprctl monitors -j | jq -c '.[] | {description, x, ws: .activeWorkspace.id}'` shows the C49RG9x at x 0 and the C24F390 at x 4096, with the side monitor on the ultrawide's workspace + 10.
- Super+3 shows 3 on the ultrawide and 13 on the side monitor, with focus staying on whichever monitor had it, and the bar marks 3 on both screens even with focus on the side monitor.
- With two windows on the side monitor, the master column is on the left. This comes from the new `workspace = "m[desc:Samsung Electric Company C24F390]"` rule in `monitors.lua`, which was only syntax-checked on silver-fox. If it does not apply, report it rather than going back to pinned workspace ids.
- Windows that were on the side monitor's old workspaces 7-10 now come up on the ultrawide when those numbers are shown; Super+Shift+Alt+Right swaps them back onto the side monitor.

## 2026-10-07 codex CLI (from silver-fox)

The Codex CLI is now kept alongside claude and gh rather than stripped as a preinstall, see "Dev tooling goes through mise" in AGENTS.md. The desktop app (`openai-codex-desktop`) stays uninstalled. Codex and Claude Code now both read the shared global instructions through links in the `agents` package, see "Agent instructions and skills live in `.agents`" in AGENTS.md.

- [ ] `just install-mise-tools`, rewrites the mise wrappers, now including `~/.local/bin/codex`
- [ ] `codex --version`, first run installs the binary through mise
- [ ] `just stow-symlinks`, links `~/.codex/AGENTS.md` and moves `~/.claude/CLAUDE.md` from the `claude` package to the `agents` package (stow unlinks the old, now dangling, link itself)

Verify:

- `codex --version` prints `codex-cli <version>`, and `pacman -Q openai-codex-desktop` reports it is not installed.
- `readlink ~/.codex/AGENTS.md ~/.claude/CLAUDE.md` shows both under `stow/agents/`, and `cmp ~/.codex/AGENTS.md ~/.agents/AGENTS.md` is silent.
- `cd /tmp && codex debug prompt-input hi | grep -c 'Beet is an Atmospheric'` prints at least 1, ie Codex loads the global instructions.

## 2026-10-07 codex voice capture fix (from silver-fox)

Codex's `/voice` dropped most of the mic audio whenever the PipeWire graph ran above a 1024 quantum, so the model never answered. A new `pipewire` stow package caps Codex's voice host at 1024-frame periods. See "Codex voice needs small capture chunks" in AGENTS.md.

- [ ] `ls -la ~/.config/pipewire`, expect it missing; if it is a real dir, check nothing in it clashes with `stow/pipewire/.config/pipewire/client.conf.d/codex-voice.conf` before the next step, since one stow conflict aborts every package
- [ ] `just stow-symlinks`, links `~/.config/pipewire` to the new package

Verify: start `codex`, run `/voice`, and while it listens `pw-top -b -n 3 | grep codex-voice-host` shows quantum 1024 (not 2048 or 2400). Then say something and confirm it transcribes and answers. This machine's mic differs from silver-fox's Brio, so the end-to-end check is the real test here.

## 2026-10-07 restore LibreOffice (from silver-fox)

The shared preinstall cleanup no longer removes LibreOffice, and fresh installs explicitly install it. Existing machines need to restore it if a previous cleanup removed it, see "Preinstalls are removed, by one flag" in AGENTS.md.

- [ ] (ask first) `just install-libreoffice`, installs `libreoffice-fresh` and its dependencies if missing; may require a sudo password
- [ ] `pacman -Q libreoffice-fresh && libreoffice --headless --version`, confirms the package is installed and the executable starts

Verify: LibreOffice appears in the launcher and opens normally. Future runs of the repo's preinstall cleanup leave it installed.
