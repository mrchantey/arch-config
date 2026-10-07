#!/bin/bash
# remove-preinstalls -- the unattended twin of `omarchy-remove-preinstalls`.
#
# Omarchy has no install-time opt-out (bare mode was rejected, omacom/omarchy#1155):
# the ISO pacstraps every package in install/omarchy-base.packages and provisioning
# lays down every web app, TUI and agent wrapper. The sanctioned way off is Menu >
# Remove > Preinstalls, which is interactive (gum confirm), all-or-nothing, and takes
# user-created web apps with it (#4830). This is the same operation made idempotent
# and scriptable, so `just init` runs it on a fresh machine and the post-update hook
# re-runs it after every `omarchy update`, which is what keeps the fleet from creeping
# back (#7107; the fix in #9703 is still open). See AGENTS.md "Preinstalls".
#
# Three things carry the opt-out:
#   - ~/.local/state/omarchy/preinstalls-removed: the flag omarchy's migrations check
#     before adding a new preinstall, and hypr/helpers.lua before binding their keys
#   - the shipped launchers, removed by name so a web app the user made survives
#   - the mise wrappers, detected by shape rather than listed, so a new agent omarchy
#     adds is caught without this file changing. The ones `just install-mise-tools`
#     writes are the allowlist.
set -euo pipefail

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
APP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/omarchy"

# Shipped launchers to leave in place.
KEEP_LAUNCHERS=("Discord" "Google Maps" "YouTube" "Disk Usage")

# mise wrappers written by `just install-mise-tools`; every other wrapper is omarchy's.
KEEP_WRAPPERS=(claude gh wrangler cf)

# omarchy's own preinstall package set (bin/omarchy-remove-preinstalls), unioned across
# the installed release and upstream master. omarchy-pkg-drop skips what isn't installed.
PACKAGES=(
	aether cliamp libreoffice-fresh xournalpp pinta obsidian obs-studio kdenlive
	moonlight-qt lazydocker omacut omacalc omawrite monologue hype
)

in_list() {
	local needle="$1"
	shift
	local item
	for item in "$@"; do
		[[ $item == "$needle" ]] && return 0
	done
	return 1
}

# Shipped web app and TUI launchers, by the names omarchy ships them under. Real apps in
# the same dir (foot, imv, mpv) match neither Exec shape and stay. The omarchy removers
# take the icon with the launcher.
remove_launchers() {
	local path name
	for path in "$OMARCHY_PATH"/applications/*.desktop; do
		name=$(basename "$path" .desktop)
		in_list "$name" "${KEEP_LAUNCHERS[@]}" && continue
		[[ -f $APP_DIR/$name.desktop ]] || continue
		if grep -qE '^Exec=(omarchy-launch-webapp|omarchy-webapp-handler)' "$path"; then
			echo "Removing web app: $name"
			OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$name"
		elif grep -qE '^Exec=xdg-terminal-exec .*-e ' "$path"; then
			echo "Removing TUI: $name"
			OMARCHY_REMOVE_NOTIFY=false omarchy-tui-remove "$name"
		fi
	done
}

# Every bash script in ~/.local/bin whose body runs `mise use -g` is an omarchy wrapper
# (omarchy-mise-install, omarchy-install-hermes-cli) unless we wrote it. Symlinks are
# ours (scripts/ on PATH), and the shebang check keeps grep off binaries like uv.
# Upstream only deletes the stub; the tool stays in ~/.config/mise/config.toml, where
# `omarchy-update-mise` keeps downloading it, so each one is unused as well. `mise unuse`
# is meant to prune too but leaves the installs under auto_prune=false (codex held
# 1.1 GB), hence the explicit uninstall of that tool's versions and nothing else's.
remove_wrappers() {
	local path name pkg
	for path in "$BIN_DIR"/*; do
		[[ -f $path && ! -L $path ]] || continue
		name=$(basename "$path")
		in_list "$name" "${KEEP_WRAPPERS[@]}" && continue
		head -n1 "$path" | grep -q '^#!/bin/bash' || continue
		grep -qE '^[[:space:]]*mise use -g' "$path" || continue
		pkg=$(sed -nE "s/^[[:space:]]*mise use -g[^'\"]*['\"]([^'\"]+)['\"].*/\1/p" "$path" | head -n1)
		echo "Removing wrapper: $name"
		rm -f "$path"
		if [[ -n $pkg ]]; then
			mise unuse -g "$pkg" 2>/dev/null || true
			mise uninstall --all "$pkg" 2>/dev/null || true
		fi
	done
}

remove_launchers

mkdir -p "$STATE_DIR"
touch "$STATE_DIR/preinstalls-removed"

# Drop the preinstall keybinds in the running session; a fresh install has no session yet.
# Before the package step, which is the only one that needs sudo and so the one that fails.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
	hyprctl reload >/dev/null
fi

remove_wrappers

omarchy-pkg-drop "${PACKAGES[@]}"
