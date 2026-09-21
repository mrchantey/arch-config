#!/bin/bash

# Put this person's age identity in place at ~/.config/beet/age/keys.txt, either
# restored from a passphrase-encrypted backup or freshly generated.
#
# The identity is PER PERSON, not per device: it is the one key that opens every
# beet secrets document (a repo's committed `secrets.toml`, the exported stack
# secrets) whose groups list its public half, so a new machine RESTORES it from
# the backup rather than generating a second one that can read nothing. Generate
# only on the very first machine, then `beet vault/backup --qr` it onto a USB
# stick before anything depends on it.
# ~/.config/beet is deliberately NOT stowed: a private key never enters a repo.
#
# usage: just setup-age-identity [backup.age]

set -euo pipefail

BACKUP="${1:-}"
DIR=~/.config/beet/age
KEYS="$DIR/keys.txt"

mkdir -p "$DIR"
chmod 700 "$DIR"

if [[ -f "$KEYS" ]]; then
  echo "== identity already exists: $KEYS (leaving it alone)"
elif [[ -n "$BACKUP" ]]; then
  echo "== restoring the identity from $BACKUP (age will ask for the passphrase)"
  age -d -o "$KEYS" "$BACKUP"
else
  echo "== no backup given, generating a NEW identity on $(hostnamectl --static 2>/dev/null || hostname)"
  echo "   only do this on your first machine; every other machine restores:"
  echo "   just setup-age-identity /path/to/backup.age"
  age-keygen -o "$KEYS"
fi
chmod 600 "$KEYS"

echo
echo "== public key (recipient): add it to the \`recipients\` list of every group"
echo "   you should read in a secrets document ([groups.<name>] in secrets.toml),"
echo "   then \`beet secrets/rekey\` and \`beet secrets/check\`"
echo
age-keygen -y "$KEYS"
echo
if [[ -z "$BACKUP" ]]; then
  echo "== back it up before anything depends on it:"
  echo "   beet vault/backup --qr   (a passphrase-encrypted copy for a USB stick, and a QR code for paper)"
  echo "   or, before beet is built:  age -p -a -o beet-identity.age $KEYS"
fi
