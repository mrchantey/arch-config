# Handoff: rainbow-cat

## 2026-11-20 Brio 100 default mic gain (from silver-fox)

The `pipewire` stow package now also holds `.config/wireplumber/wireplumber.conf.d/brio-100-mic-gain.conf`, which starts any never-seen Logitech Brio 100 at its +6dB hardware floor. See "Logitech Brio 100" in `docs/devices/silver-fox.md`. It matches only the Brio 100 (`046d:094c`), not this machine's BRIO 4K, so nothing changes here; the link just keeps the machines alike.

- [ ] `just stow-symlinks`, links the new file into the existing `~/.config/wireplumber/wireplumber.conf.d`
- [ ] `readlink ~/.config/wireplumber/wireplumber.conf.d/brio-100-mic-gain.conf`, expect a path into `stow/pipewire`

Verify: `systemctl --user restart wireplumber && journalctl --user -u wireplumber --since -1min | grep -i error` prints nothing.

## 2026-11-20 Omarchy 4.5 workspace conflict, voxtype speed (from silver-fox)

Omarchy 4.5 added `default.hypr.monitor-workspaces`, its own per-monitor workspace blocks, which fought our synced workspaces on every reload and hotplug. `hyprland.lua` now preloads `hypr.workspaces` under that name, so Omarchy's module never runs and `o.workspaces` is ours, see the "Omarchy interface" section of `workspaces.lua`. Voxtype gains `context_window_optimization` and `flash_attention` (a 5.8s clip went from 4.85s to 1.15s on silver-fox), and its GPU drop-in loses `VOXTYPE_VULKAN_DEVICE`, which voxtype 1.2.2 can no longer match and only warns about. The G903 gets an explicit `left_handed = true` in `input.lua`, which this machine's global setting already implied.

- [ ] `hyprctl reload && hyprctl configerrors`, expect no errors
- [ ] `rm -f ~/.local/state/omarchy/monitor-workspaces ~/.local/state/omarchy/monitor-workspaces-merged`, Omarchy's block assignments, now dead state
- [ ] `sed -i '/VOXTYPE_VULKAN_DEVICE/d' ~/.config/systemd/user/voxtype.service.d/gpu.conf && systemctl --user daemon-reload`, the same line `just setup-voxtype-gpu` no longer writes
- [ ] `just restart-voxtype`, picks up the new whisper settings

Verify: `for i in 1 2 3; do hyprctl reload; sleep 0.6; hyprctl monitors -j | jq -c '[.[] | {name, ws: .activeWorkspace.id}]'; done` keeps the same group each time, with the leftmost monitor on N and the next on N + 10. `journalctl --user -u voxtype --since -1min | grep -E 'flash attn|WARN'` shows `flash attn = 1` and no `VOXTYPE_VULKAN_DEVICE` warning; dictation reports `Transcription completed in` well under a second.

## 2026-11-20 verify silver-fox's notes against this machine (from silver-fox)

silver-fox no longer does project work; this machine does. Every untracked and ignored `.agents` file silver-fox held (37,534 files across 12 checkouts, including its three beet worktrees) was moved to a USB drive labelled `mini-mouse` and deleted from silver-fox, which now holds only what git tracks. Most of it should already be here from the 2026-11-14 recovery, often at new paths, so this is a check that nothing was lost, not a migration. The drive's `silver-fox-handoff-2026-11-20/README.md` describes every archive and how to read the report.

- [ ] Plug in the drive and read `silver-fox-handoff-2026-11-20/README.md` on it
- [ ] `bash <drive>/silver-fox-handoff-2026-11-20/compare.sh ~/.cache/silver-fox-handoff-check ~/me`, adding the 2026-11-14 recovery quarantine as a further root if it still exists. Expect `0 manifest mismatches`; takes a few minutes for ~5G
- [ ] Read every `changed` and `missing` entry it lists outside `tmp` and `reference`. For each, decide whether this machine's notes already supersede it; merge only what is genuinely newer or unique into the owning `.agents`. Skim `tmp` and `reference` for anything hand-written
- [ ] `git -C ~/me/bevy fetch <drive>/silver-fox-handoff-2026-11-20/git/bevy-bevy_utils-serde-no-std.bundle bevy_utils-serde-no-std:silver-fox/bevy_utils-serde-no-std` only if `git -C ~/me/bevy cat-file -e bd209326c` fails, so the one unpushed bevy commit survives
- [ ] Check `git/beet_eval-uncommitted.status` on the drive: silver-fox had deleted seven tracked beet_eval skills locally. If that deletion was intended, make it here as a commit; otherwise ignore it
- [ ] (ask first) Once the report is accounted for, ask whether to wipe the drive's copy

Verify: every `changed` or `missing` note outside `tmp` and `reference` is accounted for, either merged or judged superseded, with the outcome written into the reply that completes this task.
