---
name: os-update
description: >
  Update Omarchy on this machine and reconcile the ~/me/arch-config stow config afterwards.
  Use when the user says omarchy is "ready for an update" / "update omarchy", asks
  to re-sync stowed config with a new omarchy version, or reports that hypr or
  shell config broke after an update. Covers running the update, spotting stow
  symlinks that a migration replaced with regular files, merging clobbered
  configs, and relinking via the justfile recipes. Specific to the ~/me/arch-config GNU
  stow dotfiles repo -- for ordinary one-off config edits (themes, keybindings,
  single tweaks) use the `omarchy` skill instead.
---

# os-update

Update Omarchy, then bring `~/me/arch-config` back into alignment with the new defaults and
migrations, without leaving broken symlinks or silently losing customizations.

## Read this first: quattro moved everything

Omarchy 4 ("quattro") invalidated most pre-4.0 update lore. If a note predates it,
distrust it:

| Then | Now |
| --- | --- |
| `~/.local/share/omarchy`, a **git repo** you could `git fetch` | `/usr/share/omarchy`, a **read-only pacman package** (`omarchy-version` → e.g. `4.0.3-1`). `~/.local/share/omarchy` is gone (4.0.4 no longer ships the back-compat symlink), so a stowed file still including it breaks, as `~/.XCompose` did. |
| Hyprland `*.conf` + `source =` chain | native **Lua** modules (`hyprland.lua` and friends) |
| waybar, walker/elephant, mako, swayosd, hypridle/hyprlock | one Quickshell process, `omarchy-shell`, configured by `~/.config/omarchy/shell.json` |
| `omarchy-refresh-<thing>` per config | one `omarchy-refresh-config <path-relative-to-.config>` |
| `~/.config/omarchy/current/...` | `~/.local/state/omarchy/` (themes, toggles, migration markers) |

**Never edit `/usr/share/omarchy/`.** It is package-owned and replaced wholesale.

## Layout

- **Config repo:** `~/me/arch-config`, stow packages under `stow/`. Git-tracked = source of truth.
- **Migrations:** `/usr/share/omarchy/migrations/*.sh`; one empty marker per applied
  migration in `~/.local/state/omarchy/migrations/`.
- **Device packages:** `stow/hypr-<host>/` holds only `monitors.lua`,
  `input-device.lua`, `layout-device.lua`. Everything else is the shared `hypr`
  package. Detect the device with `hostname`, or
  `readlink ~/.config/hypr/monitors.lua` (→ `hypr-<device>`).
- **Recipes:** `just stow-symlinks` (common packages), `just stow-device <name>`,
  `just stow-files` (the copied, non-stowed files).

## The update itself needs interactive sudo

`omarchy update` runs `pacman -Syu`, `yay`, and migrations that call `sudo`. An
agent cannot supply the password (`sudo -n true` fails). **Ask the user to run it
in their terminal.** It also takes a Snapper snapshot first and logs the whole run
to `/tmp/omarchy-update.log`, which is worth reading afterwards.

```bash
omarchy update        # interactive, confirms first
omarchy update -y     # unattended; steps that would prompt report and skip instead
```

Order matters: **update first, reconcile after.** The update is what brings in new
default files and packages. Do not pre-edit stow sources to reference files that
only exist post-update.

Check whether one is even needed: `omarchy-update-available`.

There is no useful pre-update migration preview any more. Migrations ship *inside*
the package, so they do not exist locally until the update installs them. The old
`git diff HEAD origin/master -- migrations/` trick is dead along with the git repo.

## Why reconciliation is needed at all

Every tracked dotfile is a stow symlink into `~/me/arch-config`. A migration that *appends*
(`>>`) or *reads* follows the symlink and lands in the repo. Harmless, and it shows up as
a normal `git diff`. Three things are not harmless:

1. **`sed -i` does not follow symlinks.** It writes a temp file and renames it over
   the path, **replacing the symlink with a regular file**. The edit applies to a
   detached copy; the stow source goes stale. This is the main damage, and it hits
   the file-level symlinks under `~/.config/hypr/` (that directory is real, so each
   file is linked individually).
2. **`omarchy-refresh-config <path>` copies a shipped default over `~/.config/<path>`.**
   If the symlink is intact it follows it and **overwrites the stow source with the
   stock default**, clobbering customizations. It leaves a `*.bak.<timestamp>`
   alongside, and git history has the rest.
3. **Quattro drops stock `*.lua` files next to ours.** They are plain files, so the
   next `stow` run conflicts on them. `just stow-symlinks-init` clears the known
   ones; a new stock filename means adding it to that `rm -f` list.

## Reconciliation workflow

### 1. State check

```bash
omarchy-version
ls ~/.local/state/omarchy/migrations/            # applied markers
ls ~/.local/state/omarchy/migrations/skipped/ 2>/dev/null   # anything skipped, e.g. sudo timeout
cd ~/me/arch-config && git status -s                      # folded-dir edits already show up here
```

### 2. Find symlinks a migration turned back into regular files

```bash
for f in hyprland bindings input looknfeel windows autostart envs \
         monitors input-device layout-device; do
  p=~/.config/hypr/$f.lua
  [[ -L $p ]] && echo "LINK    $f" || { [[ -f $p ]] && echo "REGULAR $f (broken)" || echo "MISSING $f"; }
done
```

Also check the two files that are still `.conf` (`hyprsunset.conf`, `xdph.conf`,
read by separate processes, not Hyprland) and `~/.config/omarchy/shell.json`.

### 3. Diff each broken file against its stow source

`stow/hypr/.config/hypr/<f>.lua`, or `stow/hypr-<device>/...` for the three device
modules.

- **Identical** → the migration rewrote it to the same bytes. Just relink.
- **Differs** → a real change. Merge deliberately, writing the result into the
  **stow source**, never into `~/.config`:
  - *Refresh-clobbered*: the live file is the stock default and the user's version
    is in git (and a `.bak.<timestamp>`). Adopt the new structure, **preserve the
    user's tuning**.
  - *Renamed commands*: confirm anything referenced still exists (`command -v ...`).
    Omarchy renames commands between versions, and a migration's grep-guard often
    will not match a customized file, so the dead name survives in our copy.

### 4. Relink

```bash
rm -f ~/.config/hypr/<broken>.lua
cd ~/me/arch-config && just stow-symlinks
[ -d "stow/hypr-$(hostname)" ] && just stow-device "$(hostname)"
```

Re-stowing no-ops already-correct links. **Do not run the `-init` recipes to fix a
few links**, they `rm -rf` a great deal first.

If stow reports a conflict, fix the conflict; do not delete blindly. **One conflict
aborts the entire invocation**, so a single stray regular file silently leaves
*every* package unstowed.

### 5. Reconcile the copied files

`files/omarchy/shell.json` is **copied, not stowed**, because `omarchy-shell-config`
writes it with `mktemp` + `mv` and would replace a symlink. So it needs manual
direction after an update:

```bash
diff -u files/omarchy/shell.json ~/.config/omarchy/shell.json
just stow-files    # repo -> live  (push our version)
just pull-files    # live -> repo  (capture an update's or the GUI's changes)
```

### 6. Verify

```bash
hyprctl reload && hyprctl configerrors    # empty output = clean
omarchy-restart-shell                     # bar / launcher / notifications / idle
systemctl --user restart voxtype.service  # only if voxtype config changed
```

`hyprctl configerrors` is the real check, because the Lua binder is far stricter than the
old `.conf` parser about keysyms and dispatcher syntax.

### 7. Review, don't commit

Show the full `git diff` in `~/me/arch-config` and summarize. **Do not commit unless asked.**

## Don'ts

- Never edit `/usr/share/omarchy/`, it is package-owned and replaced on update.
- Don't run the update non-interactively in the background hoping sudo passes.
- Don't pre-create migration skip-markers for migrations that also do package work.
- Don't pre-align stow sources to files that only land during the update.
- Don't `rm` a file just because stow calls it a conflict, check `readlink` first;
  under a folded directory symlink that "plain file" is the repo's own file.
