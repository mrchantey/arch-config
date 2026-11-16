# Handoff: silver-fox

**Recovery safety gate:** Read the 2026-11-14 reconciliation section below before executing any earlier backup step. Do not upload this machine's stale tree until its newer local work and Rainbow Cat's recovered canonical state are reconciled.

## 2026-11-12 updated shell layout (from rainbow-cat)

`files/omarchy/shell.json` now uses Omarchy's split `centerBegin` / `center` / `centerEnd` layout instead of `centerAnchor`, keeping the clock centered. It preserves rainbow-cat's updated Elsewhen cities and Voxtype settings plugin, restores `pete.workspaces`, and keeps the repo's idle timings. The compose source also preserves rainbow-cat's local `poopie` expansion. See `files/README.md`.

- [ ] `omarchy-version`, check the installed version; rainbow-cat validated this config on 4.5.0-3
- [ ] (ask first, only if this machine still predates the split-center layout) `omarchy update`, then reconcile with the `os-update` skill before copying the newer shell config
- [ ] Compare `~/.config/omarchy/shell.json` with `files/omarchy/shell.json`, preserving any deliberate local settings before replacement
- [ ] `just stow-files`, applies the copied shell config
- [ ] `omarchy restart shell`, reloads the bar and plugins
- [ ] `omarchy-restart-xcompose`, reloads the compose expansion
- [ ] `hyprctl reload && hyprctl configerrors`, expect no errors

Verify: `omarchy-shell shell ping` prints `ok`; the clock is centered and the synced-workspace buttons appear. Check `omarchy-shell shell listPlugins` for enabled `pete.workspaces` and, if installed, `io.voxtype.settings`. CapsLock space p types `poopie`.

## 2026-11-13 backup scope and Claude metadata (from rainbow-cat)

Downloads is temporary and excluded from backups, see `docs/backups.md`. The next successful mirror removes any old Downloads objects from the active device prefix; version history retains them for its existing 90-day period. `beet_egress` commit `21ccf76` preserves Claude Code's `accountUuid`, `organizationUuid` and `tools` fields without relaxing strict validation. All 44 egress tests and real ingestion passed on rainbow-cat, and its full backup succeeded.

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

`pete.workspaces` now labels each workspace group with its most recently focused Zed project while retaining numeric shortcuts. See `stow/omarchy/.config/omarchy/plugins/pete.workspaces/README.md`. The existing `omarchy` stow package includes the helper and tests, so fresh installs need no new recipe.

- [ ] `stow -d stow -t /home/pete -R omarchy`, links the widget's new helper even if the plugin directory is unfolded; run from `~/me/arch-config`
- [ ] `omarchy restart shell`, clears Qt's cached workspace widget
- [ ] `omarchy-shell shell ping`, expect `ok`

Verify: the bar shows labels such as `2 arch-config`, with the active workspace text and underline using the current theme's accent color instead of urgent red. Changing the file within a Zed project leaves its project label stable; moving its window to another workspace transfers the label. With multiple screens, the same group shows the same label on each bar.

## 2026-11-14 recovered source worktrees and canonical notes (from rainbow-cat)

Rainbow Cat now continues the verified Silver Fox snapshot without replacing newer committed work. Eval, Misc and OS were recovered at `9b5840ae0` for this exceptional transfer. Worktrees are ephemeral development state, not a required cross-device or fresh-install layout. Canonical `.agents` material, historical reference bundles and sealed retired private state are in Rainbow Cat's normal backup, not necessarily in Git. See `.agents/reports/reconcile.md` and `.agents/reports/project-reentry-2026-11-14.md` in the recovered arch-config notes.

- [ ] Before any earlier `just backup` step, record `systemctl --user is-enabled backup.timer` and `systemctl --user is-active backup.timer`, then `systemctl --user disable --now backup.timer`. Keep automatic uploads held across reboots until this section's source/note/coverage gates pass; restore the recorded enabled/active state afterward, not blindly on a failed reconciliation.
- [ ] Create a private checkpoint outside `~/me` of this laptop's current Git metadata, edited/untracked durable files, `.agents`, relevant assets and ignored private state, preserving symlinks and modes. Inventory all eight owned repos and existing worktrees first. Keep existing identities/credentials; never source a recovered `.env` or reset a dirty/diverged checkout.
- [ ] Once these reviewed tracked changes have reached Git, use the `git-sync` skill for this repo and fast-forward the clean owned source repos as appropriate. Stop on new local commits, dirty source or divergence instead of discarding laptop work. Do not deploy, rotate credentials or replay old archived tasks.
- [ ] Inspect existing worktrees for laptop-only source and notes before reconciling them. Do not create or advance worktrees merely to match Rainbow Cat's recovered layout. Never copy Rainbow Cat's `.git` pointers, indices or worktree-admin directories onto this machine.
- [ ] Read-only hydrate the canonical note payload into a **new private quarantine**, not the live home tree. From arch-config, `test ! -e target/reconcile-rainbow-cat-2026-11-14 && install -d -m 700 target/reconcile-rainbow-cat-2026-11-14`, then run the command below. The current `secrets/exec` child-environment route is verified; it must not print decrypted credentials. This filters to agent material and excludes source Git metadata, Downloads and the Egress data store.

```sh
just assets secrets/exec -- aws s3 sync s3://arch-config--shared--backup/rainbow-cat/me/ target/reconcile-rainbow-cat-2026-11-14/me/ --region us-west-2 --exclude '*' --include 'beet/.agents/*' --include 'beet_atproto/.agents/*' --include 'beet_egress/.agents/*' --include 'beet_esp/.agents/*' --include 'beet_eval/.agents/*' --include 'beetmash/.agents/*' --include 'arch-config/.agents/*' --include 'personal/.agents/*' --include 'worktrees/beet/eval/beet/.agents/*' --include 'worktrees/beet/misc/beet/.agents/*' --include 'worktrees/beet/os/beet/.agents/*' --no-progress
```

- [ ] Compare the quarantined canonical notes with this laptop's live notes by path/hash and semantics, preserving anything newer or unique. Merge directly into each owning `.agents`, not into another permanent wrapper. Keep OS, infrastructure and Eval queues separate, retain the local Silver Fox handoff until completed, and use current Next sections rather than archived imperative scripts. This is not authorization for production migration or a business-writing loop.
- [ ] Account for assets by content and consumer, retaining newer valid local files. Use the current unsigned shared-asset pull procedures only where hydration is needed; do not push incomplete local assets or revive archived wasm outputs. Historical private recovery archives open with the existing personal age identity and must never become active credentials automatically.
- [ ] Verify `cargo metadata --locked --offline --features=cli --filter-platform x86_64-unknown-linux-gnu --format-version 1` from both `~/me/beet_eval` and `~/me/beetmash`, capturing JSON to fresh scratch files. Run `cargo test --locked -p beet_eval --lib` from Eval, expecting all 33 tests; preserve any later legitimate test changes rather than forcing this historical count. The lockfile graph repairs retain existing pins, and two test-only fixes use visible captions and order-independent filesystem membership.
- [ ] Only after source, notes and assets are accounted for, run `just backup --dry-run`. Confirm the canonical worktrees/notes are included and Downloads, quarantine and the private rollback checkpoint are excluded. Do not use `just restore rainbow-cat`, `--replace`, a blanket Git clean or a direct mirror upload as a substitute for this semantic merge.
- [ ] Restore the timer's recorded enabled/active state, then perform the normal `just backup` without `--first`, verifying ingest and upload to **silver-fox's own prefix** succeed. This future caught-up upload is separate from Rainbow Cat's read-only recovery of the original Silver Fox snapshot.

Verify: Eval and Beetmash resolve their declared source dependencies when resumed, current agent entry points resolve without wrappers, original laptop-only work survives, the backup preview contains no Downloads/quarantine, and `last-run` reports `ok` only after the reconciled upload. Complete the older desktop-specific checks on this laptop as applicable; Rainbow Cat's recovery did not test its hardware or apply laptop OS settings.

## 2026-11-14 Mullvad VPN app (from rainbow-cat)

`just install-mullvad` installs Arch's official `mullvad-vpn` package, including its daemon and CLI, and enables `mullvad-daemon.service`. Fresh installs run it through `install-apps`. Account credentials and connection preferences stay local; the recipe does not log in, connect, change auto-connect or lockdown mode, or enable early-boot blocking. The old `wireguard.md` server list has since been deleted.

- [ ] (ask first, needs administrator authentication) `just install-mullvad`, installs the app and starts/enables its daemon without changing existing VPN preferences
- [ ] `pacman -Q mullvad-vpn mullvad-vpn-daemon`, verifies both packages are installed
- [ ] `systemctl is-enabled mullvad-daemon.service && systemctl is-active mullvad-daemon.service`, expect `enabled` and `active`
- [ ] `mullvad status`, verifies the CLI can reach the daemon; a new installation remains disconnected until the user logs in and connects

Verify: Mullvad VPN appears in the app launcher. The user logs into their funded account in the app; do not put account numbers or device keys in this repo. A connected tunnel and DNS/leak checks still need verification after login.

## 2026-11-14 qBittorrent preferences via Stow (from rainbow-cat)

`just install-qbittorrent` installs Arch's official GUI package. The `qbittorrent` stow module tracks `qBittorrent.conf`, including the user's `/home/pete/torrents` download path, Mullvad's `wg0-mullvad` binding, disabled local peer discovery (`Session\LSDEnabled=false`) and disabled UPnP/NAT-PMP. The interface binding is the torrent kill switch: traffic cannot fall back to Ethernet when Mullvad disconnects, while the GUI stays open. qBittorrent replaces file-level symlinks when saving, so the whole `~/.config/qBittorrent` directory must be folded by Stow. Its local `.gitignore` excludes every other file; torrent payloads and session data under `~/.local/share/qBittorrent` are untouched. Fresh installs use the normal `install-apps` and `stow-symlinks-init` flow; the initial-copy recipe is removed.

- [ ] (ask first, needs administrator authentication) `just install-qbittorrent`, installs the app
- [ ] Quit qBittorrent using File > Exit before migrating; closing its window may leave it running
- [ ] (ask first if an existing profile has unique settings) Compare `~/.config/qBittorrent/qBittorrent.conf` with `stow/qbittorrent/.config/qBittorrent/qBittorrent.conf` and merge deliberate local preferences without adding credentials or cookies
- [ ] `if [ -d ~/.config/qBittorrent ] && [ ! -L ~/.config/qBittorrent ]; then test ! -e ~/.config/qBittorrent.pre-stow && test ! -L ~/.config/qBittorrent.pre-stow && mv -T ~/.config/qBittorrent ~/.config/qBittorrent.pre-stow; fi`, preserves the existing real directory; stop if the backup name already exists
- [ ] `just stow-symlinks`, links the new module; do not pre-create `~/.config/qBittorrent` as a real directory
- [ ] `readlink ~/.config/qBittorrent`, expect the repo's `stow/qbittorrent/.config/qBittorrent` directory
- [ ] Open qBittorrent, confirm the download path and VPN binding in Settings, then use File > Exit and check the directory is still a symlink

Verify: preferences survive saving and restarting, the download path is `/home/pete/torrents`, the network interface is `wg0-mullvad`, and both local peer discovery and UPnP/NAT-PMP are disabled. Rainbow Cat verified the directory symlink survives application saves and tested VPN connect/disconnect/reconnect: all 23 sampled TCP/UDP sockets were kernel-bound to Mullvad; after disconnect, UDP sockets and TCP listeners closed and stale TCP sockets remained bound to the removed tunnel device, with no Ethernet fallback. Reconnecting reopened the tunnel-bound listener without restarting qBittorrent. This was a socket-binding test, not a packet-capture or completed-download test; ask before interrupting this machine's VPN to repeat it.

## 2026-11-14 workspace app-name fallback (from rainbow-cat)

`pete.workspaces` now falls back to the most recently focused app when a group has no Zed window. Friendly names come from desktop entries, with Chrome shortened to `Chrome`; Zed still takes priority. See `stow/omarchy/.config/omarchy/plugins/pete.workspaces/README.md`. The existing stow package includes this change for fresh installs.

- [ ] `omarchy restart shell`, reloads the label selection and desktop-entry lookup
- [ ] `omarchy-shell shell ping`, expect `ok`

Verify: a Chrome-only workspace displays a label such as `3 Chrome`, not a page title. A workspace containing both Zed and Chrome keeps its Zed project label even while Chrome is focused; empty workspaces display only their number. Rainbow Cat verified the live Chrome fallback and all 26 regression checks passed.

## 2026-11-14 install dig (from rainbow-cat)

`just install-dig` installs Arch's `bind` package, which provides `dig`. Fresh installs run it through `install-apps`; no DNS server service is enabled.

- [ ] (ask first, needs administrator authentication) `just install-dig`, installs the DNS lookup utilities
- [ ] `dig -v`, verifies the command is available

Verify: `dig -v` reports the installed BIND version.
