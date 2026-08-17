#!/bin/bash
# =============================================================================
# firefox-hardened-setup.sh
# Purpose : Configure and harden Firefox on macOS to approximate a
#           LibreWolf-like privacy posture using a VENDORED (locally
#           reviewed) arkenfox user.js placed in the same folder as this
#           script. Includes migration of container identities from
#           LibreWolf, portable pack/unpack bundles for replicating the
#           setup on additional Macs, and independent verification of the
#           installed app against Apple's signature chain.
#           App lifecycle (v10+): Firefox is installed once from Mozilla's
#           DMG by an ADMIN and then updates ITSELF natively; the macOS
#           helper dialog asks for admin credentials at each update
#           (standard-user model). This script does not install the app.
# Target  : macOS (bash 3.2 compatible). Run per-user, no sudo required.
#
# Usage   :
#   ./firefox-hardened-setup.sh                  # setup (default)
#   ./firefox-hardened-setup.sh setup            # harden + restore (no install)
#   ./firefox-hardened-setup.sh update           # staleness check + verify
#   ./firefox-hardened-setup.sh verify           # signature/Team-ID/Gatekeeper
#   ./firefox-hardened-setup.sh pack [out.tar.gz]# create replication bundle
#   ./firefox-hardened-setup.sh unpack <bundle>  # verify bundle, restore, setup
#   ./firefox-hardened-setup.sh help
#
# !!! CRITICAL - UPDATE MODEL (v10+) !!!
#   Firefox updates ITSELF (native updater, Mozilla-signed updates).
#   Because the app bundle is not writable by this standard user, macOS
#   shows the Firefox helper authorization dialog at each update - enter
#   your ADMIN account's credentials there. Do NOT postpone these dialogs:
#   an unpatched browser is the worst component to leave stale.
#   If an update wedges (helper prompt loops/stalls): quit Firefox, delete
#   ~/Library/Caches/Mozilla/ , relaunch, retry.
#   "./firefox-hardened-setup.sh update" compares the installed version
#   against Mozilla's latest release; run "verify" after updates.
#
# Trust model (short):
#   - The app comes straight from Mozilla: installed once from the official
#     DMG (verify it against Mozilla's published SHA256SUMS - commands in
#     the README), then kept current by Firefox's own updater with
#     Mozilla-signed updates. Homebrew is no longer part of the Firefox
#     lifecycle on this machine.
#   - This script verifies the installed app independently: Apple code
#     signature chain must be valid, the signer's Team ID must be
#     Mozilla's (43AQ936H96), and Gatekeeper/notarization must accept the
#     app. Runs automatically at the end of setup, update and verify.
#   - The app bundle must NOT be writable by this user (root:admin or
#     admin-owned). That is what blocks silent in-place tampering by
#     anything running as this user AND forces the admin dialog on
#     updates. setup checks and reports this.
#
# Deploy  : Machine A (source): run setup once, customise your containers,
#           then "pack" to produce a bundle. Machine B (target): ADMIN
#           installs Firefox from Mozilla's DMG (see APP PREREQUISITE),
#           then copy the bundle + this script over and run
#           "unpack <bundle>" - it verifies the manifest, restores user.js
#           / user.js.sha256 / containers.json next to the script and
#           chains into setup. Network access: only Mozilla's
#           product-details JSON when you run "update" (announced).
#
# APP PREREQUISITE (per machine, done once by an ADMIN):
#   Download the Firefox DMG from https://www.mozilla.org/firefox/ ,
#   verify it against Mozilla's SHA256SUMS (commands in the README), drag
#   Firefox.app to /Applications from the admin account, then, with
#   Firefox closed:  sudo chown -R root:admin /Applications/Firefox.app
#   The standard user must NOT be able to write to the bundle.
#
# MANUAL PREREQUISITE (one-time, deliberate - this script will NOT do it):
#   1. Download the arkenfox template yourself:
#        https://raw.githubusercontent.com/arkenfox/user.js/master/user.js
#      (or a pinned release tag from https://github.com/arkenfox/user.js/releases)
#      Official sources are ONLY github.com/arkenfox/user.js and
#      arkenfox.github.io/gui/ - do not trust other sites.
#   2. REVIEW the file - it is plain-text prefs, auditable in minutes.
#   3. Place it as "user.js" in the same folder as this script.
#   The refusal to auto-download is intentional: the reviewed local copy is
#   the trust anchor, hash-pinned via user.js.sha256 on first run.
#   (Alternative: restore everything from a bundle via "unpack".)
#
# Version history
#   v1 - Initial release: brew install, telemetry-off policies via defaults,
#        dedicated profile creation, arkenfox fetched from GitHub at runtime,
#        overrides append, containers.json migration, manual-steps summary.
#   v2 - Removed runtime arkenfox download entirely. Script now applies a
#        vendored user.js from its own directory. Added SHA-256 integrity
#        check: verifies against user.js.sha256 if present, otherwise
#        records it (trust-on-first-use). Refuses to run without user.js.
#   v3 - Documentation: added explicit MANUAL PREREQUISITE instructions for
#        obtaining the arkenfox user.js (this script never downloads it);
#        expanded the missing-file error message with the source URL.
#   v4 - Non-admin user support: cask installs to ~/Applications via --appdir
#        when /Applications is not writable (no sudo ever required; matches a
#        deliberately non-sudoer user design). Firefox binary now detected in
#        both ~/Applications and /Applications. Added DisableAppUpdate policy
#        so brew remains the single update path (user-writable app would
#        otherwise self-update and race brew's version bookkeeping) - remove
#        that line if you prefer Firefox self-updates.
#   v5 - Replication + ergonomics: new subcommands. "pack" bundles the script,
#        user.js, user.js.sha256 and containers.json (live profile copy
#        preferred over script-dir copy) into a tar.gz with a SHA-256
#        manifest; "unpack <file>" verifies the manifest, restores those
#        files next to the script and chains into setup. "update" runs only
#        the brew upgrade. Setup changes: a containers.json next to the
#        script (from a bundle) now takes priority over LibreWolf migration,
#        and an existing containers.json in the profile is never overwritten
#        (safe re-runs). user.js is hash-verified before packing. Detection
#        loops rewritten as if-conditionals (set -e safety when nothing
#        matches). Added about:policies verification step to the summary.
#        Paired README.md added as deliverable.
#   v6 - Independent trust verification + update-discipline emphasis. New
#        "verify [online]" subcommand: local checks validate the Apple code
#        signature (codesign --deep --strict), require Mozilla's Team ID
#        43AQ936H96 and Gatekeeper/notarization acceptance (spctl) - a
#        swapped or re-signed app fails these regardless of what the
#        Homebrew cask claims. "verify online" additionally fetches
#        Mozilla's official SHA256SUMS for the installed version (single
#        announced HTTPS request to ftp.mozilla.org) and confirms the
#        brew-cached DMG hash appears in it (byte-identical official
#        artifact). Local signature verification now runs automatically at
#        the end of setup and update. Update criticality (no self-updates;
#        bare "brew upgrade" skips the cask) is now stated in the header,
#        usage text, setup summary and update output. README updated.
#   v7 - Overrides corrected against the real arkenfox v144 content. Since
#        arkenfox v128, RFP, letterboxing and webgl.disabled are inactive in
#        the base (FPP via ETP Strict is the default), so the previous
#        override comment claiming "arkenfox already enables RFP" was wrong
#        and the profile effectively ran FPP + letterboxing - an incoherent
#        combination. For the stated LibreWolf-alignment goal, RFP is now
#        enabled explicitly. Removed the legacy
#        privacy.clearOnShutdown.history override (v144's clearOnShutdown_v2
#        prefs already keep history). Documented that arkenfox wipes cookies
#        and site data on shutdown (2815) - add per-site cookie "Allow"
#        exceptions to stay logged in. Added the _user.js.parrot SUCCESS
#        check (arkenfox's built-in runtime syntax canary) to manual steps.
#   v8 - Docs: manual step 6 rewritten. macOS Dock/Finder launches ignore
#        -P and always open the install's DEFAULT profile (dedicated
#        profiles / installs.ini, FF67+), so "Set as default profile" in
#        about:profiles is required before icon-based launches; until then
#        a plain launch silently uses or creates an unhardened
#        default-release profile. No functional changes.
#   v9 - Keep cookies across restarts: added
#        privacy.clearOnShutdown_v2.cookiesAndStorage=false to the override
#        block, overriding arkenfox 2815. Rationale: UI changes to this
#        setting cannot stick because the profile user.js re-asserts prefs
#        at every startup; the change must live in the override block.
#        sanitizeOnShutdown stays enabled (cache + formdata still cleared).
#        Reverting to full wipe-on-close: delete that line and re-run, or
#        keep the wipe and use per-site cookie "Allow" exceptions.
#   v10 - Update model switched to native Firefox self-updates (option C).
#        setup no longer installs/updates via Homebrew; it checks Firefox
#        is present and that the bundle is NOT writable by the current
#        user (tamper protection + forces the admin helper dialog on
#        updates), and it removes the old DisableAppUpdate policy
#        (migration from v4-v9). "update" repurposed: signature check +
#        installed-vs-latest comparison against Mozilla's product-details
#        JSON, with instructions to update via About Firefox (admin
#        credentials in the helper dialog). "verify online" removed - no
#        brew cache exists in this model; manual DMG verification commands
#        moved to the README. If brew's Caskroom still lists firefox,
#        setup prints the safe de-registration command (metadata only;
#        never brew uninstall). Header, usage, summary, README rewritten.
# =============================================================================
set -euo pipefail

PROFILE_NAME="hardened"
BUNDLE_NAME="ff-hardened-bundle"
# Mozilla Corporation's Apple Developer Team ID, constant across Firefox
# releases for years (visible in Mozilla's own Bugzilla codesign outputs).
# Cross-check once yourself against a DMG fetched directly from mozilla.org:
#   codesign -d --verbose=2 /Volumes/Firefox/Firefox.app
EXPECTED_TEAM_ID="43AQ936H96"

info()  { printf '[*] %s\n' "$1"; }
warn()  { printf '[!] %s\n' "$1"; }
fail()  { printf '[X] %s\n' "$1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
VENDORED_JS="$SCRIPT_DIR/user.js"
HASH_FILE="$SCRIPT_DIR/user.js.sha256"
VENDORED_CONTAINERS="$SCRIPT_DIR/containers.json"
PROFILE_ROOT="$HOME/Library/Application Support/Firefox/Profiles"

usage() {
cat <<EOF
Usage: ./$SCRIPT_NAME [command]

  setup              Verify the installed Firefox (presence, ownership,
                     Apple signature), apply policies, create the
                     "$PROFILE_NAME" profile, apply vendored user.js +
                     overrides, restore/migrate container identities.
                     Does NOT install or update the app (see header).
                     Default when no command is given.
  update             Staleness check: verifies the app signature, then
                     compares the installed version against Mozilla's
                     latest release (one announced HTTPS request to
                     product-details.mozilla.org). The update itself runs
                     inside Firefox (About Firefox) with the admin dialog.
  verify             Verify the installed app: Apple code-signature chain
                     + Mozilla Team ID ($EXPECTED_TEAM_ID) +
                     Gatekeeper/notarization.
  pack [out.tar.gz]  Bundle script + user.js + user.js.sha256 +
                     containers.json into a portable archive with a SHA-256
                     manifest. Default output:
                     $BUNDLE_NAME-YYYYMMDD.tar.gz next to the script.
  unpack <bundle>    Verify a bundle's manifest, restore its files next to
                     this script, then run setup.
  help               Show this text.
EOF
}

# --- shared helpers ----------------------------------------------------------

locate_profile_dir() {
    PROFILE_DIR=""
    for d in "$PROFILE_ROOT"/*."$PROFILE_NAME"; do
        if [ -d "$d" ]; then PROFILE_DIR="$d"; fi
    done
}

locate_firefox_bin() {
    FIREFOX_BIN=""
    for CAND in "$HOME/Applications/Firefox.app/Contents/MacOS/firefox" \
                "/Applications/Firefox.app/Contents/MacOS/firefox"; do
        if [ -x "$CAND" ] && [ -z "$FIREFOX_BIN" ]; then FIREFOX_BIN="$CAND"; fi
    done
    [ -n "$FIREFOX_BIN" ] || fail "Firefox not found in ~/Applications or /Applications. Install it first (as ADMIN): download the DMG from https://www.mozilla.org/firefox/ , verify it (README), drag to /Applications, then: sudo chown -R root:admin /Applications/Firefox.app - and re-run."
}

firefox_running() { pgrep -x firefox >/dev/null 2>&1; }

# Verify vendored user.js against user.js.sha256; record hash on first use.
verify_or_record_hash() {
    CURRENT_HASH="$(shasum -a 256 "$VENDORED_JS" | awk '{print $1}')"
    if [ -f "$HASH_FILE" ]; then
        EXPECTED_HASH="$(awk '{print $1}' "$HASH_FILE")"
        if [ "$CURRENT_HASH" != "$EXPECTED_HASH" ]; then
            fail "user.js SHA-256 mismatch. File differs from the reviewed version. Re-review the file and update user.js.sha256 deliberately if the change is intended."
        fi
        info "user.js integrity verified (SHA-256 match)."
    else
        printf '%s  user.js\n' "$CURRENT_HASH" > "$HASH_FILE"
        warn "No user.js.sha256 found. Recorded current hash (trust-on-first-use):"
        warn "  $CURRENT_HASH"
        warn "Distribute this hash file alongside the script to your other Macs."
    fi
}

# v10: the app is installed/updated natively (Mozilla DMG + self-updater).
# setup only checks presence and that the bundle is protected from this user.
check_firefox_install() {
    locate_firefox_bin
    APP="${FIREFOX_BIN%/Contents/MacOS/firefox}"
    info "Firefox found: $APP"
    # If Homebrew still thinks it manages Firefox, say how to de-register
    # safely. NEVER run 'brew uninstall --cask firefox' in this model -
    # it would try to delete the app itself.
    if command -v brew >/dev/null 2>&1; then
        BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
        if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/Caskroom/firefox" ]; then
            warn "Homebrew still lists a firefox cask. De-register it (metadata"
            warn "only; the app itself is untouched):"
            warn "    rm -rf \"$BREW_PREFIX/Caskroom/firefox\""
        fi
    fi
}

# Independent (Homebrew-free) verification of the installed app:
# Apple code-signature chain + Mozilla Team ID + Gatekeeper/notarization.
# A swapped, patched or re-signed app fails these checks regardless of what
# the cask claimed (a tampered copy shows Signature=adhoc / different or no
# TeamIdentifier). Sets APP and APP_VER for callers.
verify_app_signature() {
    locate_firefox_bin
    APP="${FIREFOX_BIN%/Contents/MacOS/firefox}"

    info "Verifying Apple code signature (independent of Homebrew): $APP"
    codesign --verify --deep --strict "$APP" 2>/dev/null \
        || fail "codesign verification FAILED - the app bundle is modified or improperly signed. Do NOT launch it. (brew reinstall from a reviewed cask, then re-verify.)"

    CS_INFO="$(codesign -d --verbose=2 "$APP" 2>&1 || true)"
    TEAM_ID="$(printf '%s\n' "$CS_INFO" | awk -F= '/^TeamIdentifier=/{print $2}')"
    AUTHORITY="$(printf '%s\n' "$CS_INFO" | awk -F= '/^Authority=/{print $2; exit}')"
    if [ "$TEAM_ID" != "$EXPECTED_TEAM_ID" ]; then
        fail "Signer Team ID mismatch: got '${TEAM_ID:-none}', expected Mozilla ($EXPECTED_TEAM_ID). A re-signed/tampered app presents a different (or no) Team ID. Do NOT launch it."
    fi
    info "Signature OK: ${AUTHORITY:-Developer ID} / TeamIdentifier=$TEAM_ID"

    if spctl --assess --type execute "$APP" >/dev/null 2>&1; then
        info "Gatekeeper/notarization assessment: accepted."
    else
        fail "Gatekeeper assessment REJECTED the app (spctl). Either it fails notarization or Gatekeeper assessment is disabled/altered on this Mac. Investigate before launching."
    fi

    APP_VER="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null \
        || /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null \
        || true)"
    if [ -n "$APP_VER" ]; then info "Installed Firefox version: $APP_VER"; fi

    # Ownership posture: the bundle must not be writable by this user.
    if [ -w "$APP" ]; then
        warn "The app bundle IS WRITABLE by this user - no tamper protection,"
        warn "and Firefox will self-update without any admin dialog."
        warn "Recommended (from your ADMIN account, with Firefox closed):"
        warn "    sudo chown -R root:admin \"$APP\""
    else
        info "App bundle is not writable by this user (tamper-protected)."
        info "Updates will show the macOS helper dialog - authenticate with"
        info "your ADMIN account when it appears."
    fi
}

# --- setup -------------------------------------------------------------------

do_setup() {
    # --- 0. Vendored user.js must exist --------------------------------------
    [ -f "$VENDORED_JS" ] || fail "user.js not found next to this script. Manually download it from https://raw.githubusercontent.com/arkenfox/user.js/master/user.js , review it, then place it in: $SCRIPT_DIR (see MANUAL PREREQUISITE in the script header). If you have a bundle from another Mac, run: ./$SCRIPT_NAME unpack <bundle.tar.gz>"

    # --- 1. Integrity check on the vendored file -----------------------------
    verify_or_record_hash

    # --- 2. Locate Firefox (installed natively - see APP PREREQUISITE) -------
    check_firefox_install

    # --- 2b. Verify the app independently of Homebrew ------------------------
    verify_app_signature

    # --- 3. Apply enterprise policies via macOS defaults (survive updates) ---
    # User-domain policies; Mozilla documents ~/Library policies as the
    # no-sudo, per-user mechanism. Verify later in about:policies.
    info "Applying Firefox enterprise policies (telemetry, studies, Pocket off)."
    defaults write org.mozilla.firefox EnterprisePoliciesEnabled -bool TRUE
    defaults write org.mozilla.firefox DisableTelemetry -bool TRUE
    defaults write org.mozilla.firefox DisableFirefoxStudies -bool TRUE
    defaults write org.mozilla.firefox DisablePocket -bool TRUE
    defaults write org.mozilla.firefox DontCheckDefaultBrowser -bool TRUE
    defaults write org.mozilla.firefox OverrideFirstRunPage -string ""
    defaults write org.mozilla.firefox DisableFeedbackCommands -bool TRUE
    # v10: Firefox must self-update now - ensure the old policy is gone
    # (migration from v4-v9 installs).
    defaults delete org.mozilla.firefox DisableAppUpdate 2>/dev/null || true
    info "DisableAppUpdate policy removed (native self-updates enabled)."

    # --- 4. Create a dedicated profile (never harden a lived-in profile) -----
    info "Creating dedicated profile: ${PROFILE_NAME}"
    "$FIREFOX_BIN" -CreateProfile "$PROFILE_NAME" >/dev/null 2>&1 || true

    locate_profile_dir
    [ -n "$PROFILE_DIR" ] || fail "Could not locate created profile directory."
    info "Profile directory located."

    # --- 5. Apply vendored user.js and append local overrides ----------------
    info "Applying vendored user.js to profile."
    cp "$VENDORED_JS" "$PROFILE_DIR/user.js"

    info "Appending user-overrides (LibreWolf-alignment tweaks)."
    cat >> "$PROFILE_DIR/user.js" <<'EOF'

/* === user-overrides: LibreWolf-alignment (appended by setup script v7) === */
/* arkenfox v144 ships FPP-by-default (via ETP Strict); RFP, letterboxing   */
/* and webgl.disabled are inactive in the base since v128. LibreWolf        */
/* enables RFP, so we opt into RFP + letterboxing + webgl-off to match it.  */
/* RFP trade-offs: GMT-like timezone, light-theme preference, canvas       */
/* prompts, letterbox margins. To fall back to arkenfox's FPP default,     */
/* remove the RFP line AND the letterboxing line together (letterboxing    */
/* without RFP is an odd, fingerprintable combination).                    */
user_pref("privacy.resistFingerprinting", true);                // LW default
user_pref("privacy.resistFingerprinting.letterboxing", true);   // LW default
user_pref("webgl.disabled", true);                              // LW default
user_pref("browser.safebrowsing.downloads.remote.enabled", false); // arkenfox
                                             // 0403 sets this too; kept as
                                             // defense-in-depth
user_pref("network.trr.mode", 5);            // DoH off; DNS is enforced at
                                             // network layer in this setup
user_pref("browser.startup.page", 3);        // restore session (convenience;
                                             // remove for LW's fresh start)
/* History is already KEPT by arkenfox v144 (clearOnShutdown_v2, 2811/2812) */
/* so no history override is needed.                                        */
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false); // KEEP
                                             // cookies + site data across
                                             // restarts (overrides arkenfox
                                             // 2815; cache and formdata are
                                             // still cleared on close).
                                             // Trade-off: 1st-party tracking
                                             // can persist across sessions.
                                             // Tighter alternative: delete
                                             // this line and use per-site
                                             // cookie "Allow" exceptions
                                             // instead (they survive the
                                             // wipe but disable partitioning
                                             // for the allowed sites).
   // user_pref("privacy.spoof_english", 2); // optional full LW-style en-US spoofing
/* === end overrides === */
EOF

    # --- 6. Container identities: existing > bundle > LibreWolf --------------
    if [ -f "$PROFILE_DIR/containers.json" ]; then
        warn "Profile already has containers.json; leaving it untouched."
        warn "(To force a restore: quit Firefox, delete it from the profile, re-run setup.)"
    elif [ -f "$VENDORED_CONTAINERS" ]; then
        cp "$VENDORED_CONTAINERS" "$PROFILE_DIR/containers.json"
        info "containers.json restored from bundle/script-dir copy."
    else
        LW_ROOT="$HOME/Library/Application Support/LibreWolf/Profiles"
        MIGRATED=0
        if [ -d "$LW_ROOT" ]; then
            for lw in "$LW_ROOT"/*/containers.json; do
                if [ -f "$lw" ] && [ "$MIGRATED" -eq 0 ]; then
                    cp "$lw" "$PROFILE_DIR/containers.json"
                    MIGRATED=1
                    info "containers.json migrated from LibreWolf profile."
                fi
            done
        fi
        if [ "$MIGRATED" -eq 0 ]; then
            warn "No containers.json found (bundle or LibreWolf); skipping."
        fi
    fi

    # --- 7. Summary of remaining manual steps --------------------------------
    printf '\nDone.\n'
    warn "UPDATE MODEL: Firefox self-updates. When an update installs, macOS"
    warn "shows the Firefox helper authorization dialog - enter your ADMIN"
    warn "account's credentials. Do not postpone updates. If one wedges:"
    warn "quit Firefox, delete ~/Library/Caches/Mozilla/ , relaunch."
    printf '\nRemaining one-time manual steps (in Firefox, profile "%s"):\n' "$PROFILE_NAME"
    printf '  1. Launch:  %s -P %s\n' "$FIREFOX_BIN" "$PROFILE_NAME"
    cat <<'EOF'
  2. Verify policies are active: open about:policies - the entries applied
     by this script (DisableTelemetry, DisableFirefoxStudies, ...) must be listed.
  3. Verify user.js applied cleanly: in about:config search _user.js.parrot -
     it must read "SUCCESS: ..." (arkenfox's built-in syntax canary).
  4. Install extensions from addons.mozilla.org (Mozilla-signed):
       - uBlock Origin
       - Multi-Account Containers
  5. In Multi-Account Containers: enable Sync (Firefox Account) to replicate
     container identities AND site assignments to your other Macs.
     Without Sync: identities carried over via containers.json; site
     assignments must be re-created once per machine (the extension has no
     file export - upstream PR #1533 is still unmerged).
  6. If you will launch from the Dock/Finder: about:profiles > hardened >
     "Set as default profile". Icon launches always open the DEFAULT
     profile and do NOT remember -P; until this is set, a plain launch
     silently uses or creates a different, UNHARDENED profile.
  7. Periodically: "./firefox-hardened-setup.sh update" (installed vs
     latest Mozilla release + signature check), and after each Firefox
     update: "./firefox-hardened-setup.sh verify".

Replicating to another Mac: run "./firefox-hardened-setup.sh pack" here,
copy the bundle + this script over, run "unpack <bundle>" there.

UPDATING FIREFOX: native self-update. Check/trigger via Firefox menu >
About Firefox; authenticate the helper dialog with your ADMIN account.
"./firefox-hardened-setup.sh update" tells you if you are behind.

Updating arkenfox: fetch the new release ONCE, diff it against your current
user.js, review, replace the vendored copy, delete user.js.sha256 (it will
be re-recorded), re-run this script, then "pack" a fresh bundle for your
other Macs.
EOF
}

# --- update ------------------------------------------------------------------

do_update() {
    verify_app_signature
    [ -n "${APP_VER:-}" ] || fail "Cannot determine installed Firefox version."

    VERSIONS_URL="https://product-details.mozilla.org/1.0/firefox_versions.json"
    info "Single outbound HTTPS request: checking Mozilla's latest release:"
    info "  $VERSIONS_URL"
    LATEST="$(curl -fsSL --proto '=https' "$VERSIONS_URL" 2>/dev/null \
        | sed -n 's/.*"LATEST_FIREFOX_VERSION": *"\([^"]*\)".*/\1/p' \
        | head -1 || true)"
    if [ -z "$LATEST" ]; then
        warn "Could not fetch Mozilla's latest-version info; check manually"
        warn "via Firefox menu > About Firefox."
        return 0
    fi
    info "Latest Mozilla release: $LATEST"
    if [ "$APP_VER" = "$LATEST" ]; then
        info "Firefox is up to date."
    else
        warn "Installed $APP_VER != latest $LATEST."
        warn "Update now: Firefox menu > About Firefox (download runs in the"
        warn "background; authenticate the helper dialog with your ADMIN"
        warn "account when it installs). Re-run 'verify' afterwards."
    fi
}

# --- verify ------------------------------------------------------------------

do_verify() {
    MODE="${1:-}"
    case "$MODE" in
        "") : ;;
        online)
            warn "'verify online' was removed in v10: without Homebrew there"
            warn "is no cached DMG to compare. Manual DMG verification"
            warn "commands are in the README. Running local verification:"
            ;;
        *) fail "Usage: ./$SCRIPT_NAME verify" ;;
    esac

    verify_app_signature
    info "Local verification complete (signature chain, Mozilla Team ID,"
    info "Gatekeeper)."
}

# --------------------------------------------------------------------------

# --- pack --------------------------------------------------------------------

do_pack() {
    OUT="${1:-$SCRIPT_DIR/$BUNDLE_NAME-$(date +%Y%m%d).tar.gz}"

    [ -f "$VENDORED_JS" ] || fail "Nothing to pack: user.js not found in $SCRIPT_DIR."
    # Never bundle an unverified user.js.
    verify_or_record_hash

    # Freshest containers.json wins: live profile first, script dir fallback.
    locate_profile_dir
    CONTAINERS_SRC=""
    if [ -n "$PROFILE_DIR" ] && [ -f "$PROFILE_DIR/containers.json" ]; then
        CONTAINERS_SRC="$PROFILE_DIR/containers.json"
        info "Packing containers.json from the live \"$PROFILE_NAME\" profile."
        if firefox_running; then
            warn "Firefox appears to be running. If you changed containers just now, quit it and re-pack for a consistent snapshot."
        fi
    elif [ -f "$VENDORED_CONTAINERS" ]; then
        CONTAINERS_SRC="$VENDORED_CONTAINERS"
        warn "No containers.json in the profile; packing the script-dir copy instead."
    else
        warn "No containers.json found anywhere; bundle will not carry container identities."
    fi

    STAGE="$(mktemp -d)"
    trap 'rm -rf "$STAGE"' EXIT
    mkdir "$STAGE/$BUNDLE_NAME"

    cp "$SCRIPT_DIR/$SCRIPT_NAME" "$STAGE/$BUNDLE_NAME/"
    cp "$VENDORED_JS"             "$STAGE/$BUNDLE_NAME/user.js"
    cp "$HASH_FILE"               "$STAGE/$BUNDLE_NAME/user.js.sha256"
    FILES="$SCRIPT_NAME user.js user.js.sha256"
    if [ -n "$CONTAINERS_SRC" ]; then
        cp "$CONTAINERS_SRC" "$STAGE/$BUNDLE_NAME/containers.json"
        FILES="$FILES containers.json"
    fi

    # shellcheck disable=SC2086  # intentional word split of fixed filenames
    ( cd "$STAGE/$BUNDLE_NAME" && shasum -a 256 $FILES > manifest.sha256 )

    tar -czf "$OUT" -C "$STAGE" "$BUNDLE_NAME"
    rm -rf "$STAGE"
    trap - EXIT

    info "Bundle written: $OUT"
    info "Contents: $FILES manifest.sha256"
    info "On the target Mac: copy the bundle + this script, then run:"
    info "  ./$SCRIPT_NAME unpack $(basename "$OUT")"
    info "Note: the manifest gives integrity, not authenticity - transport the"
    info "bundle yourself (or verify its own sha256 out-of-band)."
}

# --- unpack ------------------------------------------------------------------

do_unpack() {
    BUNDLE="${1:-}"
    [ -n "$BUNDLE" ] || fail "Usage: ./$SCRIPT_NAME unpack <bundle.tar.gz>"
    [ -f "$BUNDLE" ] || fail "Bundle not found: $BUNDLE"

    STAGE="$(mktemp -d)"
    trap 'rm -rf "$STAGE"' EXIT
    tar -xzf "$BUNDLE" -C "$STAGE" || fail "Could not extract bundle (valid .tar.gz?)."

    SRC="$STAGE/$BUNDLE_NAME"
    if [ ! -d "$SRC" ]; then SRC="$STAGE"; fi   # tolerate flat archives
    [ -f "$SRC/user.js" ] || fail "Bundle does not contain user.js; not a valid bundle."

    if [ -f "$SRC/manifest.sha256" ]; then
        ( cd "$SRC" && shasum -a 256 -c manifest.sha256 >/dev/null 2>&1 ) \
            || fail "Manifest verification FAILED - bundle corrupted or modified. Aborting."
        info "Bundle manifest verified (SHA-256)."
    else
        warn "Bundle has no manifest.sha256; skipping verification (older/foreign bundle)."
    fi

    cp "$SRC/user.js" "$VENDORED_JS"
    if [ -f "$SRC/user.js.sha256" ]; then
        cp "$SRC/user.js.sha256" "$HASH_FILE"
    fi
    info "Restored user.js + user.js.sha256 next to the script."

    if [ -f "$SRC/containers.json" ]; then
        cp "$SRC/containers.json" "$VENDORED_CONTAINERS"
        info "Restored containers.json next to the script (setup will install it)."
    fi

    if [ -f "$SRC/$SCRIPT_NAME" ]; then
        info "Bundle carries its own script copy; the running copy is kept as-is."
    fi

    rm -rf "$STAGE"
    trap - EXIT

    info "Bundle restored. Continuing with setup."
    do_setup
}

# --- dispatch ----------------------------------------------------------------

CMD="${1:-setup}"
if [ $# -gt 0 ]; then shift; fi

case "$CMD" in
    setup)          do_setup ;;
    update)         do_update ;;
    verify)         do_verify "${1:-}" ;;
    pack)           do_pack "${1:-}" ;;
    unpack)         do_unpack "${1:-}" ;;
    help|-h|--help) usage ;;
    *)              usage; fail "Unknown command: $CMD" ;;
esac
# v10
