- Start every chat with 'evnin partner'


# Editing OS Config

This is my omarchy config, located at `~/me/arch-config`.
Omarchy 4 ("quattro") installs to `/usr/share/omarchy` (read-only, never edit; `~/.local/share/omarchy` is a back-compat symlink to it), and to `~/.config`, some of which is overridden via stow.
Generated state (current theme, toggles, workspace layouts) lives in `~/.local/state/omarchy`, which is where `current/theme/...` moved to from `~/.config/omarchy/current`.

When asked to make changes use these files as reference to understand the system, and ensure install scripts are updated so the changes are reflected in a fresh install.

## Hyprland is configured in Lua

Quattro replaced the `*.conf` + `source =` chain with native Lua. `~/.config/hypr/hyprland.lua` is the entry point; everything else is a module resolved off `package.path` (`~/.config/?.lua`, then `$OMARCHY_PATH/?.lua`). Omarchy's defaults are loaded first via `require("default.hypr.omarchy")`, so our modules override them.

Reference for the API: type stubs at `/usr/share/hypr/stubs/hl.meta.lua` (wired up for the LSP by `hypr/.luarc.json`), and Omarchy's own defaults in `/usr/share/omarchy/default/hypr/`.

Three gotchas that differ from the old `.conf` files:

- **Re-binding a key does not replace the old bind, both fire.** Call `hl.unbind("SUPER + F")` before `o.bind(...)`. Every unbind in `bindings.lua` names the default it displaces.
- **`hyprctl dispatch` also takes Lua now, not bare words.** `hyprctl dispatch workspace 4` and `hyprctl dispatch focuswindow address:0x...` both fail with a Lua parse error; the working forms are `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'` and `hl.dsp.window.close({ ... })`. The dispatcher namespace is enumerated under `HL.DspNamespace` in the stubs. This bites scripts, not config, and it fails loudly on stdout, so a script that redirects to `/dev/null` looks like it worked.
- **Keysyms must match xkbcommon exactly.** `Page_Up`/`Page_Down`, not `PAGEUP`/`PAGEDOWN`; `comma`, not `COMMA`. The old parser was forgiving, the Lua binder is not. Validate with `hyprctl reload && hyprctl configerrors`, which reports these.

Only `hyprsunset.conf` and `xdph.conf` are still `.conf`: they are read by separate processes, not Hyprland, so `hyprctl` neither applies nor validates them.

## Per-device config

Most config is common, stowed by the `hypr` package and shared `just` recipes.
Naming convention: `*.lua` is shared (common `hypr` package); `*-device.lua` and `monitors.lua` are per-device and live in a stow package named after the machine (`stow/hypr-rainbow-cat`, `stow/hypr-silver-fox`), stowed by `stow-device <name>` and selected via `init-<name>`. The per-device files are `monitors.lua`, `input-device.lua`, `layout-device.lua`.

Device modules are loaded with `require_optional` so a machine whose device package isn't stowed still boots.

Input is split: shared settings (keyboard, scroll speed, trackball) live in the common `hypr/input.lua`, and each device's `input-device.lua` holds only its overrides (left_handed, touchpad gestures). `input.lua` is required before `input-device.lua` so per-device settings win. When editing monitors or window-layout settings, edit the right device package; shared input or anything else goes in the common `hypr` package.

`layout-device.lua` holds the master-layout `master` block (required after the shared `looknfeel.lua` so it overrides it): rainbow-cat opens a centered master column for its ultrawide; silver-fox opens windows full-screen.

`monitors.lua` also owns `GDK_SCALE` and workspace-to-monitor pinning (`hl.workspace_rule`). There is no `envs-device.lua`: Omarchy detects the NVIDIA GPU and sets `NVD_BACKEND` / `LIBVA_DRIVER_NAME` / `__GLX_VENDOR_LIBRARY_NAME` itself (see `default/hypr/nvidia.lua`).

## Dev tooling goes through mise

Quattro made mise (pacman package, `/usr/bin/mise`) the backbone for language runtimes and CLI tools. Two distinct mechanisms, don't mix them up:

- **Runtimes** are plain global mise installs: `omarchy-install-dev-env <node|deno|zig|go|python|bun|java|ruby|elixir|dotnet|clojure|scala>`, which is the same entry point as Menu > Install > Development. It boils down to `mise use -g <tool>@latest`.
- **CLI tools** are `omarchy-mise-install <package> [command] [bin]`, which writes a four-line wrapper into `~/.local/bin/<command>`. Every invocation runs `mise use -g <package>` then `mise x`, so the tool installs on first use and self-updates thereafter. `MISE_MINIMUM_RELEASE_AGE=0` is exported inside the wrapper to bypass mise's release cooldown. Omarchy ships a fleet of these in `install/user/mise.sh`: claude, codex, gemini, crush, copilot, opencode, gh, playwright, pi, omp, grok, ghui, hunk. Never install those a second way, `omarchy-mise-install` starts by `rm -f`-ing the target path, so a competing pacman/AUR/npm install just becomes shadowed dead weight.

**Former gotcha, now fixed upstream: those wrappers used to write to stdout.** `mise use -g` prints `mise <config> tools: <pkg>@<version>` on stdout every run, not just on an install, so every `omarchy-mise-install` tool prepended a junk line to its own output, which is harmless for a TUI but not when the output is piped or parsed (`gh api ... | jq` got a bad first line). As of the omarchy on this machine (`omarchy-version` reports 4.0.3-1, checked 2026-09-10) `omarchy-mise-install` writes `mise use -g --quiet`, which silences that line while leaving install progress visible, so the wrappers are stdout-clean. Verified directly: `gh --version` through the wrapper, and `gh auth git-credential get` (whose stdout git itself parses), both emit only their own output.

Re-check `omarchy-mise-install` before relying on this. If a version ever drops `--quiet`, the rule returns: do not front a tool whose stdout is a data channel with it. `scripts/claude-agent-acp.sh` is the worked example from when that mattered: a hand-rolled copy of the wrapper with the `mise use` line redirected to stderr, because Zed speaks JSON-RPC to it over stdio. It is belt-and-braces now rather than load-bearing, and is kept because it costs nothing. Don't reach for `MISE_QUIET=1` as a global fix, it also silences install progress, so a first run that downloads 100MB looks like a hang.

Not everything is mise. Rust is rustup (we take pacman's `rustup` rather than omarchy's rustup.rs curl installer, same toolchain manager either way), PHP is pacman, OCaml is opam, and uv comes from astral's install script, which `omarchy-install-dev-env python` runs alongside the mise interpreter.

Python is worth understanding rather than copying. Arch's `/usr/bin/python` rolls minor versions and takes every venv built against it along, which is the actual reason python hurts on this distro; mise's interpreter is what insulates you from that, so install it even though nothing here calls `python` directly. Two things to know about the uv half. Pass `UV_NO_MODIFY_PATH=1`, or astral's installer appends a `. ~/.local/bin/env` line to our *stowed* `.bashrc` on every run, editing a tracked file to add a `~/.local/bin` that `.bashrc` already puts on PATH itself. And because a curl-installed uv is in neither pacman nor mise, nothing in `omarchy update` moves it, so `stow/omarchy/.config/omarchy/hooks/post-update.d/uv-self-update` runs `uv self update` from omarchy's own post-update hook. Never add a second uv from pacman: `~/.local/bin` is *prepended* by `.bashrc` but *appended* by `env-bootstrap`, so terminals would get one uv and GUI apps the other, which is the same split that Vite+ caused for node.

Our additions live in `just install-mise-tools`: the node/deno/zig/python runtimes, plus `wrangler`, `cf` and the Zed ACP adapter as wrappers. Anything that needs a global CLI belongs there, not in an `npm install -g`. It runs before `init-user` in `just init` because `setup-tts` builds the kokoro venv with uv and would otherwise hit `uv: command not found`.

PATH is assembled by `/usr/share/omarchy/default/bash/env-bootstrap`, which appends `~/.local/share/mise/shims` then `~/.local/bin`; `default/bash/init` adds `mise activate bash` for interactive shells, and a `PATH` line in `/etc/security/pam_env.conf` covers `ssh host cmd`, which runs no shell setup at all. Because that all happens outside `.bashrc`, anything prepended in `stow/bashrc/.bashrc` wins over mise for terminals only, and GUI-launched apps keep getting the mise version. That split is exactly what removing Vite+ fixed, so think twice before putting another runtime ahead of the shims there.

Updates flow through `omarchy update`, which calls `omarchy-update-mise` (`MISE_MINIMUM_RELEASE_AGE=0 mise up`). The `mup` alias is the same thing by hand.

## Transcription

Three tools, all on PATH from `scripts/` via `just install-transcribe` and `just install-transcribe-file`, and all sharing one 4 GB GPU with the voxtype and kokoro daemons:

- `voxtype` is dictation: push-to-talk, whisper.cpp on Vulkan running large-v3-turbo, model kept resident so capture is instant, clips capped at 60 s, with the replacement dictionary in `stow/voxtype/.config/voxtype/config.toml`. Do not use it for files.
- `transcribe [name]` records the mic to `name.wav` and transcribes it with voxtype's engine to `name.txt`. Plain text, no timestamps; for a quick note, not a lecture.
- `transcribe-file <file> [--out BASE] [--title TEXT]` is for existing audio or video. faster-whisper (CTranslate2 on CUDA), Silero VAD so long silences do not turn into hallucinated text, segment timestamps, and a model ladder that picks the biggest Whisper that fits: on the A2000 that is large-v3-turbo, since large-v3 shares turbo's encoder (which alone peaks near 3.5 GB) and its extra decoder weights do not fit in any configuration. Writes `BASE.md` (paragraphs prefixed `**[hh:mm:ss]**`, header names the model), `BASE.srt` and `BASE.segments.json`. A 75 minute recording takes about 2.5 minutes. `transcribe-file --help` has the options. Setup is `just setup-transcribe-file`: a uv venv at `~/.local/share/whisper-venv` with the CUDA runtime wheels, and large-v3-turbo in `~/.cache/huggingface`.

`gpu-exclusive <cmd>` is the handoff both transcribers use: it stops whichever of `voxtype.service` and `kokoro-tts.service` are running, runs the command, and restarts exactly those from an EXIT trap, so an error or Ctrl-C still brings dictation back. Its status lines go to stderr, the command's stdout is untouched, and `GPU_EXCLUSIVE_SERVICES=voxtype.service` narrows it (the mic `transcribe` does this so kokoro keeps talking). Nested calls are no-ops via `GPU_EXCLUSIVE=1`. Anything else that wants the whole card should go through it rather than growing its own stop/start.

Lessons that cost time: Hugging Face downloads through `hf_xet` stall indefinitely on silver-fox (75 MB then nothing), so both the setup recipe and the script export `HF_HUB_DISABLE_XET=1`; if a model still will not come down, `curl -L https://huggingface.co/<repo>/resolve/main/<file>` the four files (`config.json`, `model.bin`, `tokenizer.json`, `vocabulary.txt`) into a folder and pass it to `--model`. CTranslate2 dlopens `libcublas.so.12` and `libcudnn*.so.9`, which the script supplies from the pip wheels via `LD_LIBRARY_PATH`, so pacman's CUDA is not involved. A stopped kokoro sits in `failed` rather than `inactive` (uvicorn exits non-zero on SIGTERM); `systemctl --user start` works from there. Neither pipeline does speaker diarisation; WhisperX with pyannote would, at the cost of gated model downloads and another 2 GB of VRAM, so it is not set up.

## Cursor theme

The pointer is Never-Lost Rainbow, converted from the Windows `.ani` set in `neverlost/` (see its readme for what the conversion changes). `just install-cursor-theme` runs `scripts/install-cursor-theme.py`, which builds the XCursor theme into `~/.local/share/icons/Never-Lost-Rainbow`. That script also owns the Windows-role-to-X11-name mapping, so it is the file to edit to change which cursor plays which role.

`cursor-toggle` (on PATH, from `scripts/cursor-toggle.sh`) turns it on and off, falling back to the system default theme. State is the flag file `~/.local/state/cursor-off`, on the same pattern as `presentation-mode`.

`XCURSOR_THEME` and `XCURSOR_SIZE` are set in the shared `hypr/envs.lua`, which is required from `hyprland.lua` after Omarchy's defaults so it overrides their size of 24. It reads the same flag the toggle writes, which is what makes the choice survive a reload. Both branches assign every variable, because `hyprctl reload` can overwrite an env var but never unsets one. GTK apps read the theme from gsettings instead, which the toggle sets.

## Shared pictures

`~/Pictures/shared` is a mirror of the `pictures/` prefix of the `mrchantey-os` S3 bucket (wallpapers, headshots, the omarchy-logo template), shared across machines and tracked in no repo. `just pull-pictures` syncs it down and `just push-pictures` syncs it up with `--delete`, so a file removed locally is removed from the bucket on the next push. `init-user` runs the pull on a fresh install, but the bucket policy only makes `GetObject` public, not `ListBucket`, so the sync needs `aws configure` first; without credentials the recipe prints a SKIP and exits 0 rather than failing `init`, and the README's AWS step says to rerun it. Individual files remain fetchable unsigned at `https://mrchantey-os.s3.us-west-2.amazonaws.com/pictures/<path>`, which is how `stow-files-init` gets the Firewatch wallpaper before aws is configured.

## Keeping single-instance apps on the current workspace

Chrome, Zed, Nautilus and Element all hand a second invocation to the already-running process over an IPC socket instead of starting fresh. That process places the payload (a URL, a file, a folder) in whichever of its windows was activated last, which is routinely on a workspace you cannot see. Hyprland cannot fix this: no window is created, so there is no event for a window rule to match on. It has to be handled at the launch site.

`scripts/launch-here.sh` is the shared helper:

```
launch-here <class-regex> <new-window-flag> <command> [args...]
```

It focuses the most recently focused matching window on the *active* workspace, making it the one the app considers last-activated, then hands the payload over. With no match here it falls back to `<new-window-flag>`, so a fresh window opens on this workspace instead of joining one elsewhere. Invocations with no payload (`--help`, `--incognito` from `omarchy-launch-browser`) pass straight through, so nothing that merely launches an app is affected.

Anchor the class regex. `^google-chrome$` deliberately excludes Chrome PWA windows, whose class is `chrome-<appid>-Default`. Matching follows `omarchy-hyprland-focus-app` in checking `.class` then `.initialClass`.

Only Chrome is wired up so far, via `stow/mimeapps/.local/share/applications/google-chrome.desktop`, which **shadows** the packaged entry. Reusing the `google-chrome.desktop` ID rather than adding a new one is deliberate: `mimeapps.list` already points at that ID, and Chrome's own default-browser check compares against it, so a differently-named wrapper would make Chrome nag on every launch. The cost is that the shadowing copy is a hand-trimmed subset of the packaged file, so a Chrome release that adds a field will not reach us until it is copied across. Adding another app is one more shadowing `.desktop` with a different `Exec` line; Zed is the obvious next candidate, since files opened from elsewhere land in an arbitrary one of its windows.

`Exec` does not point at `launch-here` directly, it points at `scripts/chrome-here.sh`, which bakes in the class regex, the new-window flag and the chrome binary. That indirection is load-bearing. `omarchy-launch-webapp` and `omarchy-launch-browser` both resolve "the browser" by `sed`-ing the *first whitespace-delimited token* out of `Exec=` and then calling it with chrome's own flags (`--app=<url>`, `--incognito`). With `launch-here` first they called it as `launch-here --app=<url>`, which misses its `<class-regex> <new-window-flag> <command>` signature and exits 2; `omarchy-launch-webapp` wraps the call in `setsid`, so every webapp keybind failed silently. Anything put first in that `Exec` line has to be a drop-in for the browser binary. One residue remains: `omarchy-launch-browser` derives its post-launch focus regex from `basename` of that token, so with a shim there it matches nothing and the focus call no-ops (harmless here, `bindings.lua` avoids that focuser deliberately).

### The related Super+B bug is a different failure mode

`bindings.lua` bypasses `omarchy-launch-browser` for a problem that looks the same but is not. There the launch was always correct, `--new-window` opens here; the damage came afterwards from `omarchy-hyprland-focus-app`, which picks `first(...)` in `hyprctl clients` order with no regard for workspace and yanked focus away. That is focus stealing, fixed by not calling the focuser, so those bindings stay as plain `--new-window` launches and do not route through `launch-here`, which in that mode would add indirection and no behaviour change.

## The bar, launcher, and idle are one Quickshell process

Quattro replaced waybar (bar), walker + elephant (launcher), mako (notifications), swayosd (OSD), and hypridle + hyprlock (idle/lock) with a single long-running Quickshell process, `omarchy-shell`. All of those packages are uninstalled and their stow packages are deleted.

It is configured by `~/.config/omarchy/shell.json`, which hot-reloads on save. Our copy is tracked at `files/omarchy/shell.json` and **copied** into place by `just stow-files`, not stowed: `omarchy-shell-config` writes the file with `mktemp` + `mv`, which would replace a symlink with a regular file the first time anything edits the bar. Use `just pull-files` to capture GUI-made changes back into the repo.

Idle timings (`idle.screensaver`, `idle.lock`, in seconds) live there too, replacing `hypridle.conf`. There is no display-off setting: `omarchy-system-lock` turns the display off itself.

To customize a built-in widget, never edit `/usr/share/omarchy/shell/plugins/`; clone it with `omarchy plugin clone omarchy.<widget>`, which switches the bar to `<username>.<widget>` under `~/.config/omarchy/plugins/`.

### Devices

`silver-fox`
	- Dell Precision 7560 laptop (replaced the XPS 15 9500 on 2026-09-10; the XPS
	  is dead and gone). Full record: the `info-silver-fox` skill.
	- i7-11850H (8c/16t, Tiger Lake-H), 64GB RAM
	- NVIDIA RTX A2000 Mobile, 4GB of GDDR6 VRAM + Intel UHD iGPU (drives eDP-1)
	- internal panel is 1920x1080 16:9 at scale 1, NOT the XPS's 4K 16:10 panel,
	  so `GDK_SCALE` is 1 here and omarchy's `scale = "auto"` is deliberately not used
	- unlike the XPS, the dGPU drives real outputs: HDMI + mDP are on the NVIDIA
	  card, eDP-1 and the USB-C DP-alt ports are on the Intel one
	- **no built-in camera and no working built-in microphone** (camera-less SKU;
	  the array mics live in that module). A capture source still enumerates and
	  hears nothing. A Logitech Brio 100 (USB) provides both since 2026-09-11 and
	  is the voxtype mic; it powers on at +30dB and clips, so
	  `scripts/silver-fox/startup.sh` sets it to wpctl 0.4 (the +6dB hardware
	  floor) by node name. Calibration and re-tune in the `info-silver-fox` skill.
	- OS and home are on the 1TB KIOXIA NVMe (one drive, like rainbow-cat); the 256GB SK hynix it shipped with is a blank spare in the CPU-attached, Gen4-capable M.2 slot. Never address either by node number. See the `info-silver-fox` skill.

`rainbow-cat`
	- desktop, NVIDIA (primary GPU)
	- Samsung C49RG9x ultrawide (5120x1440@120, scaled 1.25) + C24F390 1080p to its right
