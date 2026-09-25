---
name: info-silver-fox
description: >
  The standing record of `silver-fox`, the Dell Precision 7560 laptop that this
  ~/me/arch-config config runs on: measured hardware inventory, the per-device config
  decisions and why they were made, what is installed versus still pending, and
  the machine-specific traps. Read this before changing anything under
  stow/hypr-silver-fox/ or scripts/silver-fox/, before answering "what hardware
  is this", and before assuming a silver-fox fact that predates 2026-09-10 --
  the name was inherited from a Dell XPS 15 9500 that is dead and gone, so a lot
  of older notes describe different hardware. Update this skill whenever the
  machine's hardware or device config changes.
---

# silver-fox: Dell Precision 7560

Rebuilt from a fresh Omarchy install on **2026-09-10**, replacing a Dell XPS 15
9500 of the same name that died of a motherboard power fault, then reinstalled onto the 1TB drive on **2026-09-14** (see Disks). The hostname is unchanged deliberately: `stow/hypr-silver-fox` and `just init-silver-fox` both key off it.

**Everything below was measured on the machine, not read off a spec sheet.**

## Hardware

| | |
| --- | --- |
| Model | Dell Precision 7560, SKU 0A69, rev A01 |
| BIOS | 1.48.0 (2026-05-31) |
| CPU | i7-11850H, 8c/16t, Tiger Lake-H |
| RAM | 64GB (62GiB usable) |
| dGPU | NVIDIA RTX A2000 Mobile, GA107GLM `10de:25b8`, 4GB GDDR6 |
| iGPU | Intel TigerLake-H UHD `8086:9a60` |
| Panel | BOE 0x08CF on eDP-1, **1920x1080**, 340x190mm, ~143 DPI, 16:9 |
| Audio | Realtek **ALC289** on HDA Intel PCH (card 0), driven by `snd_hda_intel` |
| Microphone | Logitech **Brio 100** over USB (added 2026-09-11); the chassis has **none that works**, see below |
| Camera | the same Brio 100; the chassis has **none**, no `/dev/video*` without it |
| Pointing | touchpad only, **no pointing stick** |

The panel is the FHD SKU. Its only modes are 1920x1080@60 and @48, so there is no
4K here, and no 16:10. That single fact invalidates most XPS-era display config.

### The two GPUs drive different ports

From `/sys/class/drm`:

- **NVIDIA (card1)**: `HDMI-A-1`, `DP-1`, `DP-2`, `DP-3`: the physical HDMI and mDP ports
- **Intel (card2)**: `eDP-1`, `DP-4`, `DP-5`: the internal panel and the USB-C DP-alt ports

This is a genuine departure from the XPS, whose dGPU drove no displays at all.
Plugging into HDMI or mDP wakes the dGPU and keeps it awake, which costs battery
and defeats the on-battery dGPU-suspend behaviour that voxtype and the TTS server
both key off. **Prefer USB-C for a projector when on battery.**

The compositor runs on the Intel iGPU. The NVIDIA card is for CUDA and per-app
PRIME offload:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>
```

Quattro's `default/hypr/nvidia.lua` does **not** detect the hybrid setup. It only checks that an NVIDIA GPU exists and then exports `NVD_BACKEND=direct`, `LIBVA_DRIVER_NAME=nvidia` and `__GLX_VENDOR_LIBRARY_NAME=nvidia` to the whole session. `stow/hypr-silver-fox/.config/hypr/envs-device.lua` overrides `LIBVA_DRIVER_NAME` to `iHD` (intel-media-driver), because Chrome's GL context lives on the iGPU and cannot import NVDEC-decoded frames. See the Chrome entry under Traps.

## Disks

Two NVMes are fitted and the OS lives on the **larger** one. Omarchy was reinstalled onto the KIOXIA on 2026-09-14 so that OS and home share one drive, the same layout as rainbow-cat, and this repo carries no storage scripts.

| Device | Size | Slot | Role |
| --- | --- | --- | --- |
| KIOXIA KXG60ZNV1T02, serial `X93ZZ00TK84L` | 953.9G | chipset port `00:1d.0`, Gen3 x4 | **live system**, LUKS + btrfs. The ex-XPS drive. |
| SK hynix BC711, serial `CY12N087910403351` | 238.5G | CPU port `00:06.0`, Gen4-capable | **blank spare**. The drive the Precision shipped with. |

Node numbering (`nvme0n1` / `nvme1n1`) is not stable across boots, so match on serial or use `/dev/disk/by-id/`, never a node.

The slot split looks backwards and is not. Both drives are Gen3 x4 parts and both link at full Gen3 x4, so the CPU-attached slot buys nothing today. It is the slot to use if a Gen4 drive is ever fitted. Opening the chassis to swap them was considered and rejected for that reason.

The alternative that was built and then abandoned (unstaged, never applied) kept the OS on the 256G drive and mounted the KIOXIA at `~/me`: a serial-guarded setup script, a keyfile in crypttab, a chicken-and-egg clone on every reinstall, and a boot-time mount that 42 home symlinks depended on. It also moved the wrong thing. `~/me` was 1.6G, while the sccache dir (capped at 150GiB), `~/.cache` and `~/.local` all stayed on the small drive. Do not rebuild it. If the spare is ever wanted, mount it at a neutral path and point only disposable, growing things at it (sccache, Steam, media), never `~/me`.

## Per-device config, and why

`stow/hypr-silver-fox/` holds four modules, stowed by `just stow-device silver-fox`.

**`monitors.lua`** pins eDP-1 to `1920x1080@60` at **`scale = 1`**, with
`GDK_SCALE=1`. Omarchy's `scale = "auto"` picks **1.5** on this panel, which
leaves a 1280x720 logical desktop; scale 1 gives 1920x1080 logical, near-identical
to the effective 1920x1200 the XPS's 4K panel gave at scale 2. It is a 1080p
panel, so there is no HiDPI to serve and no fractional-scaling blur to accept.
Bump to 1.25 if text is too small; do not go back to `"auto"`.

Also holds the fallback auto-mirror rule (`output = ""`), which catches whatever
an external cable enumerates as.

**`input-device.lua`** sets touchpad `natural_scroll` and `clickfinger_behavior`.
Note the two libinput nodes, `dell0a69:00-0488:120a-touchpad` and
`...-mouse`: same HID device, one physical touchpad. The `-mouse` node is not a
trackpoint and needs no configuration.

**`layout-device.lua`** sets the master layout, `new_status = "master"`. New windows fill
the screen. On one 1080p panel there is no room to give away, which is why this
differs from rainbow-cat's centered column.

**`envs-device.lua`** sets `LIBVA_DRIVER_NAME=iHD`, overriding the session-wide `nvidia` value that Omarchy's nvidia.lua exports whenever any Turing-or-newer NVIDIA GPU is present. Required from the shared `hyprland.lua` right after `hypr.envs`. The header comment carries the measurements. `__GLX_VENDOR_LIBRARY_NAME=nvidia` is deliberately left alone for now: measured with a GLX probe on Xwayland, it makes every X11 GL app render on the A2000 with direct rendering, which works but wakes the dGPU; set it to `mesa` in the same file if X11 apps should default to the iGPU.

### Deleted with the XPS

`scripts/silver-fox/present-mirror` and `mirror-watch.sh` forced both displays to
1080p on hotplug. They existed solely because the XPS's 16:10 panel was squished
~11% when mirrored to a 16:9 projector. This panel is natively 16:9 1080p, so the
plain mirror rule already produces a 1:1 image. Nothing was key-bound to them.

### `scripts/silver-fox/install.sh` is currently a no-op

Both of its root-level fixes are inert on this hardware, and both are kept anyway:

- **Keyboard backlight timeout.** No `dell::kbd_backlight` LED exists.
  `dell_laptop` *is* loaded, so this is not a missing module. The 7560's
  backlight is EC-owned. Change the timeout in the BIOS under
  System Configuration > Keyboard Backlight.
- **S3 deep sleep.** `/sys/power/mem_sleep` reads `[s2idle]` with no `deep`.
  No longer untested: s2idle suspend and resume were exercised twice on
  2026-09-25 (a 92 second sleep and a 3h22m one) and both came back clean, with
  no hard reset and no unclean shutdown on the next boot. The XPS failure this
  block was written for does **not** reproduce here, so the block stays purely
  as a one-BIOS-setting-away fix if that ever changes. The only resume noise is
  a pair of harmless `NVRM: RmHandleDNotifierEvent ... status=0x11` lines.

### A closed lid suspends the machine when the external monitor sleeps

Fixed on 2026-09-25, recorded because the symptom points nowhere near the cause.
This is the only laptop, so it is the only machine that can hit it.

logind keeps re-asking whether a closed lid is still docked, roughly every 30
seconds, for as long as the lid is shut. The Samsung Odyssey G5 drops HDMI
hot-plug detect a few seconds after it powers down, which `omarchy-system-lock`
makes it do on every lock, so the next re-check sees no external display and
applies `HandleLidSwitch` (stock default `suspend`). Locking the screen
therefore slept the machine, and an overnight agent run died at the idle lock.
`just install-logind` installs the `HandleLidSwitchExternalPower=ignore` drop-in
that settles it. Full writeup in `AGENTS.md`, under "Locking a laptop used to
suspend it".

Two tells that identify it in the journal: `systemd-logind: Suspending...` with
no lid event anywhere near it, and `drm: Connector HDMI-A-1 disconnected` in the
Hyprland log five or so seconds earlier.

### There is no working internal microphone

Tested on 2026-09-10 and worth knowing before debugging dictation for an hour. The machine exposes a capture source and it is not muted, but it hears nothing. Dictation works through the Brio 100 instead, next section.

What is there: PipeWire lists `alsa_input.pci-0000_00_1f.3.analog-stereo`, the
ALC289 declares an internal mic pin (`0xb7a60130`, Fixed / Mic at Oth Mobile-In),
`Internal Mic` capture is `[on]`, `Capture` is `[on]`, the `platform::micmute`
LED reads 0, and nothing is muted in `wpctl`.

What it does: nothing. Recording a 4s clip yields a noise floor and no signal.
The noise floor scales with gain, so there is a live analog input being
amplified, but playing a 1 kHz tone through the speakers (confirmed at -24.7 dB
on the sink monitor, i.e. genuinely audible) produced **no change whatsoever** in
the recorded level (-56.8 dB quiet vs -56.5 dB during the tone). That is an
unconnected ADC input picking up electrical noise, not a microphone.

This matches the missing camera. On this chassis the array mics live in the
camera module in the lid, and there is no camera: no `/dev/video*` exists. So
this is a camera-less SKU, and the BIOS ships the same generic codec verb table
regardless, which is why the pin is still declared.

Ruled out along the way: it is not a DMIC/SOF path. The SOF modules load, but
card0 is `PCH` under `snd_hda_intel` with a single `ALC289 Analog` capture PCM
and no DMIC devices, so the codec's analog input is the only capture path there
is.

**Consequence: voxtype dictation cannot work on the internal hardware**, even though the service installs, enables and runs. A headset on the 3.5mm combo jack would also work, since `Headset Mic` is a separate, currently-`[off]` input on the same codec, but the Brio 100 is what is actually in use.

### Logitech Brio 100: the camera and the dictation mic

Plugged in 2026-09-11, USB `046d:094c`, on `usb-0000:00:14.0-11`. Plain UVC plus USB audio class, so nothing to install. It enumerates as ALSA card `B100` (card 2), PipeWire node `alsa_input.usb-046d_Brio_100_<serial>.mono-fallback` ("Brio 100 Mono", 16-bit mono), and `/dev/video0` + `/dev/video1`, which PipeWire also exposes as a V4L2 source. WirePlumber makes it the default source on its own (`priority.session` 2100 beats the internal codec), so voxtype's `device = "default"` needs no change.

**Its mic powers on at maximum gain and clips.** The one mixer control, `Mic Capture Volume`, runs 0..6144 raw for +6dB..+30dB and ships at 6144. Measured at +30dB, the empty room alone is -22 to -27dBFS RMS with peaks near -9dBFS, so there is no headroom left for a voice. `scripts/silver-fox/startup.sh` sets it to **wpctl 0.4** through WirePlumber, which resolves the node by name via `pw-dump` + `jq` (wpctl only takes IDs) and polls in the background so a login without the camera does not stall startup. WirePlumber then persists the value per device in `~/.local/state/wireplumber/default-routes`, so it also survives replug; the startup line is the reassert and the written record.

The mapping, verified against the mixer: total gain = 30 + 60·log10(vol) dB. 0.7 = +21dB, 0.5 = +12dB, **0.4 = +6dB, the hardware floor**. Below 0.4 WirePlumber pins the hardware at +6dB and attenuates in software, which scales the noise floor down with the voice and improves nothing, so 0.4 is the lowest value worth setting. It is a 24dB cut from power-on, picked from the ambient measurement and then confirmed clean with real voxtype dictation the same day. To re-check after a change of room, distance or unit:

```bash
# talk normally for the 8 seconds, then read the peak. Aim for max around -12 to -6dBFS;
# -0.0 means clipping (lower vol), below -25 means room to go up. -ss 0.5 skips the
# stream-open pop: the first ~100ms of every capture is a -11dBFS transient even in silence.
id="$(pw-dump | jq -r '.[] | select(.info.props["node.name"] // "" | test("^alsa_input\\.usb-046d_Brio_100_")) | .id')"
pw-record --target "$id" --rate 16000 --channels 1 --format s16 /tmp/mic.wav & sleep 8; kill -INT $!
ffmpeg -ss 0.5 -i /tmp/mic.wav -af volumedetect -f null - 2>&1 | grep -E '(mean|max)_volume'
```

If it needs adjusting, change the `0.4` in `startup.sh` and apply it live with `wpctl set-volume "$id" <vol>`; each 0.1 step above 0.4 is worth roughly 5 to 6dB.

### The old mic gain line in startup.sh is gone

Until 2026-09-11 `scripts/silver-fox/startup.sh` set `wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.13`, the XPS-era calibration for the internal Realtek (Capture +6.75dB, boost off). It was correct for that codec and pointless here, because nothing is behind it. With the Brio plugged in it became actively wrong: the Brio is now the default source, and 0.13 on its curve is -23dB total, 29dB below its own hardware floor, all of it software attenuation. The line was replaced by the name-targeted Brio one above rather than kept alongside it. If a 3.5mm headset ever becomes the mic, it is a separate WirePlumber route (`analog-input-headset-mic`) with its own persisted volume, so the old 0.13 would not have carried over to it anyway.

## State as of 2026-09-10

Omarchy `4.0.3-1` (`omarchy-version`), kernel `7.2.3-arch1-3`.

**Working:** all stow packages linked; mise runtimes (node, deno, zig, python) and
the wrangler/cf/claude-agent-acp wrappers; Everforest theme with the Firewatch
wallpaper; Never-Lost-Rainbow cursor; transcribe and tts helpers on PATH; Kokoro
TTS built, enabled and **running on CUDA** (the NVIDIA driver, `nvidia-open-dkms`
610.57.04, came with the fresh Omarchy install); `just pull-repos` clones cleanly
including private repos.

**Root half done** via `just init-silver-fox-sudo`: ghostty, google-chrome,
visual-studio-code-bin, voxtype-bin, rustup + cargo-binstall, cuda, steam,
element-desktop, thunderbird, helix, podman are all installed, and
`voxtype.service` is enabled and active, listening through the Brio 100 since 2026-09-11 (the internal codec has nothing behind it, see the microphone section).

That recipe now runs under `scripts/sudo-keepalive.sh`. The first attempt died
halfway through at `install-rust` with `sudo: timed out reading password`,
because a bare `sudo -v` only holds for five minutes and the install takes about
an hour. The wrapper refreshes the timestamp every 50 seconds for the life of the
run, so it asks once at the start and never again. `just init`,
`just init-silver-fox` and `just init-rainbow-cat` are wrapped the same way.

## Traps

- **Do not trust pre-2026-09-10 silver-fox notes.** They describe the XPS: 4K
  16:10 panel, GTX 1650 Ti, i7-10750H, a dGPU that drove no displays. That
  machine's record was deliberately deleted in commit `3a0a0ec`; do not restore
  it, and do not carry its facts forward.
- **`hyprctl devices` shows two mice for one touchpad.** Not a trackpoint.
- **The internal capture source is not a microphone.** Don't take the presence of `alsa_input...analog-stereo`, an unmuted `Internal Mic` control, or a running `voxtype.service` as evidence that dictation can work without the Brio 100 plugged in.
- **The Brio 100 mic clips at its power-on gain.** If dictation goes to garbage after a fresh install or a wiped `~/.local/state/wireplumber`, check `wpctl get-volume` on the Brio source reads 0.40, not 1.00.
- **Long installs need `scripts/sudo-keepalive.sh`.** A bare `sudo -v` lapses
  after five minutes and the run dies mid-way once nobody is at the keyboard.
- **Never address a disk by node.** `nvme0n1` and `nvme1n1` swap between boots. Match on serial or `/dev/disk/by-id/`: the system KIOXIA is `X93ZZ00TK84L`, the spare SK hynix is `CY12N087910403351`.
- **Rendering corrupts after the monitor sleeps, and it is not the app's fault.** Diagnosed 2026-09-25, when it presented as "a black bar at the bottom of the screen and Zed drawing wrong". Neither is an app bug. The desk monitor is on HDMI, which is wired to the NVIDIA card, so Hyprland composites on the Intel iGPU and blits every frame across to the dGPU for scanout. When the monitor sleeps, that secondary renderer is torn down (`drm: Deinitializing secondary renderer on /dev/dri/card1, no enabled outputs`) and rebuilt on wake, and it can come back broken: `EGL (blit): glCheckFramebufferStatus failed: 1282` fires on every cursor move. Because the blit is damage-tracked, only regions an app repaints get re-copied, so a static strip keeps showing stale content and the busiest UI on screen looks the most corrupt. That is why Zed looked guilty. Confirm with `nvidia-smi`: if the app is not listed, it is not rendering on the dGPU and the problem is below it. Two fixes, in order of how well they work: cycle DPMS (`hl.dsp.dpms` off then on) to clear the EGL errors, then force full damage by retiling (spawn or close any window) to repaint the stale regions. The real fix is to stop blitting at all, by moving the monitor to a USB-C port. See below.
- **The USB-C ports are the Intel side.** `card2-DP-4` and `card2-DP-5` are DP-alt on the Tiger Lake-H Thunderbolt 4 controller, so a monitor plugged in there is native to the compositor's own GPU: no cross-GPU blit, nothing to rebuild on wake, and the dGPU is free to idle. HDMI and mDP are hardwired to the NVIDIA card by Dell and no software setting reroutes them. A USB-C to DisplayPort cable is the whole fix; verify 2560x1440@144 survives the move before trusting it.
- **Chrome flickered and blanked on video calls (Blackboard Collaborate, any WebRTC or hardware-decoded video).** Cause: `LIBVA_DRIVER_NAME=nvidia` from Omarchy's nvidia.lua. Chrome 153 has hardware decode on by default, decoded on the A2000, and its Intel-side GL context failed `eglCreateImage` with EGL_BAD_MATCH on every frame (about 1000 failures in 17 s of a WebRTC loopback) until the window stopped painting. Fixed 2026-09-22 by `envs-device.lua` forcing `iHD`. If it comes back after an Omarchy update, check that `systemctl --user show-environment | grep LIBVA` reads `iHD` and that `hyprland.lua` still requires `hypr.envs-device` after `hypr.envs`. Upstream: omacom/omarchy#12704.
