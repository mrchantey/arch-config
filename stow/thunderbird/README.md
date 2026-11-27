# Thunderbird

## Shared preferences

Stow owns only `~/.thunderbird/user.js`. `scripts/thunderbird.py link` links it into the selected profile as `user.js`, which Thunderbird reads at startup. The profile directory stays real and outside the repo. A previous `user.js` is preserved beside it as `user.js.pre-stow.<timestamp>`.

The shared preferences follow the system theme and timezone, disable the default-client and accelerator-send prompts, and set `mailnews.headers.sendUserAgent = false`. That last preference suppresses the outgoing email `User-Agent` header, not the HTTP user agent. Changes take effect on the next Thunderbird start.

## Account snapshot

`secrets.toml` holds `THUNDERBIRD_PROFILE` in the `thunderbird` group, sealed to the person's age recipient. The record has no `env_var` role. Its value is a base64-encoded, gzip-compressed JSON snapshot containing portable account, identity, SMTP, calendar and address-book preferences, mail filter files, and the saved-login NSS files. Absolute mail directories are reconstructed from their profile-relative counterparts. IMAP client IDs, server responses, filter timestamps and CardDAV sync tokens are omitted so the new profile can establish its own state and fetch a complete address book.

Thunderbird already encrypts saved usernames and passwords in `logins.json` using key material in `key4.db`. The snapshot keeps those files together without decrypting individual passwords. Without a Primary Password, possession of the pair is generally enough to recover the logins. Age adds protection for the entire snapshot in git, including account details that Thunderbird normally stores in plaintext. Restore removes only the age layer, leaving Thunderbird's login encryption intact. An existing Primary Password is still required by Thunderbird and is not captured.

The snapshot is not a full profile backup. Mail, local folders, contacts, calendar events, caches, sessions, extensions and OpenPGP key material are not included. Remote mail, calendars and address books are fetched again. Local-only content requires a separate backup.

## Commands

| Command | Behavior |
| --- | --- |
| `just capture-thunderbird` | With Thunderbird closed, seals the selected default profile into `secrets.toml` using Beet and stdin, without printing credential values. Replaces the previous point-in-time snapshot. |
| `just capture-thunderbird --profile /absolute/profile/path` | Captures an explicitly selected profile. |
| `just setup-thunderbird` | With Thunderbird closed, stows shared preferences and restores accounts only when the selected profile has no accounts. Existing account profiles are preserved and receive only the shared preferences link. |
| `just setup-thunderbird --new-profile` | Selects a separate restored `~/.thunderbird/arch-config` profile as the default, preserving all previous profiles and backing up their registry files. A previously completed restored profile is reused without replacing its accounts. |
| `just stow-symlinks` | Links the shared preferences without decrypting or replacing accounts. Safe while Thunderbird is running, with changes applied on restart. |

Profiles are selected using the installation default in `profiles.ini`, then the profile marked `Default`, then a sole registered profile. Ambiguous profiles require `--profile`. A foreign or incomplete `arch-config` directory is never overwritten. Restored profiles have mode `0700` and their files have mode `0600`.

## Fresh installs

`just init-user`, reached by `just init` and the device recipes, runs `just setup-thunderbird` after stowing. Restore uses Python's standard library and the installed `age` binary to open the sealed TOML group, so it does not need a built Beet or a Rust toolchain. The plaintext snapshot exists only in process memory and the local profile, never in the repo or a command argument.

If `~/.config/beet/age/keys.txt` is not present yet, setup reports that account restoration is pending. `just setup-age-identity /path/to/backup.age` restores the person's identity and automatically retries Thunderbird setup. A wrong or unreadable identity fails setup rather than creating new credentials. Restoring accounts does not launch Thunderbird.
