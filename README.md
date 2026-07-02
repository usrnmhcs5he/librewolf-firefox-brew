# firefox-hardened-setup

Deploys Firefox on macOS with a LibreWolf-like privacy configuration, using a
locally vendored (pre-reviewed) [arkenfox user.js](https://github.com/arkenfox/user.js).
No runtime download of the configuration — the only network activity is
Homebrew installing/upgrading the signed Firefox cask.

Built as a migration path away from the LibreWolf Homebrew cask, which is
deprecated and will be disabled in the main Homebrew repo on 2026-09-01
(unsigned binary, fails Gatekeeper).

## What it does

1. Installs/upgrades Firefox via Homebrew (signed, notarized build).
   **No admin rights required:** if `/Applications` is not writable, the app
   is installed to `~/Applications` automatically (`--appdir`), so the script
   works for deliberately non-sudoer users. A user-set `HOMEBREW_CASK_OPTS`
   always takes precedence.
2. Applies enterprise policies via macOS defaults (telemetry, studies,
   Pocket off; Firefox self-update off so brew stays the single update
   path) — these survive app updates, unlike a bundled `policies.json`
3. Creates a dedicated Firefox profile (`hardened`)
4. Verifies the vendored `user.js` against `user.js.sha256`
   (trust-on-first-use: the hash is recorded on the first run)
5. Applies `user.js` and appends LibreWolf-alignment overrides
   (letterboxing, WebGL off, DoH off, session restore kept)
6. Migrates container identities (`containers.json`) from an existing
   LibreWolf profile, if one is found

## Manual prerequisite (one-time, deliberate)

The script never downloads the arkenfox template. Obtain it yourself:

1. Download `https://raw.githubusercontent.com/arkenfox/user.js/master/user.js`
   (or a pinned tag from the arkenfox releases page)
2. Review it — plain-text prefs, auditable in minutes
3. Place it as `user.js` in the same folder as the script

The reviewed local copy is the trust anchor, hash-pinned on first run.

## Folder contents

| File                        | Purpose                                        |
|-----------------------------|------------------------------------------------|
| `firefox-hardened-setup.sh` | Deployment script (bash 3.2 compatible)        |
| `user.js`                   | Vendored arkenfox template — review before use |
| `user.js.sha256`            | Integrity pin, created on first run            |

## Usage

```sh
# 1. Place the reviewed arkenfox user.js in this folder (see prerequisite)
# 2. First machine — records the hash:
./firefox-hardened-setup.sh
# 3. Copy the whole folder to each additional Mac and run the same command.
#    A hash mismatch aborts before any changes are made.
```

No sudo required. Re-running is safe (idempotent where possible). The final
summary prints the detected launch path (`~/Applications` or `/Applications`).

## Manual steps after first launch

1. Launch the profile (path printed by the script):
   `<Applications dir>/Firefox.app/Contents/MacOS/firefox -P hardened`
2. Install from addons.mozilla.org (Mozilla-signed):
   uBlock Origin, Multi-Account Containers
3. In Multi-Account Containers, enable Sync to replicate container
   identities **and** site assignments across machines. Without Sync,
   identities carry over via `containers.json`; site assignments must be
   re-created once per machine.

## Persistent container logins (optional)

arkenfox wipes cookies and site storage on every Firefox exit
(`privacy.clearOnShutdown_v2.cookiesAndStorage = true`, item 2815). Container
*identities* survive, but logins inside them do not persist across restarts.
If you want container logins to survive, pick ONE of the following:

**Option A — pref override (all sites keep cookies):**
Add this line and restart Firefox:

```js
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
```

- *Before deploying:* add it to the override block inside the setup script,
  so every machine gets it.
- *After the script has already run:* append it to the very END of the
  profile's `user.js` (`~/Library/Application Support/Firefox/Profiles/`
  `<random>.hardened/user.js`) — last write wins.
- **Do NOT use about:config for this** — the profile `user.js` re-applies
  every pref on startup and will silently revert the change.
- Re-running the setup script regenerates the profile `user.js`, wiping any
  manually appended lines — re-add them, or put the line in the script's
  override block instead.

Other sanitize-on-exit categories (cache etc.) remain active; only cookie
persistence changes.

**Option B — per-site exceptions (arkenfox-sanctioned, selective):**
While on the site: Page Info (Cmd+I) > Permissions > Set Cookies > Allow.
Manage them under Settings > Privacy & Security > Cookies and Site Data >
Manage Exceptions. Item 2815 respects "Allow" exceptions, so only chosen
sites survive shutdown. For cross-domain logins add both domains (e.g.
`youtube.com` **and** `accounts.google.com`). Note: excepted sites also lose
partitioning, so keep the list short.

## Notes

- Overrides are appended at the end of `user.js`; last write wins. Edit the
  override block in the script to change behaviour (e.g. enable
  `privacy.clearOnShutdown.history` for full LibreWolf wipe-on-exit).
- Firefox self-update is disabled by policy (`DisableAppUpdate`) because a
  user-writable app in `~/Applications` would otherwise self-update and race
  brew's version tracking. Remove that line in the script if you prefer
  Firefox self-updates — then stop upgrading the cask via brew.
- Elevation note: `sudo` cannot help a non-sudoer user (it checks the
  invoking user against sudoers). The scriptable equivalent of the Finder
  admin prompt is `osascript ... "with administrator privileges"`, but it is
  deliberately NOT used here — a root-owned app in `/Applications` would
  require admin authentication on every future upgrade.
- arkenfox is stricter than stock Firefox: expect some site breakage and
  tune via overrides. See the arkenfox wiki, section "Overrides [Common]".
- This approximates LibreWolf; compile-time LibreWolf patches cannot be
  replicated via prefs.

## Changelog

- **v4** — non-admin support: `--appdir=~/Applications` fallback when
  `/Applications` is not writable; binary detection in both locations;
  summary prints the real launch path; `DisableAppUpdate` policy added
- **v3** — documented manual arkenfox acquisition (script header + error
  message); README: persistent container logins option
- **v2** — vendored local `user.js` with SHA-256 pinning; runtime download removed
- **v1** — initial release; arkenfox fetched from GitHub at runtime

## License

MIT. arkenfox user.js is licensed separately (MIT) by its authors.
