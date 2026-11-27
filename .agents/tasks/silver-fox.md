## 2026-11-27 Thunderbird preferences and encrypted accounts (from rainbow-cat)

Thunderbird now has shared stowed preferences and a point-in-time account snapshot in `secrets.toml`, see `stow/thunderbird/README.md`. The snapshot contains five mail accounts and their saved logins, calendar and remote address-book configuration. Restore uses age directly, without building Beet. No individual password is printed or put in an environment variable.

- [ ] Confirm Thunderbird is closed with `pgrep -x thunderbird`. If it is running, ask before closing it so drafts and other work can be saved. Capture and account setup refuse to run while it is open.
- [ ] Confirm `~/.config/beet/age/keys.txt` exists. If absent, ask for the person's existing identity backup and use `just setup-age-identity /path/to/backup.age`, which retries Thunderbird setup automatically. Do not generate a second identity. If the key exists but cannot open the snapshot, stop and resolve that rather than replacing it.
- [ ] `just setup-thunderbird --new-profile`, stows the shared preferences, decrypts the snapshot into the separate `~/.thunderbird/arch-config` profile, and selects it as the default. Existing profiles and their credentials are preserved, and their registry files are backed up beside the originals. A previously completed restored profile is reused without overwriting its accounts. If changing an already configured default profile needs a user decision, ask first.
- [ ] Run `just setup-thunderbird` again, expect existing accounts to be preserved without applying the snapshot again.
- [ ] Open Thunderbird and verify the five mail accounts, saved logins, remote calendars and address books work. An existing Primary Password still needs to be entered in Thunderbird. Remote data may take time to download.

Verify `~/.thunderbird` is a real directory, `~/.thunderbird/arch-config/user.js` links to the shared stowed file, and Config Editor shows `mailnews.headers.sendUserAgent = false`. Never print decrypted snapshot contents while verifying. Local-only mail, calendar events and OpenPGP keys are outside this snapshot and remain in any previous profile.

## 2026-11-27 install Firefox (from rainbow-cat)

Firefox is now included in `just install-apps` through `just install-omarchy-apps` in `justfile`.

- [ ] (ask first) `just install-omarchy-apps`, installs missing packages including Firefox and enables the Mullvad daemon, and may require a sudo password.

Verify `pacman -Q firefox` reports the installed version and Firefox appears in the app launcher.
