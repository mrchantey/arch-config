#!/usr/bin/env bash
# Back up this device: push what git can push, ingest Claude Code sessions
# through beet_egress, then mirror what git cannot hold into this device's
# prefix of the private `arch-config--shared--backup` bucket, laid out as the
# home directory (`silver-fox/me/beet/.agents/..`).
#
#   backup.sh [--if-due] [--dry-run] [--first]   back up, printing a report
#   backup.sh restore <device> [--replace]        lay a device's prefix over ~, see restore()
#
#   --if-due   only run when one is due: 23h after the last run, or 3h after a
#              failed one. The hourly `backup.timer` passes it.
#   --dry-run  push, ingest and upload nothing; stage and report what would be
#   --first    allow the first upload from a machine that has neither backed up
#              nor restored, whose mirror would otherwise prune the prefix a
#              reinstall of the same hostname should have restored from
#
# What is staged and why: "Backups" in AGENTS.md.
set -euo pipefail

repo_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
host="$(hostname)"
stage="$repo_dir/target/backup/$host"
state="${XDG_STATE_HOME:-$HOME/.local/state}/backup"
egress_dir="$HOME/me/beet_egress"
# a remote under this account makes a checkout ours: staged whole and pushed
owner_re='github\.com[:/]mrchantey/'

if_due=false
dry_run=false
first=false
pushed=()
local_only=()
attention=()
uncommitted=()
failures=()
egress_status="not run"
upload_status="skipped, dry run"

main() {
	case "${1:-}" in
		restore)
			[[ -n ${2:-} ]] || { echo "usage: backup.sh restore <device> [--replace]" >&2; exit 2; }
			restore "$2" "${3:-}"
			return
			;;
	esac
	for arg in "$@"; do
		case $arg in
			--if-due) if_due=true ;;
			--dry-run) dry_run=true ;;
			--first) first=true ;;
			*) echo "backup.sh: unknown argument $arg" >&2; exit 2 ;;
		esac
	done
	grep -q "path=\"backup/push/$host\"" "$repo_dir/main.bsx" || {
		echo "backup.sh: main.bsx declares no backup/push/$host route, add this device's pair beside the others" >&2
		exit 1
	}
	mkdir -p "$state"
	# the timer and a manual run must not stage over each other
	exec 9>"$state/lock"
	flock -n 9 || { echo "backup.sh: a backup is already running" >&2; exit 0; }
	if $if_due && ! is_due; then
		return
	fi
	if [[ ! -f $state/last-run ]] && ! $first && ! $dry_run; then
		echo "backup.sh: nothing has been backed up or restored on this machine; restore it first (just restore), or pass --first if $host has no backup" >&2
		notify-send -u critical "Backup refused" "first backup on $host: just restore, or just backup --first" 2>/dev/null || true
		exit 1
	fi

	local checkouts
	mapfile -d '' checkouts < <(find_checkouts)
	for dir in "${checkouts[@]}"; do
		survey "$dir"
	done
	egress
	rm -rf "$stage"
	mkdir -p "$stage"
	for dir in "${checkouts[@]}"; do
		stage_checkout "$dir"
	done
	if [[ -d $HOME/Downloads ]]; then cp -a --reflink=auto "$HOME/Downloads" "$stage/Downloads"; fi
	upload
	report

	if ! $dry_run; then
		if ((${#failures[@]})); then echo failed; else echo ok; fi >"$state/last-run"
	fi
	if ((${#failures[@]})); then
		notify-send -u critical "Backup failed" "$(printf '%s\n' "${failures[@]}")" 2>/dev/null || true
		exit 1
	fi
}

# --if-due: a day after the last run, or three hours after a failed one
is_due() {
	local last="$state/last-run" age
	[[ -f $last ]] || return 0
	age=$(($(date +%s) - $(stat -c %Y "$last")))
	((age > 23 * 3600)) && return 0
	[[ $(<"$last") != ok ]] && ((age > 3 * 3600))
}

# every checkout under ~/me, main repos and linked worktrees alike, skipping
# anything nested in a checkout's .agents, target or node_modules
find_checkouts() {
	find "$HOME/me" -maxdepth 5 \( -name .agents -o -name target -o -name node_modules -o -name .git \) -prune \
		-name .git -printf '%h\0' | LC_ALL=C sort -z
}

is_owned() { git -C "$1" remote -v | grep -Eq "$owner_re"; }

# a linked worktree's .git is a file naming its gitdir in the main repo
is_worktree() { [[ -f $1/.git ]]; }

# Records uncommitted work and pushes what can be pushed.
survey() {
	local dir=$1 name=${1#"$HOME"/} count
	if [[ -n $(git -C "$dir" status --porcelain) ]]; then uncommitted+=("$name"); fi
	if ! is_owned "$dir"; then
		count=$(git -C "$dir" rev-list --count --branches --not --remotes)
		((count == 0)) || attention+=("$name: $count local commits on no remote, not backed up since the repo is not ours")
		return
	fi
	if is_worktree "$dir"; then
		# a linked worktree shares its main repo's branches, pushed there; a
		# detached HEAD's commits are reachable only from the copied .git
		if ! git -C "$dir" symbolic-ref -q HEAD >/dev/null; then
			count=$(git -C "$dir" rev-list --count HEAD --not --remotes)
			((count == 0)) || local_only+=("$name: $count commits on its detached HEAD")
		fi
		return
	fi
	push_branches "$dir"
}

# Fast-forwards every branch that is ahead of its upstream on one of our
# remotes. A diverged branch, a gone upstream or a branch without one is
# reported, never rebased or created.
push_branches() {
	local dir=$1 name=${1#"$HOME"/}
	local branch upstream remote remoteref track
	while IFS='|' read -r branch upstream remote remoteref track; do
		if [[ -z $upstream ]]; then
			attention+=("$name: branch $branch has no upstream")
			continue
		fi
		case $track in
			*gone*) attention+=("$name: $branch tracks $upstream, which is gone") ;;
			*behind*ahead* | *ahead*behind*) attention+=("$name: $branch has diverged from $upstream $track") ;;
			*ahead*)
				if ! git -C "$dir" remote get-url --push "$remote" | grep -Eq "$owner_re"; then
					attention+=("$name: $branch is $track of $upstream, which is not our remote")
				elif $dry_run; then
					pushed+=("$name $branch $track (dry run)")
				elif GIT_TERMINAL_PROMPT=0 git -C "$dir" push --quiet "$remote" "refs/heads/$branch:$remoteref"; then
					pushed+=("$name $branch $track")
				else
					failures+=("$name: git push $remote $branch")
				fi
				;;
		esac
	done < <(git -C "$dir" for-each-ref refs/heads \
		--format='%(refname:short)|%(upstream:short)|%(upstream:remotename)|%(upstream:remoteref)|%(upstream:track)')
}

# Claude Code transcripts, whose record is beet_egress's own bucket rather than
# this one. Ingesting is append only and verified lossless before it writes.
egress() {
	if [[ ! -d $egress_dir ]]; then
		attention+=("no ~/me/beet_egress checkout, Claude Code sessions not ingested")
	elif $dry_run; then
		egress_status="skipped, dry run"
	elif run_bin beet-egress ingest pete --source=claude-code && run_bin beet-egress push; then
		egress_status=ok
	else
		egress_status=failed
		failures+=("beet_egress ingest or push")
	fi
}

# Stages one checkout under $stage at its path below ~. Ours: the working tree
# as git sees it, uncommitted edits included, its .git, and what .gitignore
# hides that lives nowhere else. Theirs: only what is ours in it, and nothing
# at all when that is nothing.
stage_checkout() {
	local dir=$1 dest="$stage/${1#"$HOME"/}" paths
	paths=$(mktemp)
	staged_paths "$dir" | LC_ALL=C sort -zu >"$paths"
	if [[ -s $paths ]]; then
		mkdir -p "$dest"
		# reflinks: staging costs no space and holds still while it uploads, and
		# the kept mtimes are what let the sync skip unchanged files
		(cd "$dir" && while IFS= read -r -d '' path; do
			if [[ -f $path && ! -L $path ]]; then printf '%s\0' "$path"; fi
		done <"$paths" | xargs -0 -r cp --reflink=auto --preserve=timestamps --parents -t "$dest")
	fi
	rm "$paths"
	if is_owned "$dir"; then
		mkdir -p "$dest"
		cp -a --reflink=auto "$dir/.git" "$dest/.git"
	fi
}

# the files of a checkout to stage, NUL separated, relative to it
staged_paths() {
	local dir=$1
	if is_owned "$dir"; then
		git -C "$dir" ls-files -z -co --exclude-standard
		agents_paths "$dir"
		assets_paths "$dir"
	else
		git -C "$dir" ls-files -z -m -o --exclude-standard
		LC_ALL=C comm -z -23 <(agents_paths "$dir" | LC_ALL=C sort -z) \
			<(git -C "$dir" ls-files -z -c -- .agents | LC_ALL=C sort -z)
	fi
}

# .agents, less its tmp, build output and repos cloned into it for reference,
# which live wherever they were cloned from
agents_paths() {
	[[ -d $1/.agents ]] || return 0
	(cd "$1" && find .agents \( -path .agents/tmp -o -name target -o -name node_modules \
		-o \( -type d -exec test -e '{}/.git' \; \) \) -prune -o -type f -print0)
}

# gitignored `assets` dirs: hydrated from buckets of their own, held twice
# because a stale local push over such a bucket is final
assets_paths() {
	local dir=$1 entry
	while IFS= read -r -d '' entry; do
		entry=${entry%/}
		[[ ${entry##*/} == assets && $entry != .agents/* ]] || continue
		(cd "$dir" && find "$entry" -type f -print0)
	done < <(git -C "$dir" ls-files -z -o -i --exclude-standard --directory)
}

upload() {
	$dry_run && return
	if run_bin beet "backup/push/$host"; then
		upload_status="ok, s3://arch-config--shared--backup/$host/"
	else
		upload_status=failed
		failures+=("upload to the backup bucket")
	fi
}

report() {
	local files size
	files=$(find "$stage" -type f | wc -l)
	size=$(du -sh --apparent-size "$stage" | cut -f1)
	echo
	echo "# backup $host $(date -u +%FT%TZ)$($dry_run && echo ', dry run')"
	section "Failed" "${failures[@]}"
	section "Needs attention" "${attention[@]}"
	section "Pushed" "${pushed[@]}"
	section "Held only in the .git copy" "${local_only[@]}"
	section "Uncommitted, held in the mirror" "${uncommitted[@]}"
	echo
	echo "- egress: $egress_status"
	echo "- staged: $files files, $size, $stage"
	echo "- upload: $upload_status"
}

section() {
	local title=$1
	shift
	(($#)) || return 0
	echo
	echo "## $title"
	printf -- '- %s\n' "$@"
}

# Runs one of the two beet binaries the backup needs from a saved copy of its
# last good build, so a checkout that is mid-refactor or busy with another
# build does not stop the backup. The copy is rebuilt when a week old, and once
# more when it fails, in case the binary is what is out of date.
run_bin() {
	local name=$1
	shift
	local bin="$state/bin/$name"
	if [[ ! -x $bin || -n $(find "$bin" -mtime +7) ]]; then
		build_bin "$name" || [[ -x $bin ]] || return 1
	fi
	run_saved "$name" "$@" && return 0
	build_bin "$name" && run_saved "$name" "$@"
}

build_bin() {
	local name=$1 dir exe args
	case $name in
		beet) dir="$HOME/me/beet" args=(-p beet-cli --features infra,extra --bin beet) ;;
		beet-egress) dir="$egress_dir" args=(--features cli --bin beet-egress) ;;
	esac
	echo "backup.sh: building $name in $dir" >&2
	if exe=$(cd "$dir" && cargo build --message-format=json-render-diagnostics "${args[@]}" |
		jq -r 'select(.executable != null) | .executable' | tail -n1) && [[ -n $exe ]]; then
		mkdir -p "$state/bin"
		cp "$exe" "$state/bin/$name.new"
		mv "$state/bin/$name.new" "$state/bin/$name"
	else
		attention+=("$name does not build in ${dir#"$HOME"/}, ran its last good build")
		return 1
	fi
}

# what `just assets` and `just cli` give each binary through cargo: the
# workspace it serves and the stack beet's deep type graph needs
run_saved() {
	local name=$1
	shift
	case $name in
		beet) BEET_WORKSPACE_ROOT="$repo_dir" RUST_MIN_STACK=1073741824 \
			"$state/bin/beet" --entry="$repo_dir/main.bsx" "$@" ;;
		beet-egress) (cd "$egress_dir" && BEET_WORKSPACE_ROOT="$egress_dir" RUST_MIN_STACK=1073741824 \
			"$state/bin/beet-egress" "$@") ;;
	esac
}

# Pulls a device's prefix and lays it over ~. By default it only fills in what
# is missing, safe on a live machine. --replace is for a fresh one, whose `just
# init` has already cloned: each checkout the backup holds replaces the local
# one, which is kept beside it as `<path>.pre-restore`.
restore() {
	local device=$1 replace=${2:-} src dir entry mode path
	src="${XDG_CACHE_HOME:-$HOME/.cache}/backup-restore/$device"
	mkdir -p "$state" "$repo_dir/target/restore/$device"
	run_bin beet "backup/pull/$device"
	# out of this repo first, since this repo may be one of those replaced
	rm -rf "$src"
	mkdir -p "${src%/*}"
	mv "$repo_dir/target/restore/$device" "$src"
	if [[ $replace == --replace ]]; then
		while IFS= read -r -d '' dir; do
			dir=${dir#"$src"/}
			if [[ -e $HOME/$dir ]]; then mv "$HOME/$dir" "$HOME/$dir.pre-restore"; fi
		done < <(find "$src/me" -maxdepth 6 -name .git -printf '%h\0')
	fi
	cp -a --reflink=auto --update=none "$src/." "$HOME/"
	# what S3 cannot hold, symlinks and executable bits, from each checkout's index
	while IFS= read -r -d '' dir; do
		dir="$HOME/${dir#"$src"/}"
		while IFS= read -r -d '' entry; do
			mode=${entry%% *}
			path=${entry#*$'\t'}
			case $mode in
				120000) [[ -L $dir/$path ]] || git -C "$dir" checkout -- "$path" ;;
				100755) if [[ -f $dir/$path ]]; then chmod +x "$dir/$path"; fi ;;
			esac
		done < <(git -C "$dir" ls-files -s -z)
	done < <(find "$src/me" -maxdepth 6 -name .git -printf '%h\0')
	# a restored machine may back up over its prefix from here on
	[[ -f $state/last-run ]] || echo restored >"$state/last-run"
	echo "restored $device into $HOME from $src"
}

# one line, so an edit made while a run is in flight is never read mid-file
main "$@"; exit
