#!/usr/bin/env bash
# Shared logind setup: stop a closed lid from suspending the machine while it is
# on mains power. The drop-in it installs carries the full explanation.
#
# Laptop-only, and a clean no-op anywhere else. rainbow-cat has no lid, so there
# is no lid action for logind to take and nothing to override -- the guard below
# runs BEFORE elevating, so a desktop never prompts for a password it cannot use.
#
# Run directly (`bash scripts/install-logind.sh`) or via `just install-logind`.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DROPIN=30-lid-external-power.conf
SRC="${REPO}/files/systemd/logind.conf.d/${DROPIN}"
DEST="/etc/systemd/logind.conf.d/${DROPIN}"

if ! omarchy-hw-laptop; then
	echo "logind: no lid on this machine, skipping (expected on rainbow-cat)"
	echo "PASS install-logind"
	exit 0
fi

# re-exec under sudo if we are not already root (single prompt for the whole script)
if [[ ${EUID} -ne 0 ]]; then
	exec sudo bash "$0" "$@"
fi

install -Dm644 "${SRC}" "${DEST}"

# systemd-logind is Type=notify-reload, so this re-reads the drop-in in place.
# Restarting it instead would also work and is a far bigger hammer: it re-opens
# every session's device handles, which is not worth it for a config re-read.
systemctl reload systemd-logind

# Read the setting back off the bus rather than trusting the write. An unset
# value prints as an empty string, which is the state this file exists to leave.
applied=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
	org.freedesktop.login1.Manager HandleLidSwitchExternalPower)
echo "logind: lid close on external power -> ${applied#s }"
echo "PASS install-logind"
