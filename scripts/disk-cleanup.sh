#!/usr/bin/env bash
# Free disk space without losing anything that can't be rebuilt or re-downloaded.
#
#   disk-cleanup.sh survey             report what is using the disk
#   disk-cleanup.sh prune [--dry-run]  clear cargo intermediates and user caches
#
# Cargo never collects its own garbage: every dependency version and every
# rebuilt workspace crate stays in `target/<profile>/deps` forever, so targets
# grow until the disk fills. The sccache in $SCCACHE_DIR turns the dependency
# rebuild into cache hits, which makes clearing them cheap.
#
# `target/` is not cargo's alone: beet keeps tofu work dirs (`target/infra`,
# whose state lives in S3), dev TLS certs, local stores and sometimes downloads
# there, so never `rm -rf target`. Prune only the intermediates inside a cargo profile dir, ie
# any dir holding `.cargo-lock`, keeping the final binaries beside them so
# symlinks like ~/.cargo/bin/beet still run. A profile whose cargo lock is held
# by a running build or rust-analyzer check is skipped.
#
# `du` reports uncompressed sizes, the disk is zstd compressed, so real savings
# are smaller. Trust the `df` delta.
#
# Needs sudo, so printed rather than run: the pacman cache and system journal.
set -euo pipefail

# where cargo targets are searched for
roots=("$HOME/me")
# cargo intermediates inside a profile dir, all rebuildable; newer cargo keeps
# fingerprints and per-crate output under `build/<crate>/<hash>/` instead
intermediates=(deps build examples incremental .fingerprint)

dry_run=false

main() {
	case "${1:-}" in
	survey) survey ;;
	prune)
		[[ "${2:-}" == "--dry-run" ]] && dry_run=true
		prune
		;;
	*)
		sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
		exit 1
		;;
	esac
}

survey() {
	df -h /
	echo
	echo "## Largest under ~ (uncompressed)"
	du -xh --max-depth=3 "$HOME" 2>/dev/null | sort -h -r | awk '$1 ~ /[GT]$/' | head -40
	echo
	echo "## Cargo profile dirs"
	find_profiles | xargs -r -d '\n' du -sh 2>/dev/null | sort -h -r
	echo
	echo "## System"
	du -sh /var/cache/pacman/pkg 2>/dev/null
	journalctl --disk-usage 2>/dev/null
}

prune() {
	local before after
	before=$(free_bytes)
	# 1. cargo intermediates
	local profile
	while IFS= read -r profile; do
		prune_profile "$profile"
	done < <(find_profiles)
	# 2. user caches, each tool pruning only what it can refetch
	run mise prune --yes
	# a long-running `uv run`, ie the tts server, holds the cache lock indefinitely
	run env UV_LOCK_TIMEOUT=5 uv cache prune
	run npm cache clean --force
	run find "$HOME/.cache/yay" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
	# 3. report
	after=$(free_bytes)
	echo
	echo "Freed $(numfmt --to=iec $((after - before))), $(numfmt --to=iec "$after") now free."
	echo "Needs sudo, run if wanted:"
	echo "  sudo paccache -rk1 && sudo paccache -ruk0   # pacman cache: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
	echo "  sudo journalctl --vacuum-size=500M          # journal"
}

# every cargo profile dir under $roots, one per line
find_profiles() {
	find "${roots[@]}" \
		\( -name .git -o -name node_modules \
		-o \( -path '*/target/*' \( -name deps -o -name build -o -name examples -o -name incremental \) \) \) -prune \
		-o -type f -name .cargo-lock -printf '%h\n' 2>/dev/null || true
}

# clears one profile's intermediates while holding its cargo locks
prune_profile() {
	local profile=$1 lock fd fds=() busy=false
	for lock in "$profile"/.cargo-*lock; do
		[[ -e $lock ]] || continue
		exec {fd}<"$lock"
		fds+=("$fd")
		flock -n "$fd" || { busy=true; break; }
	done
	if $busy; then
		echo "skip (cargo running): $profile"
	elif $dry_run; then
		echo "$(du -sch "${intermediates[@]/#/$profile/}" 2>/dev/null | tail -1 | cut -f1)	$profile"
	else
		echo "prune: $profile"
		(cd "$profile" && rm -rf "${intermediates[@]}" && find . -maxdepth 1 -type f \( -name 'lib*.rlib' -o -name 'lib*.rmeta' -o -name '*.d' \) -delete)
	fi
	for fd in "${fds[@]}"; do exec {fd}<&-; done
}

run() {
	if $dry_run; then echo "would run: $*"; else "$@" || echo "failed: $*"; fi
}

free_bytes() {
	df --output=avail -B1 / | tail -1
}

main "$@"
