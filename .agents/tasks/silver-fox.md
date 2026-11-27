## 2026-11-27 Thunderbird preferences and encrypted accounts (from rainbow-cat)

Thunderbird now has shared stowed preferences and a point-in-time account snapshot in `secrets.toml`, see `stow/thunderbird/README.md`. The snapshot contains five mail accounts and their saved logins, calendar and remote address-book configuration. Restore uses age directly, without building Beet. No individual password is printed or put in an environment variable.

Account restoration and the idempotent second setup run completed on silver-fox. Thunderbird is open using `~/.thunderbird/arch-config`, with five mail accounts, 15 saved login records, six calendar configurations and five remote address-book configurations. All five mail accounts fetched folders, and inbox messages loaded without a password prompt. The previous `~/.config/thunderbird` profiles remain untouched.

The first launch created a separate empty `default-release` profile because this installation had no entry in the new profile registry. After closing that instance, rerunning `just setup-thunderbird --new-profile` registered the restored profile against the installation. A subsequent normal launch was verified to use `arch-config`.

- [ ] In the open Thunderbird window, confirm the expected remote calendar events and address-book contacts are available. Their configurations are restored, but their contents have not been verified. Resolve any authentication prompt in Thunderbird without printing credentials.

Verified `~/.thunderbird` is a real directory and `~/.thunderbird/arch-config/user.js` links to the shared stowed file with `mailnews.headers.sendUserAgent = false`. Never print decrypted snapshot contents while verifying. Local-only mail, calendar events and OpenPGP keys are outside this snapshot and remain in any previous profile.
