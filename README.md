# firefox-hardened-setup

Deploys Firefox on macOS with a LibreWolf-like privacy configuration, using a
locally vendored (pre-reviewed) [arkenfox user.js](https://github.com/arkenfox/user.js).
No runtime download of the configuration — the only network activity is
Homebrew installing/upgrading the signed Firefox cask.

Built as a migration path away from the LibreWolf Homebrew cask, which is
deprecated and will be disabled in the main Homebrew repo on 2026-09-01
(unsigned binary, fails Gatekeeper).

## What it does

1. Installs/upgrades Firefox via Homebrew (signed, notarized build)
2. Applies enterprise policies via macOS defaults (telemetry, studies,
   Pocket off) — these survive app updates, unlike a bundled `policies.json`
3. Creates a dedicated Firefox profile (`hardened`)
4. Verifies the vendored `user.js` against `user.js.sha256`
   (trust-on-first-use: the hash is recorded on the first run)
5. Applies `user.js` and appends LibreWolf-alignment overrides
   (letterboxing, WebGL off, DoH off, session restore kept)
6. Migrates container identities (`containers.json`) from an existing
   LibreWolf profile, if one is found

## Folder contents

| File                        | Purpose                                        |
|-----------------------------|------------------------------------------------|
| `firefox-hardened-setup.sh` | Deployment script (bash 3.2 compatible)        |
| `user.js`                   | Vendored arkenfox template — review before use |
| `user.js.sha256`            | Integrity pin, created on first run            |

## Usage

```sh
# 1. Place a reviewed arkenfox user.js in this folder
# 2. First machine — records the hash:
./firefox-hardened-setup.sh
# 3. Copy the whole folder to each additional Mac and run the same command.
#    A hash mismatch aborts before any changes are made.
```

No sudo required. Re-running is safe (idempotent where possible).

## Manual steps after first launch

1. Launch the profile:
   `/Applications/Firefox.app/Contents/MacOS/firefox -P hardened`
2. Install from addons.mozilla.org (Mozilla-signed):
   uBlock Origin, Multi-Account Containers
3. In Multi-Account Containers, enable Sync to replicate container
   identities **and** site assignments across machines. Without Sync,
   identities carry over via `containers.json`; site assignments must be
   re-created once per machine.

## Updating arkenfox

Fetch the new release once, diff against the vendored copy, review, replace
`user.js`, delete `user.js.sha256` (re-recorded on next run), re-run the
script on each Mac. Never let the script fetch it for you — that is the point.

## Notes

- Overrides are appended at the end of `user.js`; last write wins. Edit the
  override block in the script to change behaviour (e.g. enable
  `privacy.clearOnShutdown.history` for full LibreWolf wipe-on-exit).
- arkenfox is stricter than stock Firefox: expect some site breakage and
  tune via overrides. See the arkenfox wiki, section "Overrides [Common]".
- This approximates LibreWolf; compile-time LibreWolf patches cannot be
  replicated via prefs.

## Changelog

- **v2** — vendored local `user.js` with SHA-256 pinning; runtime download removed
- **v1** — initial release; arkenfox fetched from GitHub at runtime

## License

MIT. arkenfox user.js is licensed separately (MIT) by its authors.
