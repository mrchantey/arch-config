---
name: disk-cleanup
description: >
  Free disk space on this machine: survey what is using the disk, prune cargo intermediates and refetchable caches, and surface the bigger decisions. Use when the disk is full or nearly full, when a build or write fails with "No space left on device", when asked to "clean up the disk", "free up space" or "what's using all my space", and before a large download or build on a tight disk.
---

# Disk Cleanup

`just disk-cleanup` does the safe work; this skill runs it and handles everything it deliberately leaves alone. Why cargo targets dominate and how pruning keeps them usable: the header of `scripts/disk-cleanup.sh`. Don't restate it here.

## Running it

1. If the disk is at or near 100%, run step 3 first: cargo is nearly always the fastest win, and builds and agents fail until there is headroom.
2. `just disk-cleanup survey` for the picture: free space, the largest dirs under `~` three levels deep, every cargo profile dir with its size, and the pacman cache and journal. It takes a minute or two, most of it `du`.
3. `just disk-cleanup prune --dry-run` lists what prune would clear per profile, then `just disk-cleanup prune`. Profiles printed as `skip (cargo running)` have a build or rust-analyzer holding their lock; rerun later rather than killing it, an agent is likely mid-build.
4. Relay the two sudo lines prune prints for the user to run. Agents have no passwordless sudo.
5. Work through the survey against the tiers below, then report the `df` delta and the open decisions.

## Tiers

### Prune handles it

- Cargo intermediates in every profile dir under `~/me`, including git worktrees and scratch crates in `.agents/tmp`.
- Mise versions no config requests, the uv cache's unused entries, the npm cache, yay's AUR clones.

### Delete without asking

- A cargo target dir whose path is not under `~/me`, ie a stray `CARGO_TARGET_DIR` from an abandoned setup: check nothing in `~/.cargo/config.toml`, `~/.bashrc` or a repo's `.cargo/config.toml` points at it, then delete it whole.
- A second sccache dir that is not `$SCCACHE_DIR`.
- A cargo `target/` inside a retired or archived checkout, but only its cargo profile dirs, never the checkout's notes or state.

### Ask first

- Anything else under a `target/`: beet's dev TLS certs and local stores (`target/tls`, `target/stores`) and the odd download (`beet_egress/target/takeout-*.tgz`). Tofu work dirs (`target/infra`) are regenerable, their state lives in S3, but deleting one mid-deploy breaks that deploy.
- `~/me/beet_egress/dumps` and `store`. `store` is the append-only source of truth and is never deleted. `dumps` are originals awaiting ingest, they shrink through beet_egress's `ingest --consume`, never `rm`.
- Dated dumps under `~/me/arch-config/target/reconcile` and `~/.local/state/reconcile`: evidence from a past migration, the user decides when it's done with.
- `~/.local/share/Trash`, rustup toolchains (`rustup toolchain list`; keep stable, the default nightly and any pinned by a repo's `rust-toolchain.toml`), `~/.cache/tofu-plugins` (`.terraform` dirs symlink into it), `~/.cache/ms-playwright`, Steam, containers, model weights such as `~/.local/share/kokoro-fastapi`.
- Whole repos or worktrees, even stale ones: they may hold unpushed work.

## Reading the numbers

- `du` overstates real usage: see the script header. Report what `df` says was freed.
- `/home` has no snapper snapshots, so deletions there free space at once. `/` keeps at most 5, so space freed under `/usr` can lag until they rotate.
- A cargo profile that grows back to hundreds of GB within days is normal for beet; `SCCACHE_CACHE_SIZE` caps the shared cache, nothing caps a target, so rerun prune rather than tuning cargo.
