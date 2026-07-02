#!/bin/bash
# =============================================================================
# firefox-hardened-setup.sh
# Purpose : Install Firefox via Homebrew and configure it to approximate a
#           LibreWolf-like privacy posture using a VENDORED (locally reviewed)
#           arkenfox user.js placed in the same folder as this script.
#           Includes migration of container identities from LibreWolf.
# Target  : macOS (bash 3.2 compatible). Run per-user, no sudo required.
#
# Deploy  : Copy this folder (script + user.js [+ user.js.sha256]) to each
#           Mac and run. No network access needed except brew's Firefox pull.
#
# Version history
#   v1 - Initial release: brew install, telemetry-off policies via defaults,
#        dedicated profile creation, arkenfox fetched from GitHub at runtime,
#        overrides append, containers.json migration, manual-steps summary.
#   v2 - Removed runtime arkenfox download entirely. Script now applies a
#        vendored user.js from its own directory. Added SHA-256 integrity
#        check: verifies against user.js.sha256 if present, otherwise
#        records it (trust-on-first-use). Refuses to run without user.js.
# =============================================================================
set -euo pipefail

PROFILE_NAME="hardened"

info()  { printf '[*] %s\n' "$1"; }
warn()  { printf '[!] %s\n' "$1"; }
fail()  { printf '[X] %s\n' "$1"; exit 1; }

# --- 0. Locate script directory and vendored user.js -------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENDORED_JS="$SCRIPT_DIR/user.js"
HASH_FILE="$SCRIPT_DIR/user.js.sha256"

[ -f "$VENDORED_JS" ] || fail "user.js not found next to this script. Place the reviewed arkenfox user.js in: $SCRIPT_DIR"

# --- 1. Integrity check on the vendored file ---------------------------------
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

# --- 2. Install Firefox (signed, notarized) via Homebrew ---------------------
if ! command -v brew >/dev/null 2>&1; then
    fail "Homebrew not found. Install it first, then re-run."
fi

if brew list --cask firefox >/dev/null 2>&1; then
    info "Firefox cask already installed; running brew upgrade check."
    brew upgrade --cask firefox || true
else
    info "Installing Firefox cask."
    brew install --cask firefox
fi

FIREFOX_BIN="/Applications/Firefox.app/Contents/MacOS/firefox"
[ -x "$FIREFOX_BIN" ] || fail "Firefox binary not found at expected path."

# --- 3. Apply enterprise policies via macOS defaults (survive app updates) ---
info "Applying Firefox enterprise policies (telemetry, studies, Pocket off)."
defaults write org.mozilla.firefox EnterprisePoliciesEnabled -bool TRUE
defaults write org.mozilla.firefox DisableTelemetry -bool TRUE
defaults write org.mozilla.firefox DisableFirefoxStudies -bool TRUE
defaults write org.mozilla.firefox DisablePocket -bool TRUE
defaults write org.mozilla.firefox DontCheckDefaultBrowser -bool TRUE
defaults write org.mozilla.firefox OverrideFirstRunPage -string ""
defaults write org.mozilla.firefox DisableFeedbackCommands -bool TRUE

# --- 4. Create a dedicated profile (never harden a lived-in profile) ---------
info "Creating dedicated profile: ${PROFILE_NAME}"
"$FIREFOX_BIN" -CreateProfile "$PROFILE_NAME" >/dev/null 2>&1 || true

PROFILE_ROOT="$HOME/Library/Application Support/Firefox/Profiles"
PROFILE_DIR=""
for d in "$PROFILE_ROOT"/*."$PROFILE_NAME"; do
    [ -d "$d" ] && PROFILE_DIR="$d"
done
[ -n "$PROFILE_DIR" ] || fail "Could not locate created profile directory."
info "Profile directory located."

# --- 5. Apply vendored user.js and append local overrides --------------------
info "Applying vendored user.js to profile."
cp "$VENDORED_JS" "$PROFILE_DIR/user.js"

info "Appending user-overrides (LibreWolf-alignment tweaks)."
cat >> "$PROFILE_DIR/user.js" <<'EOF'

/* === user-overrides: LibreWolf-alignment (appended by setup script v2) === */
/* arkenfox already enables RFP, TCP/ETP-strict, telemetry prefs off.       */
/* Overrides below adjust the small deltas and common usability choices.   */
user_pref("privacy.resistFingerprinting.letterboxing", true);   // LW default
user_pref("webgl.disabled", true);                              // LW default
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("network.trr.mode", 5);            // DoH off; DNS is enforced at
                                             // network layer in this setup
user_pref("browser.startup.page", 3);        // restore session (convenience;
                                             // remove if you want LW's wipe)
user_pref("privacy.clearOnShutdown.history", false); // keep history; set
                                             // true for full LW behaviour
/* === end overrides === */
EOF

# --- 6. Migrate container identities from LibreWolf, if present --------------
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
[ "$MIGRATED" -eq 0 ] && warn "No LibreWolf containers.json found; skipping."

# --- 7. Summary of remaining manual steps ------------------------------------
cat <<'EOF'

Done. Remaining one-time manual steps (in Firefox, profile "hardened"):
  1. Launch:  /Applications/Firefox.app/Contents/MacOS/firefox -P hardened
  2. Install extensions from addons.mozilla.org (Mozilla-signed):
       - uBlock Origin
       - Multi-Account Containers
  3. In Multi-Account Containers: enable Sync (Firefox Account) to replicate
     container identities AND site assignments to your other Macs.
     Without Sync: identities carried over via containers.json; site
     assignments must be re-created once per machine.
  4. Optional: set this profile as default in about:profiles.

Updating arkenfox later: fetch the new release ONCE, diff it against your
current user.js, review, replace the vendored copy, delete user.js.sha256
(it will be re-recorded), then re-run this script on each Mac.
EOF

# v2
