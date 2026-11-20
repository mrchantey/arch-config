# Handoff: silver-fox

## 2026-11-20 voxtype: medium.en, VAD, no context window optimization (from rainbow-cat)

`context_window_optimization` made whisper repeat sentences, so it is off (comment in `stow/voxtype/.config/voxtype/config.toml`). To win back the full-window encode under the 20W USB-C cap, silver-fox now runs `medium.en` via `stow/voxtype/.config/voxtype/devices/silver-fox.toml`, applied by `scripts/voxtype-render-config.sh`. Silero VAD now drops clips with no speech. The systemd drop-in was renamed from `battery-isolation.conf` to `render-config.conf`.

- [ ] `rm -f ~/.config/systemd/user/voxtype.service.d/battery-isolation.conf`, removes the old drop-in, which would otherwise run alongside the new one
- [ ] `just setup-voxtype`, renders the config, downloads medium.en (~1.5 GB) and the VAD model, writes `render-config.conf` and restarts the daemon
- [ ] `journalctl --user -u voxtype -n 200 | grep -E 'render-config|Loading whisper model'`, expect `whisper.model = medium.en` and the medium.en model path

Verify: on the USB-C charger (`upower -d`), dictate a few 2 to 10 s clips and read `journalctl --user -u voxtype -n 80 | grep 'Transcription completed'`. Turbo took ~4.85s per clip here; report medium.en's time and whether accuracy holds up. If it is still too slow, `small.en` is the next rung down. Then press and release push-to-talk without speaking: nothing should be typed and the log should show `No speech detected`.
