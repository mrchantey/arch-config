---
name: device-handoff
description: >
  Hand a change off to the other machines that run ~/me/arch-config, and pick up handoffs left for this one. Use when a change made here needs another device to act before it takes effect (relink, reload, restart, install, migrate, verify on that hardware), when asked to "hand off to rainbow-cat" or "leave a task for the other machines", and whenever git-sync finds `.agents/tasks/<this-hostname>.md` after a pull. Covers when a handoff is needed, the task file format, and completing then deleting it.
---

# Device Handoff

A commit reaches every device on its next `git-sync`, but the commit alone does not always make the change live there. A handoff is a task file committed alongside the change, telling the other devices exactly what to run to catch up:

```
.agents/tasks/<device>.md
```

`<device>` is the hostname, which is also the name of that machine's `stow/hypr-<device>` package and its entry under "Devices" in AGENTS.md. One file per device, holding every handoff it has not yet completed.

## Sending: when a change needs one

Write a handoff for each other device when the change is not fully live after a plain pull on that device. Typical cases:

- a new file or module under `stow/` (no symlink exists there yet)
- a file that is copied rather than stowed, ie `files/omarchy/shell.json`
- a running process that only reads its config at startup: the Omarchy shell (a bar plugin edit needs `omarchy restart shell`), voxtype, fcitx5, a systemd unit
- a package, mise tool or service to install, or a `sudo` recipe to run
- a one-off migration of machine state, ie moving a directory, clearing a flag, removing an old package
- anything that touches that device's own hardware or `stow/hypr-<device>` files and could not be tested here

No handoff is needed for a plain content edit to an already stowed file, which is live the moment the pull lands. If unsure, write one: the cost is a few idempotent commands.

A handoff is the delta for machines that already exist. A fresh install must get the same result from `just init` alone, so encode the change in the justfile first and have the handoff call those recipes rather than repeat their contents.

### Writing the task

1. Do the steps on this device first, so the handoff only contains commands that are known to work.
2. For every other device, append a section to `.agents/tasks/<device>.md`, creating the file if needed. Never overwrite another section: earlier handoffs may still be pending there.
3. Commit the task file in the same commit as the change, so a device never gets one without the other.

Each section stands on its own, because the agent reading it starts with no context:

```md
## 2026-10-07 synced workspaces (from silver-fox)

Workspace switches now apply to every monitor together, see "Workspaces switch on every monitor together" in AGENTS.md.

- [ ] `just stow-symlinks`, links the new `hypr/workspaces.lua` and the `pete.workspaces` bar plugin
- [ ] `hyprctl reload && hyprctl configerrors`, expect no errors
- [ ] (ask first) `just install-apps`, adds `foo`

Verify: Super+3 shows workspace 3 on the ultrawide and 13 on the side monitor.
```

- **Heading**: date, a few words on the change, and the sending device.
- **Context**: one or two sentences, citing AGENTS.md or a skill for the detail rather than restating it.
- **Steps**: exact commands in order, each with what it does. Every step must be idempotent, since the receiver's git-sync may already have run some of them. Mark anything that needs `sudo`, a password, a reboot or a judgement call as `(ask first)`.
- **Verify**: how to tell it worked on that machine, especially anything this device could not test.
- Never put secrets in a task, it is committed.

## Receiving: completing a handoff

`git-sync` checks for `.agents/tasks/$(hostname).md` after it pulls. When it exists:

1. Read the whole file before running anything, oldest section first, and do the sections in that order.
2. Run each step, ticking it (`- [x]`) as it succeeds. Stop at an `(ask first)` step and ask. Do not skip ahead past a failure: fix it if the cause is clear, otherwise leave it unticked and report.
3. Run the section's Verify. Delete the section once every step is ticked and it verifies.
4. When no sections remain, delete the file. Commit the file's new state, `patch: complete <device> handoff` or `patch: partial <device> handoff` when steps remain, and push.

A partly done file stays committed with its ticks, so the next sync resumes where this one stopped. Only ever edit or delete the file for this hostname; another device's tasks are that device's to complete.

## Gotchas

- **Two devices appending to the same task file conflict on pull.** It is an additive conflict, so keep both sections (git-sync step 3).
- **A handoff for every other device, not just one.** Read the Devices list in AGENTS.md; a device missing a task is a device that silently never catches up.
- **Hostname is the key.** If `hostname` does not match a file name, that device has no handoffs; do not guess at another device's file.
