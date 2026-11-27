#!/bin/bash

# Generate this device's SSH key for a git host and print the public half to
# register with the host's account settings.
#
# Keys are PER DEVICE and never leave the machine: the private half stays in
# ~/.ssh (which is deliberately NOT stowed into this repo), the public half is
# pasted into the host's key settings page. A key is per ACCOUNT, not per repo,
# so this is a once-per-device-per-host job.
#
# usage: just setup-ssh-key <host>

set -euo pipefail

HOST="${1:?Usage: setup-ssh-key.sh <host>}"
# Derive the key name from the host. Set the matching IdentityFile in
# stow/ssh/.ssh/config to use the key on every device.
SLUG="${HOST%%.*}"
KEY=~/.ssh/"id_ed25519_${SLUG}"
DEVICE="$(hostnamectl --static 2>/dev/null || hostname)"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ -f "$KEY" ]]; then
  echo "== key already exists: $KEY (leaving it alone)"
else
  echo "== generating a new key for $HOST on $DEVICE"
  echo "   (empty passphrase is fine on a disk-encrypted personal machine;"
  echo "    set one and ssh-agent will ask for it once per login)"
  # comment is what shows up in the host's key list -- name the device so an
  # individual machine can be identified and revoked later
  ssh-keygen -t ed25519 -f "$KEY" -C "$DEVICE"
fi
chmod 600 "$KEY"
chmod 644 "$KEY.pub"

echo
echo "== public key -- paste this into the keys page of your $HOST settings"
echo
cat "$KEY.pub"
echo
if command -v wl-copy >/dev/null; then
  wl-copy <"$KEY.pub"
  echo "   (copied to clipboard)"
fi
echo
echo "== once it is registered, verify with:"
echo "   ssh -T $HOST   (the user comes from ~/.ssh/config)"
echo "   the first connect asks you to trust the host fingerprint -> known_hosts"
