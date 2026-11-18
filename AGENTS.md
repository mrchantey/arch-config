# Editing OS Config

This is my omarchy config, located at `~/me/arch-config`. Omarchy 4 ("quattro") installs to `/usr/share/omarchy` (read-only, never edit; the Omarchy 3 path `~/.local/share/omarchy` no longer exists, so anything still pointing there is broken), and to `~/.config`, some of which is overridden via stow. Generated state (current theme, toggles, workspace layouts) lives in `~/.local/state/omarchy`, which is where `current/theme/...` moved to from `~/.config/omarchy/current`.

When asked to make changes use these files as reference to understand the system, and ensure install scripts are updated so the changes are reflected in a fresh install.

## Where docs live

This file holds only what applies to any change in the repo, plus the index below. Everything else lives as close to its code as it can, with one home per fact; every other mention cites it.

| Kind of knowledge | Home |
| --- | --- |
| Why one file is the way it is | that file's header comment |
| A self-contained unit (a stow package, a plugin, `neverlost/`, `files/`) | `README.md` in its directory; stow skips one at a package's top level |
| A topic spanning several packages or scripts | `docs/<topic>.md` |
| One machine's hardware, device config and traps | `docs/devices/<hostname>.md` |
| A procedure run on a trigger | a skill in `.agents/skills` |

When adding one, add its line to the index. Never grow a section here for a single subsystem.

## Index

Read the entry before touching its subject.

- Workspace sync, or any bind or rule that names a workspace: header of `stow/hypr/.config/hypr/workspaces.lua`
- Bar workspace labels: `stow/omarchy/.config/omarchy/plugins/pete.workspaces/README.md`
- Bar, launcher, notifications, idle and lock (one Quickshell process), `shell.json`, logind drop-ins: `files/README.md`
- Runtimes, CLI tools, PATH, uv: `docs/dev-tooling.md`
- Removing Omarchy's preinstalled apps, launchers and agent wrappers: header of `scripts/remove-preinstalls.sh`
- Global agent instructions and user skills: `stow/agents/README.md`
- Dictation, transcription, TTS and sharing the GPU between them: `docs/transcription.md`
- Chrome, Chromium and Electron flags (mic gain during calls, the keyring): `docs/chromium-flags.md`
- Codex `/voice`: header of `stow/pipewire/.config/pipewire/client.conf.d/codex-voice.conf`
- Links opening on the wrong workspace: headers of `scripts/launch-here.sh` and `scripts/chrome-here.sh`
- Cursor theme: `neverlost/readme.md`
- Shared assets bucket: `docs/assets.md`
- Backups: `docs/backups.md`, run through the `backup` skill
- Freeing disk space: header of `scripts/disk-cleanup.sh`, run through the `disk-cleanup` skill
- Handing changes to other devices: the `device-handoff` skill
- A device's hardware and device config: `docs/devices/<hostname>.md`

## Changes reach the other devices by handoff

The repo runs on every machine under "Devices" below, but a pull alone does not make every change live: a new stow file needs linking, the shell needs a restart, a package needs installing. When a change needs another device to act, commit a task for each other device alongside it, in `.agents/tasks/<device>.md` (the device's hostname), holding the exact steps to catch up. The install scripts cover fresh machines; the handoff covers existing ones. `git-sync` checks for this machine's task file after every pull, completes it, deletes it and pushes. The `device-handoff` skill owns when to write one, the file format and how to complete it.

## Hyprland is configured in Lua

Quattro replaced the `*.conf` + `source =` chain with native Lua. `~/.config/hypr/hyprland.lua` is the entry point; everything else is a module resolved off `package.path` (`~/.config/?.lua`, then `$OMARCHY_PATH/?.lua`). Omarchy's defaults are loaded first via `require("default.hypr.omarchy")`, so our modules override them.

Reference for the API: type stubs at `/usr/share/hypr/stubs/hl.meta.lua` (wired up for the LSP by `hypr/.luarc.json`), and Omarchy's own defaults in `/usr/share/omarchy/default/hypr/`.

Three gotchas that differ from the old `.conf` files:

- **Re-binding a key does not replace the old bind, both fire.** Call `hl.unbind("SUPER + F")` before `o.bind(...)`. Every unbind in `bindings.lua` names the default it displaces.
- **`hyprctl dispatch` also takes Lua now, not bare words.** `hyprctl dispatch workspace 4` and `hyprctl dispatch focuswindow address:0x...` both fail with a Lua parse error; the working forms are `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'` and `hl.dsp.window.close({ ... })`. The dispatcher namespace is enumerated under `HL.DspNamespace` in the stubs. This bites scripts, not config, and it fails loudly on stdout, so a script that redirects to `/dev/null` looks like it worked.
- **Keysyms must match xkbcommon exactly.** `Page_Up`/`Page_Down`, not `PAGEUP`/`PAGEDOWN`; `comma`, not `COMMA`. The old parser was forgiving, the Lua binder is not. Validate with `hyprctl reload && hyprctl configerrors`, which reports these.

Only `hyprsunset.conf` and `xdph.conf` are still `.conf`: they are read by separate processes, not Hyprland, so `hyprctl` neither applies nor validates them.

Workspace N is a group spanning every monitor, so never address a workspace by raw id in a bind or a rule, see the header of `workspaces.lua`.

## Per-device config

Most config is common, stowed by the `hypr` package and shared `just` recipes. `*.lua` is shared; `monitors.lua` and `*-device.lua` (`input-device.lua`, `layout-device.lua`, `envs-device.lua`) are per-device and live in a stow package named after the machine (`stow/hypr-rainbow-cat`, `stow/hypr-silver-fox`), stowed by `stow-device <name>` and selected via `init-<name>`. Device modules are loaded with `require_optional` after their shared counterpart, so a machine whose device package isn't stowed still boots and a device setting always wins. When editing monitors or window layout, edit the right device package; shared input or anything else goes in the common `hypr` package.

## Tools and preinstalls

- **CLI tools go through mise wrappers** written by `just install-mise-tools`, never `npm install -g` or a second pacman/AUR copy of a wrapped tool. Runtimes are global mise installs, Rust is rustup. Don't prepend a runtime ahead of the mise shims in `.bashrc`. Details in `docs/dev-tooling.md`.
- **Preinstalls stay removed** by `scripts/remove-preinstalls.sh`, re-run after every `omarchy update`, so a new Omarchy app, launcher or agent wrapper reappearing is expected and handled there, not one-off.
- **Never edit `/usr/share/omarchy/shell/plugins/`**; clone a widget with `omarchy plugin clone omarchy.<widget>`, which switches the bar to `<username>.<widget>` under `~/.config/omarchy/plugins/`.

## Devices

- `silver-fox`: Dell Precision 7560 laptop, Intel iGPU composites and an RTX A2000 4GB for CUDA, Brio 100 as the only mic and camera. Record: `docs/devices/silver-fox.md`.
- `rainbow-cat`: desktop, RTX 3080 Ti as the compositing GPU, Samsung C49RG9x ultrawide as its only display in use. Record: `docs/devices/rainbow-cat.md`.
