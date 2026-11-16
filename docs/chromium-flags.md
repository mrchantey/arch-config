# Chromium and Electron flags

Chrome, Chromium and the Electron apps each read a flags file at startup, and two of our fixes live in them: one keeps browser calls from moving the mic gain, the other gives Electron apps the keyring. Flags apply only when an app's main process starts.

## Browser calls must not move the mic gain

WebRTC's AGC does not stop at its own digital gain, it also turns the OS mic level. During a call it raises the source volume while it hears speech it judges too quiet and never lowers it again, and WirePlumber persists that like any user change, so the raised gain outlives the call, survives replug and reaches voxtype as clipped garbage. On silver-fox it took the Brio from its calibrated +6dB to +22dB. Chrome, Chromium and every Electron app (Element calls are WebRTC) do this through the `WebRtcAllowInputVolumeAdjustment` feature, which `--disable-features=WebRtcAllowInputVolumeAdjustment` turns off; the call keeps its digital gain, it just stops reaching outside the browser. The flag lives in three places:

- `stow/chrome/.config/chrome-flags.conf`, read by `/usr/bin/google-chrome-stable`
- `stow/electron/.config/electron-flags.conf`, read by the Arch electron wrappers, see the keyring section below
- `~/.config/chromium-flags.conf`, which is omarchy's own copy rather than ours, so `just stow-files` appends the line if missing

Flags apply only when the main process starts, so an already-running Chrome needs every window, PWAs included, closed first. Chromium keeps only the last `--disable-features` switch, so further features join the existing line comma separated, never a second line.

Verified 2026-10-11 with a headless loopback call (`RTCPeerConnection` pair on `getUserMedia({ audio: true })`, scratch `--user-data-dir`) while quiet espeak speech played into the room. Unflagged Chrome raised the Brio from wpctl 0.40 to 0.47 and 0.50 in two 30 s runs, unflagged Electron to 0.45; through the flags files both held at 0.40. The AGC only moves the gain while it hears speech, so a test in a silent room, or with speech already near -20 dBFS, shows nothing.

The tell is in WirePlumber's saved route. `wpctl` prints cubic volume and PipeWire stores linear, so the drift read as wpctl 0.74 beside `channelVolumes` 0.400713 in `~/.local/state/wireplumber/default-routes`. That linear value is exactly PulseAudio's raw 48316, ie `188/255 × 65536` truncated, an AGC level out of 255, which is what pointed at WebRTC rather than the bar's mic slider.

## Electron apps need the keyring flag

Element opens with "Your system has an unsupported keyring meaning the database cannot be opened" and offers weaker encryption. Nothing is wrong with the keyring: `gnome-keyring-daemon` runs with `--components=pkcs11,secrets`, and Chrome and Chromium both hold Safe Storage items in it. Electron picks its `safeStorage` backend from the desktop environment, and Chromium only auto-selects libsecret for GNOME-family desktops, so under `XDG_CURRENT_DESKTOP=Hyprland` it falls back to the "basic" store and calls the keyring unsupported.

Omarchy fixes this for exactly one app: `--password-store=gnome-libsecret` is in its `config/chromium-flags.conf`, with a migration that appends it when missing. Every other Electron app is on its own, which is what the `electron` stow package is for. Arch's `element-desktop` is nothing but `exec electron43 /usr/lib/element/app.asar "$@"`, and `/usr/bin/electron43` reads `~/.config/electron43-flags.conf` first, then falls back to the unversioned `electron-flags.conf`, passing every non-comment line through as a flag. We stow the unversioned name so the file survives Element moving to electron44 on its own schedule; the cost is that a versioned file appearing later would shadow ours silently.

**Never accept the weaker encryption offer.** The basic backend derives its key from a hardcoded password, so once this flag is in place the database written under it cannot be decrypted, and the app needs a fresh login, which for Element means re-verifying the session. Worth reporting upstream: this hits every Electron app on Hyprland, and only chromium is patched.
