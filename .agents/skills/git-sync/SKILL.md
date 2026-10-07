---
name: git-sync
description: >
  Use to synchronize this machine with the ~/me/arch-config dotfiles repo: commit and push local changes ("our own") and pull the latest from origin, then patch the live OS so it actually matches the repo. Triggers: "sync the arch-config repo", "git sync", "/git-sync", "pull and push my dotfiles", "update this machine from the repo", "bring this box up to date". Covers committing local work, rebasing onto origin, re-applying stow/services/hyprland after the pull, and completing the device-handoff tasks other machines left for this one.
---

# Git Sync

Synchronize `~/me/arch-config` (the omarchy dotfiles repo) in both directions, **make the running OS match the repo**, then complete any handoff another device left for this one.

The repo is just config — the box only changes when something re-reads that config. Most of the time that's automatic, but not always, so a sync is two jobs:

1. **Git**: commit + push local work, pull origin, end on a clean linear tree.
2. **Patch**: re-apply only the things the pull changed that aren't picked up for free.
3. **Handoff**: run the task file other devices committed for this one, if any (`device-handoff` skill).

## The mental model (why "patch" is needed at all)

Every tracked dotfile is a **stow symlink pointing into this repo** (`~/.config/zed/settings.json` → `~/me/arch-config/stow/zed/...`). So when `git pull` rewrites a file's *contents*, the change is **already live** — the symlink points at the new bytes. No action needed for plain content edits.

You only need to patch when the pull changed something *structural*:

- a **new or removed stow module** (no symlink exists yet at its target),
- a change to the **stow lists / justfile** wiring,
- a **systemd unit / drop-in** (systemd caches units until `daemon-reload`),
- a **long-running app that reads its config once at startup** (Hyprland, the fcitx5 IME daemon, the voxtype daemon) — the file's bytes are already live through the symlink, but the *running process* is still using the config it loaded at launch, so the change has no effect until it re-reads,
- a file the repo **copies rather than stows** (`files/omarchy/shell.json`) — there is no symlink, so a pull changes the repo copy and nothing else.

So: do the git half, diff what landed, and apply *only* the matching patches.

## Steps

### 1. Preflight

```sh
cd ~/me/arch-config
git status -sb        # confirm branch tracks origin/main, see what's dirty
git remote -v         # expect origin = github.com/mrchantey/arch-config
```

### 2. Commit local work ("our own")

A sync exists to push your local edits, so commit them. **Before committing, look at the diff** and make sure nothing secret is being staged (credentials, tokens, `*.pem`, real keys — see `add-stow-module`):

```sh
git diff --stat
git diff            # eyeball it; abort if a secret is in there
```

Then stage and commit. Match the repo's terse convention — short lowercase `patch` / `patch: <what>` / `feat: <what>` messages (see `git log --oneline`):

```sh
git add -A
git commit -m "patch: <one line on what changed>"
```

If the work needs the other devices to act before it is live there (a new stow file, a shell restart, an install, a migration), write their handoffs into `.agents/tasks/<device>.md` as part of this commit, following the `device-handoff` skill.

If the tree is already clean, skip to the pull.

### 3. Pull from origin (rebase)

The history is linear "patch" commits — keep it that way. Rebase replays your local commits on top of origin instead of making a merge commit:

```sh
before=$(git rev-parse HEAD)      # remember where we were, for the diff below
git pull --rebase origin main
```

**On conflict: classify before acting.** Open the conflicted file(s) and look at the markers. There are three kinds — and you are expected to resolve the first two yourself, without asking:

- **Benign (additive) — resolve it yourself.** Both sides only *added* distinct lines in the same neighbourhood: no line was edited or deleted on both sides, and the two insertions don't set the same key to two different values. This is the common case for append-only tables/lists (the voxtype corrections map, a package/keybind list, etc.) where two machines each tacked on entries. **Keep both sides**: delete the `<<<<<<<` / `=======` / `>>>>>>>` markers, leave every added line from both sides.

- **Cosmetic (same intent, different words) — resolve it yourself, be bold.** Both sides edited the *same* line/bullet but mean the *same thing*: a reword, splitting one bullet into two, added elaboration, a typo fix, or prose reordering that carries no semantic weight. This is the case you just hesitated on — **it is not a reason to stop.** Pick the clearest result: prefer the more detailed / better-worded phrasing (usually whichever side elaborates more), fold in any genuinely-new line your side added, and drop redundant restatements of the same idea. You do **not** need permission to choose wording. Most prose/markdown conflicts (CLAUDE.md, skill docs, READMEs, comments) are this kind — make the call, note the choice in your report, and move on.

- **Genuine value clash — stop and ask.** Reserve stopping for conflicts where the *meaning* diverges, not just the wording: the same key/setting given two *different actual values* (a keybind → two different keys, a number/path/colour that disagrees), overlapping edits where each side rewrites or deletes the other's logic, or reordering where order is load-bearing (sourced configs, `PATH`, etc.). Also **always stop** for the session-critical hypr files (`hyprland.lua`, `monitors.lua`, `input.lua`, `input-device.lua`, `layout-device.lua`, `bindings.lua`) even when it looks trivial — a bad merge there can wedge the session. Report the conflicting files + the diff, let the user resolve, then `git rebase --continue` (or `git rebase --abort` to back out).

After resolving (either of the first two kinds), sanity-check no markers remain and the file still parses (valid TOML/JSONC/conf/markdown), then continue:

  ```sh
  grep -rn '^<<<<<<<\|^=======\|^>>>>>>>' <file>   # sanity-check: NO markers left
  git add <file>
  GIT_EDITOR=true git rebase --continue
  ```

Resume at step 4 afterward.

### 4. Push

```sh
git push
```

### 5. Patch the live OS from what was pulled

List the paths that changed across the whole sync (pulled commits + your replayed commits), then apply only the matching actions:

```sh
git diff --name-only "$before" HEAD
```

| Changed paths | Why it needs a patch | Action |
| --- | --- | --- |
| **New/removed `stow/<mod>/`**, a new file inside an existing module, or `justfile` stow lists | nothing links the new path yet (only a dir stow *folded* into one symlink picks new files up for free; `~/.config/hypr` is a real dir of per-file links, so a new `hypr/*.lua` is not live) | `just stow-symlinks` (idempotent relink) |
| `stow/hypr-<host>/` (device files) | device overrides re-stowed | `just stow-device "$(hostname)"` then `omarchy-restart-hyprctl` |
| `stow/hypr/` (common hypr) | Hyprland holds config in memory | `omarchy-restart-hyprctl` (`hyprctl reload`) |
| `files/omarchy/shell.json` | **copied, not stowed** — the repo edit is not live at all until it is copied into `~/.config/omarchy/` | `just stow-files` (it hot-reloads on write, so no restart). If the change was made in the GUI instead, capture it the other way with `just pull-files` |
| `stow/fcitx5/conf/<addon>.conf` (e.g. `keyboard.conf` — the hint hotkeys) | a **per-addon** config; the daemon caches it at startup. **`fcitx5-remote -r` does NOT pick this up** — that only reloads fcitx5's *global* `config`, not addon configs | reload just that addon over dbus (daemon keeps running, no input drop): `gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller --method org.fcitx.Fcitx.Controller1.ReloadAddonConfig "<addon>"` (addon name = the conf filename without `.conf`, e.g. `keyboard`). Bulletproof fallback (resets IME state briefly): `... --method org.fcitx.Fcitx.Controller1.Restart` |
| fcitx5's top-level `config` (i.e. `~/.config/fcitx5/config`, **not** under `conf/`) | the daemon's **global** config (IME-switch hotkeys etc.) | `fcitx5-remote -r` (`ReloadConfig`) — global config only |
| `stow/voxtype/`, `scripts/voxtype-*`, or voxtype `just` recipes | daemon caches model/config at startup | `just restart-voxtype`; if the drop-in *generation* logic changed, re-run `just setup-voxtype-isolation` (and `just setup-voxtype-gpu` if GPU pinning changed) |
| `scripts/*/startup.sh` | needs exec bit | `chmod +x scripts/*/startup.sh` |
| `justfile` **install lists** (`install-apps`, `install-user-apps`, `install-extras`, `install-rust`) | new packages aren't installed by a pull | **ask the user** before running — these are heavy/`sudo`. Then run the matching `just install-*` recipe |
| anything else (zed, alacritty, ghostty, bashrc, claude, opencode, mimeapps, starship, …) | plain content edit through a live symlink | **nothing — already live** (open a new shell for `.bashrc`) |

Guard the device step — only stow a device package that exists:

```sh
host=$(hostname)
[ -d "stow/hypr-$host" ] && just stow-device "$host"
```

### 6. Complete handoffs for this device

```sh
ls .agents/tasks/"$(hostname)".md 2>/dev/null
```

If it exists, follow the receiving steps in the `device-handoff` skill: run its sections oldest first, delete each one as it completes and verifies, delete the file once empty, then commit and push that. Leave every other device's task file alone.

### 7. Confirm

```sh
git status -sb        # clean, up to date with origin/main
```

Report what you pushed, what you pulled, which patches you ran (or that none were needed), and which handoff sections you completed or left pending.

## Gotchas

- **Never `git pull` with a dirty tree** — commit (step 2) or `git stash` first, or the rebase refuses. Prefer committing; that's the point of a sync.
- **Conflicts: resolve wording yourself, stop only for value clashes** (see step 3). Auto-resolve both *additive* conflicts (keep both sides) and *cosmetic* ones (same intent reworded — pick the clearest phrasing and fold in any genuinely-new lines); don't ask permission for prose. Stop and ask only when the actual *value/meaning* diverges, and *always* stop for hypr session files (`monitors.lua` etc. — a bad merge there can wedge the session).
- **`just stow-symlinks` and `just stow-device` are idempotent** — safe to run even when nothing structural changed. When unsure whether a pull added a module, just run `stow-symlinks`; it only relinks.
- **`hyprland.lua` is special**: a live Hyprland regenerates a default stub the instant that symlink goes missing, which aborts the whole hypr stow. `just stow-symlinks` pre-creates it atomically — don't `rm` it by hand mid-sync.
- **Content vs structure**: a one-line edit to an existing tracked file usually needs *no* patch (symlink already points at it); a *new* file/module needs a relink. **The exception is a config owned by a long-running daemon** (hypr, fcitx5, voxtype): the new bytes are live on disk, but the process won't act on them until it re-reads — so even a pure content edit there still needs the matching reload/restart from the table. When in doubt, the table's "Action" column is always safe to run.
- **Don't reflexively re-run install recipes.** A pull that only touched config installs nothing new — only `just install-*` when the package *lists* changed, and confirm first (they use `sudo`/`yay`).
- **Never `rm` a "blocking" file to clear a stow conflict.** Stow folds whole directories: `~/.config/autostart` is often a *symlink to the repo dir*, so a file inside it that looks like a plain real file is actually the repo file surfaced through that folded symlink — `rm`-ing it deletes it straight out of `~/me/arch-config` (recover with `git checkout -- <path>`). Check with `readlink ~/.config/<dir>` first. New files under an already-folded dir are live automatically; let `just stow-symlinks` (which is idempotent) handle real conflicts, and if it reports one, surface it rather than deleting.
