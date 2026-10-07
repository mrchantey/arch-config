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
