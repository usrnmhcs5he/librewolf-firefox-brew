<div align="center">

# 🦊 firefox-hardened-setup

**Per-user, no-sudo hardening of Firefox on macOS with a LibreWolf-like privacy posture, built on a vendored, locally reviewed arkenfox `user.js`.**

![Bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-no%20sudo-000000?logo=apple&logoColor=white)
![arkenfox](https://img.shields.io/badge/arkenfox-144.0-orange)
![Version](https://img.shields.io/badge/version-12-blue)

</div>

Configures, hardens, verifies and replicates Firefox. It does **not** install or
update the app. Portable bundles carry your setup (including container
identities) to other Macs, and the installed app is independently verified
against Apple's signature chain.

> [!IMPORTANT]
> **Update model.** Firefox is installed from Mozilla's official DMG with
> **admin authority**. The bundle is deliberately not writable by your everyday
> user, which blocks tampering. Updates therefore need admin authority too:
> the **reliable path is replacing the app with the current DMG**
> ([Updating](#-updating)), about once a month. Firefox's in-app updater with
> its admin helper dialog is an optional shortcut that can hang on some Macs.
> Do not leave the browser stale. Homebrew is no longer part of the lifecycle.

## ✨ Features

- **Vendored arkenfox `user.js`**: you download and review it once. It is
  hash-pinned, and the script never fetches it.
- **LibreWolf-aligned overrides**: RFP, letterboxing, WebGL off, DoH off
  (see [Overrides](#-overrides)).
- **Signature verification**: `codesign`, Mozilla Team ID and Gatekeeper checks
  on every run.
- **Ownership check**: reports whether the app bundle is protected from your user.
- **Dedicated `hardened` profile** with user-domain policies (telemetry,
  studies and Pocket off).
- **Replication bundles**: script, `user.js`, pin and container identities,
  covered by a SHA-256 manifest.
- **Stock macOS only**: bash 3.2, no sudo, no Homebrew.

## 📦 Prerequisites

### 1. Firefox (once per machine, by an admin)

1. Download the DMG from <https://www.mozilla.org/firefox/>.
2. Verify it (below).
3. Drag `Firefox.app` to `/Applications` from the admin account.
4. With Firefox closed: `sudo chown -R root:admin /Applications/Firefox.app`
5. From the standard account, this must print `protected`:
   ```bash
   [ -w /Applications/Firefox.app ] && echo writable || echo protected
   ```

**Verify the DMG** (version e.g. `141.0`):

```bash
shasum -a 256 ~/Downloads/Firefox*.dmg
curl -fsSL "https://ftp.mozilla.org/pub/firefox/releases/<VER>/SHA256SUMS" | grep <the-hash>
```

A match on a `mac/<lang>/Firefox <VER>.dmg` line proves a byte-identical
official artifact. Optionally verify `SHA256SUMS.asc` with GPG against
Mozilla's release key.

### 2. arkenfox `user.js` (once, deliberate)

Download release `144.0` from the only official sources,
`github.com/arkenfox/user.js` or `arkenfox.github.io/gui/`. Review it and place
it as `user.js` next to the script. With a bundle from another Mac, `unpack`
restores the reviewed copy and its pin instead.

## 🚀 Usage

```bash
chmod +x firefox-hardened-setup.sh
./firefox-hardened-setup.sh [command]
```

| Command | What it does |
|---------|--------------|
| `setup` (default) | Checks Firefox is present, verifies the signature chain, applies policies, creates the `hardened` profile, applies `user.js` + overrides, restores containers. Idempotent. |
| `update` | Verifies the signature chain, then compares your version with Mozilla's latest (one HTTPS request to `product-details.mozilla.org`). If behind, see [Updating](#-updating). A failed fetch is only a warning. |
| `verify` | Signature chain, Mozilla Team ID, Gatekeeper and writability posture. Run after every update. |
| `pack [out.tar.gz]` | Verifies `user.js`, snapshots `containers.json` from the live profile, writes a manifest and the bundle. |
| `unpack <bundle>` | Verifies the manifest, restores files next to the script, then runs `setup`. |
| `backup [out.tar.gz]` | Archives the `hardened` profile (history, cookies, sessions, logins, extensions, containers, prefs) with a SHA-256 file. Firefox must be closed. |
| `restore <archive>` | Puts a backup back and registers it as `hardened`. An existing profile folder is moved aside, never deleted. |
| `cleanup [--remove\|--all]` | Finds other Firefox copies and lists them with version, signer and owner. `--remove` asks per item and moves it to the Trash. `--all` also covers `/Applications/Firefox.app` and the update cache. See [Cleaning up](#-cleaning-up-other-copies). |

After the first launch, set the profile as default in `about:profiles` if you
start Firefox from the Dock or Finder. Confirm policies in `about:policies`.

`setup` also removes the old `DisableAppUpdate` policy (migration from v4–v9)
and applies existing-container handling in this order: existing profile
`containers.json` (never overwritten), then the bundle copy, then LibreWolf
migration.

> [!WARNING]
> If Homebrew's Caskroom still lists a firefox cask, `setup` prints a safe
> de-registration command (metadata only). **Never run
> `brew uninstall --cask firefox`**, because it would try to delete the app.

### Replicating to another Mac

```
Machine A: pack  →  Machine B: admin installs Firefox  →  copy bundle + script  →  unpack
```

Then follow the manual steps the script prints: default profile, extensions,
`about:policies`.

## 🧹 Cleaning up other copies

If another program opens a Firefox other than `/Applications/Firefox.app`, a
leftover copy is registered with macOS. Typical sources: the old v4 Homebrew
install in `~/Applications`, Nightly or Developer Edition, a mounted DMG, a
copy in Downloads.

```bash
./firefox-hardened-setup.sh cleanup            # scan only, changes nothing
./firefox-hardened-setup.sh cleanup --remove   # ask per item, move to Trash
```

- **Searches**: `~/Applications`, `/Applications`, Downloads, Desktop, mounted
  `/Volumes`, Spotlight (release, Developer Edition and Nightly bundle IDs)
  and Homebrew `Caskroom/firefox*` metadata.
- **Keeps** `/Applications/Firefox.app` and refuses to run if it is missing.
- **Safe removal**: apps go to the Trash (recoverable) and are unregistered
  from Launch Services. Profiles and data are never touched. Homebrew items
  are metadata only (never `brew uninstall`).
- **No sudo**: admin-owned copies are listed with the `sudo rm -rf` command
  for you to run from an admin account. Mounted DMGs get an eject command.
- Needs a terminal and Firefox closed. After a removal, log out and in if
  another program still shows the old copy.

## 🔄 Updating

`./firefox-hardened-setup.sh update` tells you whether you are behind.

**Reliable path (DMG replacement)**, no logout needed and the profile is untouched:

1. Quit Firefox.
2. Download the current DMG from <https://www.mozilla.org/firefox/> and
   [verify it](#1-firefox-once-per-machine-by-an-admin).
3. Drag `Firefox.app` onto `/Applications` and choose **Replace**. Finder asks
   for an admin name and password. Alternatively use Fast User Switching to the
   admin account, do the drag there, and switch back.
4. `./firefox-hardened-setup.sh verify`. If it reports the bundle as writable,
   an admin runs `sudo chown -R root:admin /Applications/Firefox.app`.

**Shortcut (in-app updater)**: Firefox menu → About Firefox downloads in the
background, and installing shows the macOS helper dialog where you enter the
admin password. If it loops (bouncing Dock icon, password asked again and
again), quit Firefox, delete `~/Library/Caches/Mozilla/`, and use the
reliable path. Never install an older Firefox than the profile last used.

## 💾 Profile backup

Everything you care about lives in the profile **root** folder, shown in
`about:profiles` (here `~/Library/Application Support/Firefox/Profiles/<id>.hardened`):
history and bookmarks (`places.sqlite`), cookies, session
(`sessionstore-backups/`), logins (`logins.json` + `key4.db`), site data and
container data (`storage/`), extensions, `containers.json`, prefs. The *Local
Directory* (`~/Library/Caches/Firefox/...`) is cache only and disposable.
The app itself holds no data, so deleting every Firefox binary does not touch
the profile.

```bash
./firefox-hardened-setup.sh backup              # Firefox closed
./firefox-hardened-setup.sh restore ff-hardened-profile-*.tar.gz
```

> [!WARNING]
> The archive contains cookies, logins and history. Keep it on encrypted
> storage; never commit or upload it. Some data is cleared on exit by design
> (arkenfox: cache, form data), so not every file will be present.

A profile remembers the newest Firefox that opened it. Installing an **older**
Firefox than that makes Firefox refuse the profile, so always install the
current release.

## 🔁 Starting over (clean slate)

1. `./firefox-hardened-setup.sh backup` (Firefox closed), and copy the archive
   somewhere safe.
2. `./firefox-hardened-setup.sh cleanup --all` removes every Firefox app
   (Trash) and the update cache. Admin-owned apps are not removable without
   sudo, so the script prints the `sudo rm -rf` command for you to run from an
   admin account.
3. **As admin**: download the DMG from <https://www.mozilla.org/firefox/>,
   [verify it](#1-firefox-once-per-machine-by-an-admin), drag `Firefox.app` to
   `/Applications`, then `sudo chown -R root:admin /Applications/Firefox.app`.
4. Back in the standard account: `./firefox-hardened-setup.sh verify`, then
   `setup`. It finds the existing `hardened` profile and keeps its data. If you
   lost the profile folder, run `restore` first.
5. Launch once, confirm the profile in `about:profiles`, and run
   `./firefox-hardened-setup.sh cleanup` to confirm no other copy exists.

## 📁 Files

| File | Role |
|------|------|
| `firefox-hardened-setup.sh` | The script. |
| `user.js` | Vendored arkenfox template, reviewed by you. |
| `user.js.sha256` | Pin of the reviewed `user.js`, auto-recorded on first run. |
| `containers.json` | Optional container identities restored by `setup`. |
| `ff-hardened-bundle-YYYYMMDD.tar.gz` | Output of `pack`. |

A bundle carries the script, `user.js` + pin and container identities. It does
**not** carry bookmarks, history, cookies, logins, container data, extensions
(install from AMO) or Multi-Account Containers site assignments (no upstream
export; use the extension's Sync or re-create them).

## 🛡️ Trust chain

| # | Anchor | Guarantee |
|---|--------|-----------|
| 1 | **Official DMG** | Checked by you against Mozilla's published checksums. |
| 2 | **Native updater** | Mozilla-signed updates applied with admin authorization, so nothing running as your user can ride along. |
| 3 | **Signature check** | `codesign --verify --deep --strict`, Team ID `43AQ936H96` ("Developer ID Application: Mozilla Corporation") and Gatekeeper/notarization on `setup`, `update` and `verify`. A swapped, patched or re-signed bundle hard-fails. |
| 4 | **Ownership** | The bundle must not be writable by your user (`root:admin` or admin-owned). This blocks silent tampering and means updates need admin authority. |
| 5 | **Vendored `user.js`** | Hash-pinned. Any drift aborts. |
| 6 | **Bundles** | `manifest.sha256` over every file, and `unpack` aborts on mismatch. Integrity, not authenticity, so transport bundles yourself. |

Cross-check the Team ID once against a DMG from mozilla.org:
`codesign -d --verbose=2 /Volumes/Firefox/Firefox.app`

Finder installs and Mozilla's helper may leave the bundle admin-owned rather
than `root:admin`, which is fine. After any install or update, run `verify` to
confirm the bundle is not writable by your user.

## ⚙️ Overrides

Applied on top of arkenfox v144. The base ships FPP (via ETP Strict) and leaves
RFP, letterboxing and WebGL-off inactive, so these opt in to LibreWolf's
behavior.

| Pref | Value | Note |
|------|-------|------|
| `privacy.resistFingerprinting` | `true` | Side effects: GMT-like timezone, light theme, canvas prompts, letterbox margins. To fall back to FPP, remove this and the letterboxing line together. |
| `privacy.resistFingerprinting.letterboxing` | `true` | Only coherent with RFP. |
| `webgl.disabled` | `true` | LibreWolf default. |
| `browser.safebrowsing.downloads.remote.enabled` | `false` | Defense-in-depth (also arkenfox 0403). |
| `network.trr.mode` | `5` | DoH hard off, so DNS is enforced at the network layer. |
| `browser.startup.page` | `3` | Session restore kept. |
| `privacy.clearOnShutdown_v2.cookiesAndStorage` | `false` | **Cookies and site data persist** (overrides arkenfox 2815). Cache and form data still clear. Trade-off: first-party tracking can persist. Alternative: drop this line and use per-site "Allow" exceptions. |
| `privacy.spoof_english` | `2` (commented) | Optional, for full en-US locale spoofing. |

> [!TIP]
> Make every pref decision in the override block, never the Settings UI. The
> profile `user.js` is re-applied at each startup and overwrites UI changes.

## 💡 Maintenance

- **Update arkenfox**: fetch the new release from the official repo, diff
  against your `user.js`, review, replace it, delete `user.js.sha256`
  (re-recorded on next run), re-run the script and `pack` a fresh bundle.
- **Force a container restore** on an existing profile: quit Firefox, delete
  `containers.json` from the `*.hardened` profile directory, re-run `setup`.

## 🔧 Compatibility

- Needs `shasum`, `tar`, `mktemp`, `defaults`, `pgrep`, `codesign`, `spctl`
  and `curl`, all stock macOS.
- If Gatekeeper assessments are globally disabled, `spctl` may reject. The
  script treats that as a failure by design.
- Smoke-tested end to end with stubbed system tools (50 checks): setup,
  policy removal, ownership branches, staleness check, verify, pack/unpack
  round-trip, tamper rejection and codesign/Gatekeeper negatives. The helper
  dialog and Finder install flows are macOS behavior that you verify on-device.

## 🕘 Version

README revision 8, paired with script **v12**. The full v1–v12 changelog is in
the script header.
