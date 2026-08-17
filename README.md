# firefox-hardened-setup.sh (v10)

Per-user, no-sudo hardening of Firefox on macOS approximating a
LibreWolf-like privacy posture, built on a **vendored, locally reviewed
arkenfox `user.js`**, with **portable replication bundles** (including
container identities) and **independent verification** of the installed app
against Apple's signature chain.

**App lifecycle model (v10+):** Firefox is installed once from Mozilla's
official DMG by an **admin account** and then **updates itself natively**.
Because the app bundle is not writable by the everyday standard user, macOS
shows the Firefox helper authorization dialog at each update — authenticate
it with the admin account. Homebrew is no longer part of the Firefox
lifecycle. This script configures, hardens, verifies, and replicates; it
does not install or update the app.

---

## !!! CRITICAL — UPDATE MODEL !!!

Firefox self-updates with Mozilla-signed updates. The download happens
silently in the background under your standard account; at install time
macOS shows the **Firefox helper authorization dialog** — enter your
**admin account's** credentials there. The prompt appears on **every**
update while the bundle stays non-writable to your user; that recurrence is
the deliberate cost of the tamper-protection model. **Do not postpone these
dialogs** — an unpatched browser is the worst component to leave stale.

If an update wedges (helper prompt loops or stalls): quit Firefox, delete
`~/Library/Caches/Mozilla/`, relaunch, retry.

`./firefox-hardened-setup.sh update` tells you whether you are behind
Mozilla's latest release; `verify` re-checks the signature chain — run it
after each update.

## Files

| File | Role |
|---|---|
| `firefox-hardened-setup.sh` | The script (single executable). |
| `user.js` | Vendored arkenfox template. **You** download and review it once; the script never fetches it. |
| `user.js.sha256` | Pin of the reviewed `user.js` (trust-on-first-use; auto-recorded on first run). |
| `containers.json` | Optional. Container identities restored into the profile by `setup` (placed here by `unpack`, or by you). |
| `ff-hardened-bundle-YYYYMMDD.tar.gz` | Output of `pack`: script + user.js + hash + containers + SHA-256 manifest. |

## Trust chain

**1. Install artifact = Mozilla's official DMG, verified by you.** Download
from `https://www.mozilla.org/firefox/`, then check it against Mozilla's
published per-release checksums before installing (see *Verifying a
downloaded DMG* below). No intermediary packaging layer remains in the
chain.

**2. Updates = Firefox's native updater.** Mozilla-signed update packages,
applied by the updater with admin authorization via the macOS helper
dialog. The standard user cannot modify the bundle, so nothing running as
that user can ride along.

**3. Independent signature verification (automatic).** `setup`, `update`
and `verify` all run `codesign --verify --deep --strict`, require the
signer's **Team ID `43AQ936H96`** ("Developer ID Application: Mozilla
Corporation") and Gatekeeper/notarization acceptance. A swapped, patched or
re-signed bundle hard-fails these regardless of how it got there.
Cross-check the Team ID constant once yourself against a DMG fetched
directly from mozilla.org: `codesign -d --verbose=2 /Volumes/Firefox/Firefox.app`.

**4. Ownership doctrine — the core of this model.** The bundle must **not**
be writable by the everyday user: `root:admin` after the initial chown, or
admin-owned. That is what (a) blocks silent in-place tampering by anything
running as your user, and (b) forces the admin dialog on updates. The
script checks and reports this posture on every `setup`/`update`/`verify`.
Note: Mozilla's helper validates and may normalize bundle ownership during
the **first** elevated update (an admin-owned result is normal). Either
outcome preserves the property that matters — after the first update, run
`ls -ld /Applications/Firefox.app` and `verify` to confirm the bundle is
still not writable by your user.

**5. Vendored `user.js`** — your reviewed local copy is the anchor,
hash-pinned via `user.js.sha256`; the script refuses to fetch it and aborts
on any drift.

**6. Bundles** — `manifest.sha256` over every file; `unpack` aborts on
mismatch. Integrity, not authenticity: transport bundles yourself.

## APP prerequisite (per machine, once, by an ADMIN)

1. Download the Firefox DMG from `https://www.mozilla.org/firefox/`.
2. Verify it (next section).
3. Drag `Firefox.app` to `/Applications` from the admin account.
4. With Firefox closed: `sudo chown -R root:admin /Applications/Firefox.app`
5. Confirm from the standard account:
   `[ -w /Applications/Firefox.app ] && echo writable || echo protected`
   must print `protected`.

### Verifying a downloaded DMG

With the DMG's version number (e.g. `141.0`):

```
shasum -a 256 ~/Downloads/Firefox*.dmg
curl -fsSL "https://ftp.mozilla.org/pub/firefox/releases/<VER>/SHA256SUMS" | grep <the-hash>
```

A match against a `mac/<lang>/Firefox <VER>.dmg` line proves a
byte-identical official Mozilla artifact. (Applies to release DMGs from the
`releases/` path; Windows-style stub installers embed per-download tokens
and never hash-match — irrelevant here.) Optional extra rigor: verify
`SHA256SUMS.asc` with GPG against Mozilla's release key.

## arkenfox prerequisite (one-time, deliberate)

Download the arkenfox template yourself — current release tag `144.0`, and
the **only official sources** are `github.com/arkenfox/user.js` and
`arkenfox.github.io/gui/` — review it, place it as `user.js` next to the
script. With a bundle from another Mac, `unpack` restores the reviewed copy
plus its hash pin instead.

## Commands

```
./firefox-hardened-setup.sh                  # setup (default)
./firefox-hardened-setup.sh setup
./firefox-hardened-setup.sh update           # staleness check + verify
./firefox-hardened-setup.sh verify
./firefox-hardened-setup.sh pack [out.tar.gz]
./firefox-hardened-setup.sh unpack <bundle.tar.gz>
```

**setup** — checks Firefox is present (fails with install guidance if not)
and reports the bundle's writability posture; verifies the Apple signature
chain; applies the user-domain policies (telemetry, studies, Pocket off —
confirm in `about:policies`) and **removes the old `DisableAppUpdate`
policy** (migration from v4–v9); creates the dedicated `hardened` profile;
applies vendored `user.js` + overrides; installs container identities
(existing profile `containers.json` is never overwritten → bundle copy →
LibreWolf migration). If Homebrew's Caskroom still lists a firefox cask,
setup prints the safe de-registration command — metadata only; **never run
`brew uninstall --cask firefox`** in this model, it would try to delete the
app itself. Idempotent. After first launch, set the profile as default in
`about:profiles` if you launch from the Dock/Finder.

**update** — verifies the signature chain, then makes one announced HTTPS
request to `product-details.mozilla.org` (Mozilla's public release-info
JSON) and compares the installed version against `LATEST_FIREFOX_VERSION`.
If behind: update via **Firefox menu → About Firefox**, authenticate the
helper dialog with the admin account, then re-run `verify`. A failed fetch
degrades to a warning (the signature result stands).

**verify** — signature chain + Mozilla Team ID + Gatekeeper + writability
posture. The former `verify online` (brew-cache DMG vs SHA256SUMS) is gone
with brew; DMG verification is now the manual install-time step above.

**pack / unpack** — unchanged: `pack` verifies `user.js` first, snapshots
`containers.json` from the live profile, writes a manifest, produces the
tar.gz; `unpack` verifies the manifest, restores the files next to the
script, chains into `setup`.

## Replication workflow

Machine A: `./firefox-hardened-setup.sh pack` → Machine B: **admin installs
Firefox** (APP prerequisite above) → copy bundle + script → `./firefox-hardened-setup.sh
unpack ff-hardened-bundle-*.tar.gz` → manual steps the script prints
(default profile, extensions, `about:policies`, parrot check).

## What the bundle does and does not carry

Carries: the script, the reviewed `user.js` + hash pin, and **container
identities**. Does not carry: bookmarks, history, cookies, logins, data
inside containers, extensions (install from AMO), and **Multi-Account
Containers site assignments** (no file export upstream — PR #1533 still
unmerged; use the extension's Sync or re-create per machine).

## Updating arkenfox later

Fetch the new release once (official repo only) → diff against your current
`user.js` → review → replace the vendored copy → delete `user.js.sha256`
(re-recorded on next run) → re-run the script → `pack` a fresh bundle.

## Forcing a container restore on an existing profile

`setup` never overwrites an existing profile `containers.json`. To force:
quit Firefox, delete it from the `*.hardened` profile directory, re-run.

## Overrides applied on top of arkenfox v144 (LibreWolf alignment)

Since arkenfox v128 the base ships FPP (via ETP Strict) and leaves RFP,
letterboxing and WebGL-off inactive. LibreWolf enables RFP, so the
overrides opt in:

- `privacy.resistFingerprinting = true` — LibreWolf default. Trade-offs: a
  GMT-like timezone, light-theme preference, canvas prompts, letterbox
  margins. To fall back to arkenfox's FPP default, remove this line and the
  letterboxing line together.
- `privacy.resistFingerprinting.letterboxing = true` — only coherent
  alongside RFP.
- `webgl.disabled = true` — LibreWolf default.
- `browser.safebrowsing.downloads.remote.enabled = false` — also active in
  arkenfox 0403; kept as defense-in-depth.
- `network.trr.mode = 5` — DoH hard off; DNS enforced at the network layer.
- `browser.startup.page = 3` — session restore kept (LibreWolf wipes).
- History is already kept by arkenfox v144's `clearOnShutdown_v2` defaults —
  no override needed.
- `privacy.clearOnShutdown_v2.cookiesAndStorage = false` — **cookies and
  site data are kept across restarts** (overrides arkenfox 2815; cache and
  form data still clear on close). Trade-off: first-party tracking can
  persist across sessions. Tighter alternative: remove this line and use
  per-site cookie "Allow" exceptions instead. Any pref decision must live
  in the override block, never in the Settings UI — the profile `user.js`
  is re-applied at every startup and overwrites UI changes.
- Optional commented `privacy.spoof_english = 2` for full LibreWolf-style
  en-US locale spoofing.

## Compatibility and verification notes

- bash 3.2-safe; no sudo anywhere in the script; Homebrew not required.
- Uses `shasum -a 256` (incl. `-c`), `tar`, `mktemp -d`, `defaults`,
  `pgrep`, `codesign`, `spctl`, `curl` — all stock macOS.
- If Gatekeeper assessments are globally disabled, `spctl` may reject; the
  script treats that as a failure by design.
- v10 logic (setup without install, policy deletion, ownership posture
  branches — the protected branch exercised as an unprivileged user,
  staleness check up-to-date/outdated/fetch-fail, verify, pack/unpack
  round-trip, manifest/user.js tamper rejection, missing-Firefox guidance,
  Team-ID/codesign/Gatekeeper negatives) smoke-tested end-to-end with
  stubbed `defaults`/`codesign`/`spctl`/`curl`/Firefox — 50 checks. The
  helper-dialog flow itself is macOS behavior verified on-device by you.

## Version history

Documentation revision 6, paired with script v10. Full change log v1–v10 in
the header of `firefox-hardened-setup.sh`; the script ends with its version
marker.
