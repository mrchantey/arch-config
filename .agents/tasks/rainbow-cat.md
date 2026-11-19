# Handoff: rainbow-cat

## 2026-11-20 Brio 100 default mic gain (from silver-fox)

The `pipewire` stow package now also holds `.config/wireplumber/wireplumber.conf.d/brio-100-mic-gain.conf`, which starts any never-seen Logitech Brio 100 at its +6dB hardware floor. See "Logitech Brio 100" in `docs/devices/silver-fox.md`. It matches only the Brio 100 (`046d:094c`), not this machine's BRIO 4K, so nothing changes here; the link just keeps the machines alike.

- [ ] `just stow-symlinks`, links the new file into the existing `~/.config/wireplumber/wireplumber.conf.d`
- [ ] `readlink ~/.config/wireplumber/wireplumber.conf.d/brio-100-mic-gain.conf`, expect a path into `stow/pipewire`

Verify: `systemctl --user restart wireplumber && journalctl --user -u wireplumber --since -1min | grep -i error` prints nothing.
