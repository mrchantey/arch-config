set dotenv-load := true

default:
	just --list

restart-voxtype:
	systemctl --user restart voxtype.service

# re-pick GPU vs CPU for the kokoro tts server by current power state (see scripts/tts-server.sh)
restart-tts:
	systemctl --user restart kokoro-tts.service

# device-agnostic base; run this once per install (or a device recipe below)
# install-mise-tools comes BEFORE init-user on purpose: it is what installs uv (via the
# omarchy python dev-env), and init-user reaches setup-tts, which builds the kokoro venv
# with uv. Reverse the two and a fresh install dies there with `uv: command not found`.
#
# Wrapped in scripts/sudo-keepalive.sh so the sudo password is asked for once, at
# the start, and the hour that follows never re-prompts. Nesting is harmless: the
# device recipes below wrap this too, and the inner `sudo -v` is a no-op while the
# outer one's timestamp is still being refreshed.
init:
	bash scripts/sudo-keepalive.sh just \
	init-sudo				\
	install-mise-tools	\
	init-user					\
	install-rust			\
	install-transcribe	\
	install-transcribe-file	\
	install-tts				\
	install-cursor-theme
	chmod +x scripts/*/startup.sh

# symlink the audio capture+transcribe helper onto PATH (~/.local/bin is on PATH).
# usage from any terminal: `transcribe [name]` -> name.wav + name.txt (default: out)
install-transcribe:
	chmod +x scripts/transcribe.sh
	mkdir -p ~/.local/bin
	ln -sf ~/me/arch-config/scripts/transcribe.sh ~/.local/bin/transcribe
	@echo "PASS install-transcribe"

# symlink the file transcriber and the GPU handoff helper onto PATH (see AGENTS.md,
# "Transcription"). The venv and model behind transcribe-file come from setup-transcribe-file.
# `gpu-exclusive <cmd>` runs cmd with voxtype and kokoro stopped, restarting them after.
# usage: `transcribe-file lecture.mp4` -> lecture.md + lecture.srt + lecture.segments.json
install-transcribe-file:
	chmod +x scripts/transcribe-file.sh scripts/gpu-exclusive.sh
	mkdir -p ~/.local/bin
	ln -sf ~/me/arch-config/scripts/transcribe-file.sh ~/.local/bin/transcribe-file
	ln -sf ~/me/arch-config/scripts/gpu-exclusive.sh ~/.local/bin/gpu-exclusive
	@echo "PASS install-transcribe-file"

# symlink the Kokoro text-to-speech helper onto PATH (~/.local/bin is on PATH).
# usage from any terminal: `tts gday mate` | `echo hi | tts` | `tts stop` | `tts last`
# acp-tee.sh wraps the Zed agent (see stow/zed settings) and acp-last.sh reads its tap,
# which is what `tts last` (CTRL+PAUSE) speaks.
install-tts:
	chmod +x scripts/tts.sh scripts/acp-tee.sh scripts/acp-last.sh
	mkdir -p ~/.local/bin
	ln -sf ~/me/arch-config/scripts/tts.sh ~/.local/bin/tts
	@echo "PASS install-tts"

# build the Never-Lost Rainbow cursor theme from the Windows .ani set in
# neverlost/ and install it to ~/.local/share/icons (see neverlost/readme.md).
# Hyprland and XWayland pick it up from stow/hypr/.config/hypr/envs.lua on
# reload; gsettings is the channel GTK apps read. Safe to re-run.
# Also puts the on/off toggle on PATH: `cursor-toggle` from any terminal.
install-cursor-theme:
	python3 scripts/install-cursor-theme.py
	chmod +x scripts/cursor-toggle.sh
	mkdir -p ~/.local/bin
	ln -sf ~/me/arch-config/scripts/cursor-toggle.sh ~/.local/bin/cursor-toggle
	# turn it on through the toggle, so install and toggle share one apply path
	scripts/cursor-toggle.sh on
	@echo "PASS install-cursor-theme"

# rainbow-cat (desktop): base + device hypr overrides + gaming/GPU stack
init-rainbow-cat:
	bash scripts/sudo-keepalive.sh just \
	init												\
	stow-device rainbow-cat	\
	install-extras					\
	install-rainbow-cat

# rainbow-cat system-level tweaks that need root (e.g. Lightspeed receiver drag fix)
install-rainbow-cat:
	bash scripts/rainbow-cat/install.sh

# silver-fox (Dell Precision 7560): base + device hypr overrides + gaming/GPU stack
init-silver-fox:
	bash scripts/sudo-keepalive.sh just \
	init											\
	stow-device silver-fox	\
	install-extras				\
	install-silver-fox

# silver-fox system-level tweaks that need root (e.g. keyboard backlight timeout)
install-silver-fox:
	bash scripts/silver-fox/install.sh

# Every root-requiring step of `init-silver-fox`, in the same order, and nothing
# else -- the sudo-free half (stow, mise, theme, tts, cursor, repos) is skipped
# because it will already have completed. Use plain `just init-silver-fox` on a
# machine that has never been set up.
#
# The whole run goes through scripts/sudo-keepalive.sh, so the password is asked
# for ONCE, at the very start, and never again. A bare `sudo -v` here is not
# enough: sudo forgets after five minutes, and this takes about an hour, so it
# used to stop dead at `install-rust` with `sudo: timed out reading password`
# once the user had walked away. Read that script before changing this line.
#
# Ordering that matters: setup-voxtype needs the binary install-user-apps brings
# in, and install-extras ends in setup-voxtype-gpu, so it has to follow both.
#
# Safe to re-run on a fully-configured machine: pacman and yay take --needed, the
# package removals are `|| true`, rustup/cargo-binstall no-op when current, and
# scripts/silver-fox/install.sh guards on the sysfs nodes it writes.
#
# Finish a silver-fox install that ran without a sudo password: one command, one prompt
init-silver-fox-sudo:
	bash scripts/sudo-keepalive.sh just \
	install-apps-init	\
	install-user-apps	\
	setup-voxtype		\
	install-rust		\
	install-extras		\
	install-silver-fox
	@echo "PASS init-silver-fox-sudo"

# apply the default (dark) theme. Firewatch is pinned for both themes via the
# per-theme user backgrounds dir set up in stow-files-init, so omarchy-theme-bg-next
# auto-selects it here.
# The old `systemctl --user mask waybar.service` guard is gone with quattro: the
# bar is now part of the single long-lived Omarchy shell (Quickshell), which is
# re-themed in place rather than killed and relaunched, so bars cannot stack.
setup-theme:
	omarchy theme set "Everforest"
	# set Firewatch explicitly: `theme set` runs bg-next, which CYCLES past the
	# current wallpaper if Everforest is already active (idempotent re-runs). The
	# runtime toggle always switches themes so it lands on Firewatch via sort
	# order, but here we pin it directly.
	omarchy theme bg set ~/.config/omarchy/backgrounds/everforest/firewatch.png

# Tell omarchy-launch-editor (and so $EDITOR, SUDO_EDITOR, SUPER+N, and every
# editor bind in hypr/bindings.lua) to open Zed. Without this file it falls back
# to nvim, and `--inline` nvim under `uwsm app` has no terminal, so the binds
# silently do nothing. Written by hand rather than via `omarchy default editor
# zed` because that writes `zeditor` (the pacman package's binary name) and our
# Zed comes from zed.dev's installer as plain `zed` (see install-user-apps).
setup-editor:
	mkdir -p ~/.local/state/omarchy/defaults
	printf 'zed\n' > ~/.local/state/omarchy/defaults/editor

# generate this device's SSH key for a git host (default tangled.org) and print
# the public half to paste into that host's account settings. Run once per
# device per host; the private key never leaves the machine. Idempotent.
setup-ssh-key host="tangled.org":
	bash scripts/setup-ssh-key.sh {{host}}

# put this person's age identity at ~/.config/beet/age/keys.txt: restored from a
# passphrase-encrypted backup (every machine after the first), else generated.
# It is per PERSON not per device, opens every beet secrets document it is
# listed in, and is never stowed.
# Idempotent. See scripts/setup-age-identity.sh.
setup-age-identity backup="":
	bash scripts/setup-age-identity.sh {{backup}}

# stow the per-device hypr overrides; idempotent
# quattro moved Hyprland config to Lua, so these are *.lua now. envs-device is
# gone entirely: omarchy detects the NVIDIA GPU and sets the render env itself.
stow-device device:
	rm -f 														\
	~/.config/hypr/monitors.lua 					\
	~/.config/hypr/input-device.lua 			\
	~/.config/hypr/layout-device.lua
	cd stow && stow -vt ~ hypr-{{device}}
	@echo "PASS stow-device {{device}}"

init-sudo:
	just install-apps-init

# Run commands that must not be done as sudo
init-user:
	just stow-files-init
	just stow-symlinks-init
	just setup-theme
	just setup-editor
	just install-user-apps-init
	just pull-repos
	just pull-assets

install-apps-init:
	sudo pacman -Rns --noconfirm spotify 				|| true
	sudo pacman -Rns --noconfirm obsidian 			|| true
	sudo pacman -Rns --noconfirm typora 				|| true
	sudo pacman -Rns --noconfirm 1password-cli	|| true
	sudo pacman -Rns --noconfirm 1password-beta	|| true
	rm -rf ~/.local/share/applications/Basecamp.desktop
	rm -rf ~/.local/share/applications/dropbox.desktop
	rm -rf ~/.local/share/applications/Figma.desktop
	rm -rf ~/.local/share/applications/Google\ Contacts.desktop
	rm -rf ~/.local/share/applications/Google\ Messages.desktop
	rm -rf ~/.local/share/applications/Google\ Photos.desktop
	rm -rf ~/.local/share/applications/HEY.desktop
	rm -rf ~/.local/share/applications/typora.desktop
	rm -rf ~/.local/share/applications/WhatsApp.desktop
	rm -rf ~/.local/share/applications/X.desktop
	rm -rf ~/.local/share/applications/Zoom.desktop
	@echo "INIT install-apps"
	just install-apps

# libnotify, gtk4-layer-shell,wl-clipboard, wtype dependencies of voxtype
# espeak-ng (phonemizer), jq (json) for kokoro tts (see setup-tts)
# python, uv, pip and pipx are deliberately NOT here: they come from install-mise-tools
# the omarchy way. pip and pipx were never used by anything in this repo anyway.
install-apps:
	sudo pacman -S --noconfirm --needed 	\
	age															\
	aws-cli-v2														\
	caligula															\
	element-desktop												\
	espeak-ng															\
	gtk4-layer-shell											\
	helix																	\
	jq																		\
	libnotify															\
	opentofu															\
	podman																\
	rsync																	\
	stow																	\
	thunderbird														\
	udiskie																\
	wl-clipboard													\
	wtype
	curl -f https://zed.dev/install.sh | sh
	@echo "PASS install-apps"

# Rust is the one runtime omarchy does NOT put behind mise -- its Menu > Install >
# Development > Rust runs the rustup.rs installer and guards on ~/.rustup. We use the
# pacman `rustup` instead (same toolchain manager, but tracked by pacman and already
# on PATH via /usr/lib/rustup/bin), so we are aligned with omarchy in substance.
install-rust:
	# pacman for cargo-binstall so we dont build from source
	sudo pacman -S --noconfirm --needed \
	rustup cargo-binstall
	# bevy dependencies https://github.com/bevyengine/bevy/blob/latest/docs/linux_dependencies.md#arch--manjaro
	sudo pacman -S --noconfirm --needed \
	mold libx11 pkgconf alsa-lib pipewire-alsa
	# init stable
	rustup default stable
	# init nightly
	rustup default nightly
	# cargo install cargo-binstall
	rustup target add wasm32-unknown-unknown
	cargo binstall --no-confirm \
	cargo-edit 									\
	cargo-expand 								\
	cargo-generate							\
	cargo-lambda 								\
	cargo-watch 								\
	sccache											\
	worker-build								\
	wasm-opt
	cargo binstall --no-confirm \
	wasm-bindgen-cli 						\
	--version=0.2.106
	@echo "PASS install-rust"

install-user-apps-init:
	@echo "INIT install-user-apps"
	just install-user-apps
	just setup-voxtype
	just setup-tts
	just setup-transcribe-file

# base (CPU): download whisper model and install the user systemd service
# note: config.toml is managed via stow (built-in hotkey disabled there)
setup-voxtype:
	voxtype setup --download --model large-v3-turbo	|| true
	voxtype setup systemd														|| true
	just setup-voxtype-isolation
	@echo "PASS setup-voxtype"

# render gpu_isolation per power-state at daemon start (see scripts/voxtype-render-config.sh):
# isolate on battery so the dGPU can suspend between clips, stay warm on AC / desktop for
# instant capture. keeps ONE shared config.toml (dictionary etc.) — the flag is injected
# into a runtime copy the daemon reads via -c, never the stowed file. machine-agnostic:
# the script self-detects, so this drop-in is identical on every device.
setup-voxtype-isolation:
	chmod +x scripts/voxtype-render-config.sh
	mkdir -p ~/.config/systemd/user/voxtype.service.d
	printf '[Service]\nExecStartPre=%%h/me/arch-config/scripts/voxtype-render-config.sh\nExecStart=\nExecStart=/usr/bin/voxtype -c %%t/voxtype/config.toml daemon\n' > ~/.config/systemd/user/voxtype.service.d/battery-isolation.conf
	systemctl --user daemon-reload || true
	systemctl --user restart voxtype.service || true
	@echo "PASS setup-voxtype-isolation"

# device: enable GPU (Vulkan) acceleration, otherwise large models run on CPU.
# hybrid-graphics laptops (silver-fox: Intel iGPU + NVIDIA dGPU) enumerate the slow
# iGPU as Vulkan device 0, so whisper picks it and takes ~30s/clip; pin whisper to
# the NVIDIA dGPU via a systemd drop-in. GGML_VK_VISIBLE_DEVICES restricts ggml to
# only that device, which the persistent daemon honors (verified), so the long-lived
# daemon uses the dGPU directly — no gpu_isolation needed (see voxtype config.toml).
setup-voxtype-gpu:
	#!/usr/bin/env bash
	set -uo pipefail
	sudo voxtype setup gpu --enable || true
	# find the ggml Vulkan index of the NVIDIA dGPU (0 on single-GPU machines like
	# rainbow-cat, 1 behind the iGPU on silver-fox). a 1s tone forces model init; grep -m1
	# SIGPIPEs transcribe right after the device list prints, before slow inference.
	# detect with gpu_isolation stripped: isolation hides the worker's ggml log, and
	# a partial config is rejected, so we strip just that line from the real config.
	wav="$(mktemp --suffix=.wav)"; cfg="$(mktemp --suffix=.toml)"
	ffmpeg -nostdin -hide_banner -loglevel error -f lavfi -i sine=frequency=220:duration=1 -ar 16000 -ac 1 "$wav" -y >/dev/null 2>&1 || true
	grep -v 'gpu_isolation' ~/.config/voxtype/config.toml > "$cfg"
	idx="$(timeout 30 voxtype -c "$cfg" transcribe "$wav" 2>&1 | grep -m1 -oP 'ggml_vulkan: \K[0-9]+(?= = NVIDIA)')"
	rm -f "$wav" "$cfg"
	idx="${idx:-0}"
	echo "voxtype: pinning whisper to NVIDIA ggml Vulkan device ${idx}"
	mkdir -p ~/.config/systemd/user/voxtype.service.d
	printf '[Service]\nEnvironment="VOXTYPE_VULKAN_DEVICE=nvidia"\nEnvironment="GGML_VK_VISIBLE_DEVICES=%s"\n' "$idx" > ~/.config/systemd/user/voxtype.service.d/gpu.conf
	systemctl --user daemon-reload || true
	# the daemon caches its backend/device at startup; restart so the dGPU takes effect
	# now (otherwise a fresh install keeps running on the iGPU until the next login)
	systemctl --user restart voxtype.service || true
	echo "PASS setup-voxtype-gpu"

# kokoro tts (highlight-to-speak, the reverse of voxtype dictation). ONE venv with the CUDA
# torch wheel — that same wheel runs CPU inference fine, so tts-server.sh just flips USE_GPU
# by power state (GPU on AC, CPU on battery so the dGPU can suspend), exactly like voxtype.
# cloned to ~/.local/share since it's a build artifact, not dotfiles. enabled as a user
# service that starts on login. SHIFT+PAUSE / SHIFT+INSERT toggle playback (bindings.conf).
setup-tts:
	#!/usr/bin/env bash
	set -uo pipefail
	chmod +x scripts/tts.sh scripts/tts-server.sh
	dir="$HOME/.local/share/kokoro-fastapi"
	[ -d "$dir/.git" ] || git clone --depth 1 https://github.com/remsky/Kokoro-FastAPI.git "$dir"
	cd "$dir"
	export USE_ONNX=false PYTHONPATH="$PWD:$PWD/api"
	uv venv
	uv pip install -e ".[gpu]"
	uv run --no-sync python docker/scripts/download_model.py --output api/src/models/v1_0
	mkdir -p ~/.config/systemd/user
	printf '[Unit]\nDescription=Kokoro TTS (FastAPI)\nAfter=graphical-session.target\n\n[Service]\nExecStart=%%h/me/arch-config/scripts/tts-server.sh\nRestart=on-failure\nRestartSec=2\n\n[Install]\nWantedBy=default.target\n' > ~/.config/systemd/user/kokoro-tts.service
	systemctl --user daemon-reload || true
	systemctl --user enable --now kokoro-tts.service || true
	echo "PASS setup-tts"

# faster-whisper for transcribing files (transcribe-file). Separate from voxtype, which is
# whisper.cpp tuned for push-to-talk clips: faster-whisper adds VAD chunking and timestamps,
# which is what makes long recordings come out clean. ONE uv venv in ~/.local/share (a build
# artifact, like kokoro) holding the CUDA 12 runtime wheels, so the system CUDA install is
# irrelevant; CTranslate2 falls back to CPU on a machine without NVIDIA. Pre-downloads
# HF_HUB_DISABLE_XET: hf_xet downloads stalled indefinitely on silver-fox; plain HTTP is fine.
# builds ~/.local/share/whisper-venv and pre-downloads large-v3-turbo, the biggest model that fits on 4 GB
setup-transcribe-file:
	#!/usr/bin/env bash
	set -euo pipefail
	venv="$HOME/.local/share/whisper-venv"
	[ -x "$venv/bin/python" ] || uv venv --quiet "$venv" -p 3.12
	uv pip install --quiet -p "$venv/bin/python" faster-whisper nvidia-cublas-cu12 nvidia-cudnn-cu12
	HF_HUB_DISABLE_XET=1 "$venv/bin/python" -c 'from faster_whisper.utils import download_model; print(download_model("large-v3-turbo"))' 2>&1 | grep -v HF_TOKEN
	echo "PASS setup-transcribe-file"

# gaming / GPU stack — wanted on both rainbow-cat and silver-fox
install-extras:
	sudo pacman -S --noconfirm --needed cuda steam
	yay -S --noconfirm --needed xone-dkms xone-dongle-firmware
	just install-nvidia-deps
	# NOTE: silver-fox Optimus power management (dGPU off on battery) is a separate step.
	just setup-voxtype-gpu
	@echo "PASS install-extras"

# install NVIDIA driver and related 32-bit / Vulkan / OpenCL / performance tooling for gaming
install-nvidia-deps:
	sudo pacman -S --noconfirm --needed \
	nvtop \
	nvidia-open-dkms \
	nvidia-utils \
	lib32-nvidia-utils \
	nvidia-settings \
	vulkan-icd-loader \
	lib32-vulkan-icd-loader \
	gamemode \
	lib32-gamemode
	@echo "PASS install-nvidia-deps"

# apps from aur, usually more up-to-date than stable
install-user-apps:
	yay -S --noconfirm --needed		\
	ghostty												\
	google-chrome									\
	visual-studio-code-bin				\
	voxtype-bin
	@echo "PASS install-user-apps"

# Dev runtimes and global CLIs, all via mise -- the omarchy quattro model (see AGENTS.md).
# Omarchy's own installer already covers node plus the agent CLIs (claude, codex, gh,
# opencode, playwright, ...) in install/user/mise.sh, so this only adds what it does not
# ship. Idempotent; `omarchy update` (or the `mup` alias) upgrades everything here.
install-mise-tools:
	mkdir -p ~/.local/bin
	# Vite+ used to own node/npm/npx and shadowed mise's node from every terminal that
	# read .bashrc, while GUI apps and ssh got mise's. Removed so there is one node.
	# The other two are the orphans left behind by the old npm --prefix ~/.local installs.
	rm -rf ~/.vite-plus ~/.local/wrangler-install ~/.local/lib/node_modules/playwright
	rm -f ~/.cargo/bin/wrangler
	# runtimes omarchy offers under Menu > Install > Development but does not preinstall.
	# `omarchy-install-dev-env` is the same entry point that menu uses; node is listed
	# explicitly because the npm-backed wrappers below need a node to run under.
	omarchy-install-dev-env node
	omarchy-install-dev-env deno
	omarchy-install-dev-env zig
	# python installs a mise interpreter AND astral's uv. The mise interpreter is the
	# point: Arch's /usr/bin/python rolls minor versions and takes every venv built
	# against it with it, which is the actual reason python hurts on this distro.
	# Nothing here uses the system python, so shadowing it costs us nothing.
	# UV_NO_MODIFY_PATH stops astral's installer appending a `. ~/.local/bin/env` line to
	# our STOWED .bashrc, i.e. editing a tracked file on every run. That line only
	# prepends ~/.local/bin, which .bashrc already does for itself.
	UV_NO_MODIFY_PATH=1 omarchy-install-dev-env python
	# Self-updating ~/.local/bin wrappers, the same mechanism omarchy uses for claude and
	# codex: each run does `mise use -g` then `mise x`, so the tool upgrades itself.
	# `cf` must be spelled `npm:cf` -- mise's bare `cf` in the registry is Cloud Foundry,
	# not Cloudflare.
	omarchy-mise-install npm:wrangler wrangler
	omarchy-mise-install npm:cf cf
	# ACP adapter for the Zed agent panel. Zed can install this itself, but only for a
	# "type": "registry" agent — we run it as "type": "custom" behind scripts/acp-tee.sh
	# so the reply stream can be tapped for read-aloud, which means we own the install.
	# NOT omarchy-mise-install: its wrapper leaks a "mise ... tools:" line onto stdout on
	# every run, and here stdout is Zed's JSON-RPC channel. scripts/claude-agent-acp.sh is
	# the same wrapper with that line redirected to stderr; it explains itself in full.
	chmod +x scripts/claude-agent-acp.sh
	ln -sf ~/me/arch-config/scripts/claude-agent-acp.sh ~/.local/bin/claude-agent-acp
	@echo "PASS install-mise-tools"

# required to run after fresh install or omarchy update
# this may break hyprland, if so run Menu > System > Rel
stow-symlinks-init:
	rm -rf 													\
	~/.config/alacritty							\
	~/.config/autostart							\
	~/.bashrc												\
	~/.cargo												\
	~/.config/ghostty								\
	~/.config/mimeapps.list 				\
	~/.config/obs-studio						\
	~/.config/opencode							\
	~/.config/starship.toml 				\
	~/.config/voxtype								\
	~/.config/omarchy/branding			\
	~/.config/uwsm/default					\
	~/.config/zed											\
	~/.XCompose
	# fine-grained removal for dirs whose other contents we must preserve
	# (hypr ships other files; ~/.claude holds sessions/credentials/etc.;
	# ~/.config/gtk-3.0 is where GTK apps write settings.ini and their own state).
	# A fresh omarchy install ships gtk-3.0/bookmarks as a REAL file, and one
	# conflict aborts the WHOLE `stow` invocation -- so leaving it in place silently
	# unstows every package listed below, after the rm -rf above has already deleted
	# the old ones (.bashrc included). It has to be cleared here.
	# NOTE: hyprland.lua is intentionally NOT removed here -- stow-symlinks
	# relinks it atomically; deleting it makes a live Hyprland regenerate an
	# "autogenerated" stub (the on-screen warning banner) and breaks the stow.
	# quattro drops stock *.lua files next to ours on upgrade, so clear those too.
	rm -f													\
	~/.config/hypr/.luarc.json			\
	~/.config/hypr/bindings.lua			\
	~/.config/hypr/input.lua				\
	~/.config/hypr/looknfeel.lua		\
	~/.config/hypr/windows.lua			\
	~/.config/hypr/autostart.lua		\
	~/.config/hypr/hyprsunset.conf	\
	~/.config/hypr/xdph.conf				\
	~/.config/fcitx5/conf/keyboard.conf	\
	~/.config/git/config						\
	~/.config/git/ignore						\
	~/.ssh/config										\
	~/.config/omarchy/hooks/post-update.d/uv-self-update	\
	~/.config/gtk-3.0/bookmarks			\
	~/.claude/settings.json
	@echo "INIT stow-symlinks"
	just stow-symlinks

stow-symlinks:
	# hyprland.lua is special: a LIVE Hyprland regenerates a default *stub* the
	# instant this file goes missing, and stow refuses to overwrite that regular
	# file -- which aborts the ENTIRE hypr package (and cascades init to failure).
	# Pre-create the symlink atomically (same relative target stow would use) so
	# the file is never absent and stow treats it as already-stowed. Without this,
	# `just init-*` fails when run from inside a running Hyprland session.
	mkdir -p ~/.config/hypr
	ln -sfn ../../me/arch-config/stow/hypr/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua
	# ensure fcitx5's conf/ exists so stow links keyboard.conf into it rather than
	# folding (symlinking) the whole dir and hiding fcitx5's app-managed state
	mkdir -p ~/.config/fcitx5/conf
	# same folding hazard as ~/.ssh below: keep ~/.config/git a real dir so only
	# config+ignore are stowed, leaving room for git/gh to write their own state
	mkdir -p ~/.config/git
	# and again: post-update.d already holds omarchy's own hooks, so it must stay a real
	# dir and take only our uv-self-update link rather than being folded wholesale
	mkdir -p ~/.config/omarchy/hooks/post-update.d
	# ~/.ssh must already exist as a REAL dir, else stow folds the whole thing
	# into a symlink pointing at this repo -- and the next ssh-keygen would
	# write a PRIVATE KEY into version control. Only config is ever stowed.
	mkdir -p ~/.ssh
	chmod 700 ~/.ssh
	# omarchy's installer pre-creates ~/.agents/skills as a REAL dir (and drops an
	# `omarchy` skill symlink in it), which blocks stow from folding skills/ -- so
	# new skills created under ~/.agents/skills would be untracked real dirs. Fold
	# it ourselves: replace the dir with the symlink stow would create (safe -- the
	# only contents are stow-owned skill links plus the recreatable omarchy link),
	# then re-drop omarchy's link (it now lands in the repo via the fold; gitignored).
	mkdir -p ~/.agents
	rm -rf ~/.agents/skills
	ln -sfn ../me/arch-config/stow/agents/.agents/skills ~/.agents/skills
	ln -sfn "${OMARCHY_PATH:-/usr/share/omarchy}/default/omarchy-skill" ~/.agents/skills/omarchy
	# NOTE: the walker + elephant + waybar packages are gone with quattro. walker
	# (launcher) and elephant (its providers) were replaced by the Quickshell menu,
	# and waybar by the Quickshell bar -- all three packages are uninstalled, so
	# their configs had nothing left to configure. Bar/idle prefs moved to
	# files/omarchy/shell.json (see `stow-files`, it is copied not stowed).
	cd stow && stow -vt ~ \
	agents								\
	alacritty 						\
	autostart							\
	bashrc 								\
	cargo 								\
	claude								\
	fcitx5								\
	ghostty								\
	git									\
	gtk									\
	hypr 									\
	mimeapps 							\
	obs										\
	omarchy 							\
	opencode							\
	ssh									\
	starship 							\
	uwsm 									\
	voxtype								\
	xcompose								\
	zed
	# the mimeapps package also stows a google-chrome.desktop that shadows the
	# packaged one (see scripts/launch-here.sh); rebuild the cache so the desktop
	# database picks up the override rather than the /usr copy.
	update-desktop-database ~/.local/share/applications
	@echo "PASS stow-symlinks"

# perform cp for assets which cannot be stowed
stow-files-init:
	# Solarized Light is a community theme: the light counterpart to Everforest
	# that the dark/light toggle (Super+Shift+T) and setup-theme depend on.
	test -d ~/.config/omarchy/themes/solarized-light || \
	git clone https://github.com/dfrico/omarchy-solarized-light-theme.git ~/.config/omarchy/themes/solarized-light
	# Pin the Firewatch wallpaper for both the dark and light theme. It lives in
	# the per-theme USER backgrounds dir (~/.config/omarchy/backgrounds/<theme>/),
	# which omarchy-theme-bg-next sorts BEFORE a theme's own backgrounds -- so it
	# is auto-selected on every switch to either theme (see setup-theme).
	mkdir -p ~/.config/omarchy/backgrounds/everforest ~/.config/omarchy/backgrounds/solarized-light
	curl -fsSL -o ~/.config/omarchy/backgrounds/everforest/firewatch.png \
	https://arch-config--shared--assets.s3.us-west-2.amazonaws.com/pictures/firewatch.png
	cp ~/.config/omarchy/backgrounds/everforest/firewatch.png \
	~/.config/omarchy/backgrounds/solarized-light/firewatch.png
	@echo "INIT stow-files"
	just stow-files

# Omarchy shell (Quickshell) config: bar layout, widgets, idle/lock timings.
# Replaces the old waybar/config.jsonc + hypr/hypridle.conf pair.
# COPIED, not stowed: omarchy-shell-config writes this file with mktemp + mv,
# which replaces a symlink with a regular file. Every bar tweak goes through
# that path (`omarchy bar move ...`, the bar settings panel, enabling a plugin),
# so a stowed copy would silently detach from this repo on the first change.
stow-files:
	mkdir -p ~/.config/omarchy
	cp files/omarchy/shell.json ~/.config/omarchy/shell.json
	@echo "PASS stow-files"

# the reverse of stow-files: capture GUI-made changes back into the repo
pull-files:
	cp ~/.config/omarchy/shell.json files/omarchy/shell.json
	@echo "PASS pull-files"

# Every entry below was checked against the GitHub API on 2026-09-10 and resolves
# to itself -- no renames, no redirects. Keep it that way: `git clone` follows
# GitHub's rename redirect silently, so a stale name works right up until someone
# re-creates the old one, and then a fresh machine clones a stranger's repo. Four
# entries were wrong at that check:
#   mrchantey/notes      -> gone entirely, dropped
#   mrchantey/beet-draft -> renamed to mrchantey/personal
#   basecamp/omarchy     -> moved to omacom/omarchy
#   badlogic/pi-mono     -> moved to earendil-works/pi
# Re-verify with: gh api repos/<owner>/<name> -q .full_name
#
# beet_atproto sits beside beet because beet-cli's manifest names it as an
# optional path dependency: cargo refuses to load the workspace without it,
# so `just assets` (which builds beet-cli) needs the checkout even though the
# `atproto` feature is never enabled here.
write_repositories := "
mrchantey/beet
mrchantey/beet_atproto
mrchantey/beetmash
mrchantey/arch-config
mrchantey/personal
bevyengine/bevy
"
# when unlikely to edit, pulled with --depth=1
read_repositories := "
alexjg/samod
omacom/omarchy
ratatui/bevy_ratatui
openclaw/openclaw
earendil-works/pi
"

pull-repos:
	mkdir -p ~/me
	for repo in {{ replace(write_repositories, "\n", " ") }}; do \
		just pull-repo $repo; \
	done
	for repo in {{ replace(read_repositories, "\n", " ") }}; do \
		just pull-repo $repo --depth=1; \
	done
	mkdir -p ~/me/scratch
	touch ~/me/scratch/scratch.md
	@echo "PASS pull-repos"

# pull a repository, discarding errors
pull-repo repo *args:
	mkdir -p ~/me
	cd ~/me && git clone https://github.com/{{ repo }} {{args}} || true

# The shared assets bucket, `arch-config--shared--assets`, declared in main.bsx and
# driven by the stock beet binary built from ~/me/beet (pull-repos clones it):
#   just assets validate | plan | deploy | push | destroy
# cargo runs from beet's checkout so it reads beet's .cargo/config.toml
# (RUST_MIN_STACK for the deep type graph); WORKSPACE_ROOT points beet back here
# so `assets/` and the tofu work dir (target/infra/arch-config) resolve against
# this repo rather than beet's.
#
# the assets bucket through beet: just assets validate | plan | deploy | push | destroy
assets *args:
	cd ~/me/beet && WORKSPACE_ROOT={{ justfile_directory() }} \
	cargo run -p beet-cli --features infra,extra -- --main={{ justfile_directory() }}/main.bsx {{ args }}

# assets/ is a manifest of symlinks, one per noun, each pointing at where that noun
# lives on the machine (assets/pictures -> ~/Pictures/assets: wallpapers, headshots,
# the omarchy-logo template). It mirrors the bucket under the same prefixes, shared
# across machines and tracked in no repo (AGENTS.md, Shared assets).
#
# Hydrate assets/ from the bucket (remote -> local, additive). Deliberately not
# beet: init-user runs this on a fresh machine before any Rust toolchain or AWS
# credentials exist, and the bucket's public read (GetObject + ListBucket) is
# what lets an unsigned sync work. Each link target is created first, since the
# aws cli cannot write through a dangling symlink.
#
# hydrate assets/ from the bucket (remote -> local, additive, no credentials)
pull-assets:
	mkdir -p ~/Pictures/assets
	aws s3 sync s3://arch-config--shared--assets assets --region us-west-2 --no-sign-request
	@echo "PASS - pull-assets"

# beet refuses to push an empty or unhydrated link, which is what makes the
# delete below safe.
#
# the reverse: mirror assets/ up to the bucket (local -> remote, mirrors deletes)
push-assets:
	just assets push
	@echo "PASS - push-assets"

pre-reset:
	@set -e
	@for repo in {{ replace(write_repositories, "\n", " ") }}; do \
		just pre-reset-repo $repo || exit 1; \
	done
	@echo "PASS pre-reset"
	@echo "You are almost ready to reset your machine: \
	- ensure assets directories have been pushed: beet, beetmash \
	- ensure assets/ has been pushed: just push-assets \
	- your age identity ~/.config/beet/age/keys.txt is in NO repo: confirm the USB backup restores (just setup-age-identity <backup> on another machine) before wiping \
	"

@pre-reset-repo repo:
	cd ~/me/$(basename {{ repo }}) && \
	(git diff --exit-code || (echo "Error: $(basename {{ repo }}) has uncommitted changes" && exit 1)) && \
	(git diff --exit-code --cached || (echo "Error: $(basename {{ repo }}) has staged uncommitted changes" && exit 1)) && \
	(test -z "$(git log @{u}..)" || (echo "Error: $(basename {{ repo }}) has unpushed commits" && exit 1))

# best-effort apply these settings for windows
@windows-push:
	cp -r ./stow/zed/.config/zed/. "/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/AppData/Roaming/Zed"
	@echo "PASS windows-push"


### OPTIONAL

install-ollama:
	curl -fsSL https://ollama.com/install.sh | sh
	# general use
	ollama pull qwen3.5:9b
	# abliterated
	ollama pull huihui_ai/qwen3.5-abliterated:9b
