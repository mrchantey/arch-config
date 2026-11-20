# rainbow-cat: ASUS Z370-E desktop

The standing record of `rainbow-cat`: measured hardware, the per-device config and why it is the way it is, what was replaced, and the machine-specific traps. Read it before changing anything under `stow/hypr-rainbow-cat/` or `scripts/rainbow-cat/`, and update it whenever the machine's hardware or device config changes.

A self-built tower, originally a Windows gaming and streaming machine, now running Omarchy with Windows kept on its own drive for dual boot. The NVIDIA card is the compositing GPU, so unlike silver-fox there is no hybrid graphics to work around.

**The Hardware and Disks tables were measured on the machine on 2026-11-16.** The Original build list is the purchase record and was not re-verified item by item.

## Hardware

| | |
| --- | --- |
| Motherboard | ASUS ROG STRIX Z370-E GAMING, BIOS 2401 (2019-07-12) |
| CPU | Intel i7-8700K, 6c/12t, Coffee Lake |
| RAM | 32GB DDR4 (bought as two G.Skill Trident Z RGB 3200 kits of 2x 8GB) |
| GPU | NVIDIA GeForce RTX 3080 Ti, GA102 `10de:2208`, 12GB, drives every display |
| Monitor | Samsung C49RG9x ultrawide on DP-1, 5120x1440@120, scale 1.25 |
| Side monitor | none; the Samsung C24F390 moved to silver-fox's desk on 2026-11-20. Its rule stays in `monitors.lua` |
| Audio | Intel Z370 HD Audio `8086:a2f0`, plus the GPU's HDMI audio |
| Speakers | KEF LSX II LT, as a USB sink |
| Microphone and camera | Logitech BRIO 4K over USB (`046d:085e`) |
| Pointing | Kensington SlimBlade trackball, used left-handed; Logitech G903 on its Lightspeed receiver when plugged in |
| Keyboard | Kinesis Advantage2 |
| Cooler | Corsair H115i, reports over USB as `1b1c:0c13` |
| Network | Intel I219-V ethernet, ASUS onboard Bluetooth |

## Disks

| Device | Size | Role |
| --- | --- | --- |
| Samsung 870 QVO 2TB, serial `S5SUNG0N806690H` | 1.8T | **live system**: `/boot` plus LUKS + btrfs root and home, booted by Limine |
| Samsung 970 EVO 500GB NVMe, serial `S466NX0K437659N` | 465.8G | **Windows**, booted by Windows Boot Manager. Never format it |
| Samsung 860 EVO 1TB, serial `S4FMNF0M813843P` | 931.5G | `media-windows`, NTFS, not mounted |
| Samsung 860 EVO 500GB, serial `S3YANB0K153198X` | 465.8G | `media-linux`, exFAT, not mounted |

OS and home share one drive, the same layout as silver-fox. SATA letters (`sda`, `sdb`, ..) are assigned in probe order, so match on serial or use `/dev/disk/by-id/`, never a node.

## Per-device config, and why

`stow/hypr-rainbow-cat/` holds three modules, a `quickshell` wrapper and two WirePlumber drop-ins, stowed by `just stow-device rainbow-cat`. There is no `envs-device.lua`: Omarchy's `nvidia.lua` sets the session for an NVIDIA compositing GPU, which is exactly what this machine is.

**`.local/bin/quickshell`** runs the Omarchy shell with `__NV_DISABLE_EXPLICIT_SYNC=1`, the workaround for the shell freezing after suspend (see Traps). Its header has the mechanism and when to delete it.

**`.config/wireplumber/wireplumber.conf.d/`** keeps the KEF's USB sink from ever suspending (`kef-lsx-no-suspend.conf`, see Traps) and auto-connects the A2DP profiles of Bluetooth audio devices (`bluetooth-a2dp-autoconnect.conf`). Stow links them beside the shared `pipewire` package's drop-ins, so that directory is a real one here. WirePlumber reads them only at startup.

**`monitors.lua`** matches both monitors by description rather than port, so moving a cable to another DP or HDMI port does not break the config. The ultrawide sits at `0x0`, so it is the primary for synced workspaces and shows 1-10 (see the header of the shared `workspaces.lua`); the side monitor sits to its right at `4096x0` and shows 11-20. Workspace 1 is named `beet`. The side monitor gets a left-oriented master column from a `workspace = "m[desc:...]"` rule, which follows whatever workspace it is showing rather than an id range. That two-monitor behaviour has not been verified on this hardware since the side monitor was disconnected. `GDK_SCALE` is 1.

**`input-device.lua`** sets `left_handed = true` for the mouse.

**`layout-device.lua`** opens new windows as a centered master column with slaves flanking it across the wide screen (`orientation = "center"`, `new_status = "slave"`). Required after the shared `looknfeel.lua` so it wins.

**`scripts/rainbow-cat/install.sh`** (`just install-rainbow-cat`) keeps the G903's Lightspeed receiver on `hid-generic`, see Traps.

**`scripts/rainbow-cat/startup.sh`** sets the BRIO's mic gain at login, then opens Zed on `~/me/beet` on workspace 1.

## Microphone and camera

The BRIO 4K is the voxtype mic, PipeWire node `alsa_input.usb-046d_Logitech_BRIO_<serial>.analog-stereo`. The motherboard's analog input is also a source, so the BRIO is targeted by node name, never as `@DEFAULT_AUDIO_SOURCE@`. It powers on at full-scale capture gain (wpctl 1.0, hardware +54dB) and clips hard, so `startup.sh` sets it to **wpctl 0.30** (+22.6dB) through `scripts/mic-gain.sh` at every login, and WirePlumber persists it. Its gain is cubic, total dB = 54 + 60·log10(vol), clamped at the +18dB hardware floor below ~0.25. The calibration history is in the script's comment.

Browser calls used to raise this gain and leave it raised; the fix is in [chromium-flags.md](../chromium-flags.md).

## Replaced hardware

| Part | Was | Now |
| --- | --- | --- |
| Graphics card | MSI GeForce GTX 1080 Gaming X 8GB ($849, [mwave](https://www.mwave.com.au/product/msi-geforce-gtx-1080-gaming-x-8gb-video-card-ab83036)) | NVIDIA GeForce RTX 3080 Ti 12GB |
| Main monitor | Acer XB280HK 28" 4K G-Sync, preceded by an XB281HK ($499, [mwave](https://www.mwave.com.au/product/acer-xb281hk-28-4k-uhd-gsync-widescreen-gaming-monitor-ab88364)) | Samsung C49RG9x ultrawide |
| System drive | Windows only, on the 970 EVO | Omarchy on the 870 QVO 2TB, Windows kept on the 970 EVO |

## Original build

The purchase record, prices in AUD, with the replaced parts moved to the table above. Peripherals listed here may since have left the desk.

| Part | Model | Price | Link |
| --- | --- | --- | --- |
| CPU | Intel i7-8700K | 798 | [mwave](https://www.mwave.com.au/product/bundle-deal-intel-i7-8700k-asus-rog-strix-z370e-gaming-atx-motherboard-ac10866) |
| CPU cooler | Corsair Hydro Series H115i PRO RGB 280mm | 189 | [mwave](https://www.mwave.com.au/product/corsair-hydro-series-h115i-pro-rgb-280mm-performance-liquid-cpu-cooler-ac10725) |
| Motherboard | ASUS ROG STRIX Z370-E | 0 (bundled with the CPU) | [mwave](https://www.mwave.com.au/product/asus-rog-strix-z370e-gaming-lga-11512-atx-motherboard-ac08808) |
| Memory | 2x G.Skill Trident Z RGB 16GB (2x 8GB) DDR4 3200 | 2x 299 | [mwave](https://www.mwave.com.au/product/gskill-trident-z-rgb-16gb-2x-8gb-ddr4-3200mhz-memory-ab94981) |
| SSD | Samsung 970 EVO 500GB NVMe | 289 | [mwave](https://www.mwave.com.au/product/samsung-970-evo-500gb-nvme-13-m2-2280-3d-vnand-ssd-mzv7e500bw-ac13203) |
| SSD | Samsung 860 EVO 500GB SATA | 185 | [mwave](https://www.mwave.com.au/product/samsung-860-evo-500gb-25-sata-iii-6gbs-vnand-ssd-mz76e500bw-ac11457) |
| Case | Corsair Obsidian 750D Airflow Edition | 209 | [mwave](https://www.mwave.com.au/product/corsair-obsidian-750d-air-flow-edition-full-tower-case-ab63904) |
| PSU | EVGA SuperNOVA 750W G2 80+ Gold Modular | 159 | [mwave](https://www.mwave.com.au/product/evga-supernova-750w-g2-80-gold-modular-power-supply-ab58319) |
| OS | Windows 10 Home | 159 | [mwave](https://www.mwave.com.au/product/microsoft-windows-10-home-with-creators-update-3264bit-usb-drive-ac11442) |
| Camera | Logitech Brio 4K USB webcam | 259 | [mwave](https://www.mwave.com.au/product/logitech-brio-4k-ultra-hd-usbc-webcam-ac03497) |
| Microphone | Zoom H5 Handy Recorder | 369 | [storedj](https://www.storedj.com.au/zoom-h5-handy-recorder) |
| Mouse pad | SteelSeries QCK XXL | 49 | [mwave](https://www.mwave.com.au/product/steelseries-qck-xxl-gaming-mouse-pad-extended-ab67969) |
| Side monitor | Samsung C24F390FHE | 169 | [mwave](https://www.mwave.com.au/product/samsung-c24f390fhe-235-fhd-va-curved-freesync-lcd-led-monitor-ab84591) |
| Keypad | Razer Orbweaver Chroma Elite | 179 | [mwave](https://www.mwave.com.au/product/razer-orbweaver-chroma-elite-rgb-mechanical-gaming-keypad-ab68428) |
| Mouse | Logitech G903 | 179 | [mwave](https://www.mwave.com.au/product/logitech-g903-lightspeed-wireless-gaming-mouse-ac06663) |
| Mouse | Kensington SlimBlade | 109 | [mwave](https://www.mwave.com.au/product/kensington-slimblade-trackball-mouse-aa25905) |
| Mouse | Logitech MX Ergo | 109 | [mwave](https://www.mwave.com.au/product/logitech-mx-ergo-wireless-trackball-mouse-ac09077) |
| Mouse | Logitech M570 | 69 | [mwave](https://www.mwave.com.au/product/logitech-m570-wireless-trackball-mouse-aa25833) |
| Headset | HyperX Cloud Revolver | 219 | [mwave](https://www.mwave.com.au/product/hyperx-cloud-revolver-s-71-surround-gaming-headset-gun-metal-ac12831) |
| Monitor stand | 2x Vision Gas Single LCD Monitor Arm, desk mount 15"-27" | 2x 59 | [mwave](https://www.mwave.com.au/product/vision-mounts-gas-spring-single-lcd-monitor-arm-with-desk-mount-1527-ab80027) |
| Capture card | Elgato Game Capture HD60 Pro | 289 | [mwave](https://www.mwave.com.au/product/-elgato-game-capture-hd60-pro-ab68181) |
| Game console | Xbox One S | 399 | [mwave](https://www.mwave.com.au/product/microsoft-xbox-one-s-console-only-500gb-ac05320) |

The original build totalled $6,450, replaced parts included.

## State as of 2026-11-16

Omarchy `4.5.0-3` (`omarchy-version`), kernel `7.2.15-1-omarchy`, NVIDIA driver 615.78.08.

## Traps

- **Never format the NVMe.** `nvme0n1` is the Windows install, not spare space; Omarchy lives on the 870 QVO.
- **The G903 drops drags mid-flight under `hid-logitech-dj`.** The driver turns the receiver's sub-second RF link-loss notification into a null report that releases every held button. `install.sh` stops the module loading by any path (`install ... /bin/true`, since a bare `blacklist` is still autoloaded via the HID modalias) and rebinds the receiver to `hid-generic`. The cost is no battery reporting through the receiver.
- **The shell froze on the first unlock after every suspend**, from 2026-11-13 to 2026-11-18 on driver 615.78.08 (open modules, `NVreg_UseKernelSuspendNotifiers=1`), until the `quickshell` wrapper above disabled explicit sync for it on 2026-11-18; the next resume logged no semsurf error and the shell unlocked normally. The bar stops updating and `omarchy restart shell` fails after two minutes with "did not become ready". It is not CPU load: the system is idle while one `QSGRenderThread` pins a core inside `libnvidia-eglcore` (in `QOpenGLContext::makeCurrent`), and the main thread waits on it, so IPC (including `quickshell kill`) is never served and the replacement `quickshell -n` refuses to start beside it. Sleep-lock draws the lock surface about 150ms before logind suspends, and on resume nvidia-drm logs `Failed to register auto-value-update on pre-wait value for sync FD semaphore surface`: that frame's fence never signals, and unlocking tears down the lock surface onto it. Diagnose with `journalctl -k -b | grep semsurf` and `top -H -p $(pgrep -x quickshell)`. Recover with `pkill -TERM -x quickshell`; the original `omarchy-launch-shell` relaunches it within a second.
- **The lock screen looks like it won't wake.** While locked, Omarchy's lock blanks every display 5s after the last input (`idleBlankTimer` in `/usr/share/omarchy/shell/plugins/lock/Service.qml`, hardcoded). The C49RG9x takes about 4s to come out of standby, so a single keypress shows the lock for about a second before it blanks again, which reads as a failed resume. The machine is awake and the password field takes input while dark, so typing the password unlocks regardless.
- **Audio can vanish after a resume.** If WirePlumber rescans the sound cards before logind re-grants the session's device ACLs, it logs `snd_pcm_info() failed Permission denied`, keeps only "Dummy Output" and no sources, and dictation fails with `Recording timeout: exceeded 2 seconds` even though Insert reaches voxtype. Seen once in seven resumes (2026-11-18). `systemctl --user restart wireplumber` restores every device, and the BRIO's persisted gain with it.
- **The KEF stops answering after an idle suspend.** Its USB firmware fails control requests (`usb_set_interface -110`) once the host stops the stream, and only a replug recovers it, so `kef-lsx-no-suspend.conf` keeps the stream open.
- **The BRIO clips at its power-on gain.** If dictation goes to garbage, check `wpctl get-volume` on the BRIO's node reads 0.30, the value in `startup.sh`; if it has drifted up after a call, a browser flag is missing or the browser has not been restarted since it was added.
