---
name: backup
description: >
  Back up this device's durable work: push unpushed commits in the repos under ~/me, ingest Claude Code sessions through beet_egress, and mirror uncommitted work and `.agents` to the private `arch-config--shared--backup` bucket. Use when asked to "back up", "run the backup" or "make sure everything is saved", before wiping or handing in a machine, when a "Backup failed" or "Backup refused" notification appears, when adding a device, and when restoring a lost one.
---

# Backup

`just backup` does the work and prints a report; this skill runs it, acts on the report, and covers what it refuses. What is staged, why, and how the timer paces it: `docs/backups.md`. Don't restate it here.

Treat `~/Downloads` as temporary. Never stage or upload its contents. After changing backup scope, use `--dry-run` and verify the staged tree excludes it before uploading.

## Running it

1. `just backup`. `just backup --dry-run` stages and reports without pushing, ingesting or uploading, which is the way to preview a change to the script. A run takes a few minutes, most of it the Claude Code ingest and its push, and longer when a saved build is a week old and gets rebuilt.
2. Act on the report, section by section:
   - **Failed**: see Troubleshooting. The run exits non-zero and raised a notification.
   - **Needs attention**: nothing here was touched, each needs a decision.
     - A diverged branch: show `git log --oneline --graph <branch>...<upstream>` and propose a rebase or a merge. (ask first) Never force push.
     - A branch without an upstream, or whose upstream is gone: ask whether to `git push -u` it, or delete it.
     - Local commits in someone else's repo: tell the user, they are not backed up.
     - A binary that does not build: the saved build ran, so the backup is fine. Say so; fixing the checkout is the user's call.
   - **Pushed**, **Held only in the .git copy**, **Uncommitted, held in the mirror**: informational. Never commit uncommitted work on the user's behalf, an agent may be mid-edit in that tree.
3. Report in a few lines: what was pushed, anything that needs a decision, and that the upload and egress succeeded.

## Troubleshooting

- **`main.bsx declares no backup/push/<host> route`**: a new device. See Adding a device.
- **`Backup refused` / `nothing has been backed up or restored on this machine`**: the first-run guard. If this hostname had a backup before, ie a reinstall, restore first (below). Otherwise `just backup --first`.
- **Egress failed**: rerun it alone to see why, `cd ~/me/beet_egress && just cli ingest pete --source=claude-code`. The usual cause is a Claude Code update adding a transcript field: the parser denies unknown fields, by design, and fails the ingest before writing anything. The fix is a parser change in beet_egress (ask first). Transcripts stay on disk for 3650 days, so this is not urgent.
- **Upload failed with AccessDenied**: the deployer's policy predates a change to the stack. `just assets deploy --dry-run` says whether `--elevated` is needed; `just assets deploy --elevated` asks for the administrator's six-digit code, so only the user can run it.
- **Nothing happened overnight**: the timer is opt-in, so first check it is installed: `systemctl --user list-timers backup.timer` and `journalctl --user -u backup -n 200`. `cat ~/.local/state/backup/last-run` says how the last run went (`ok`, `failed`, `restored`), and its mtime says when.

## Adding a device

1. In `main.bsx`, add a `backup/push/<hostname>` and `backup/pull/<hostname>` pair beside the others; no deploy is needed, the prefix is just a path in the same bucket.
2. On that device: `just backup --first`, and `just install-backup-timer` only if the user wants daily runs.

## Restoring a lost device

On the replacement, after `just init` (which clones the repos and builds what the restore needs):

1. `just setup-age-identity <usb backup>`, so beet can open the deployer pair in `secrets.toml`.
2. `just restore <device> --replace`: pulls the prefix to `~/.cache/backup-restore/<device>`, swaps each backed up checkout in whole and keeps each fresh clone beside it as `<path>.pre-restore`, then fills in missing files such as other repos' `.agents`.
3. In each restored repo, `git fetch` brings the remotes up to date, and `git status` should show only the uncommitted work that was backed up.
4. Once satisfied, delete the `*.pre-restore` dirs and `~/.cache/backup-restore`. The next `just backup` uploads normally, since the restore cleared the first-run guard.

`just restore` without `--replace` only fills in missing files, never overwriting, so it is safe on a live machine, ie to recover a deleted `.agents/plans` file, provided it was deleted after the last backup. Once a backup has pruned it, it survives only as a noncurrent version for 90 days.
