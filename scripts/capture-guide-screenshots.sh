#!/usr/bin/env bash
#
# Capture the screenshots for docs/USER-GUIDE.md.
#
# SAFETY (non-negotiable): this script NEVER captures the whole display. Every
# window shot uses `screencapture -l<windowID>`, which captures ONLY the pixels of
# one specific window (identified by the target app's pid). No private/unrelated
# window can leak into a shot. CLI shots are rendered from captured command OUTPUT
# into a self-contained PNG — the real terminal is never photographed either.
#
# It is fully non-interactive: it builds the fixture + Cockpit, launches them,
# arranges them frontmost, captures each window by ID, and tears everything down.
#
# Output: docs/images/*.png (the exact filenames docs/USER-GUIDE.md references).
#
# Run it when you (the operator) are not using the screen for something private —
# it brings TestHostApp and the Cockpit frontmost while it works.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
IMAGES="$ROOT/docs/images"
FIXTURE="$ROOT/Fixtures/TestHostApp/.build/TestHostApp.app"
FIXTURE_BID="com.autopilot.testhostapp"
mkdir -p "$IMAGES"

log()  { printf '\033[1;34m[capture]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[capture] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# The capture helper (Swift, compiled once): `winid <pid>` and `render <title> <out>`.
# Built into a temp binary at startup — no PyObjC / external deps.
HELPER=""
build_helper() {
  HELPER="$(/usr/bin/mktemp -d)/guide-helper"
  /usr/bin/swiftc -O "$ROOT/scripts/guide-capture-helper.swift" -o "$HELPER" \
    || die "could not compile the capture helper"
}

# --- window-id capture: capture ONLY the given app pid's frontmost window -------
# Prints the CGWindowID of the frontmost on-screen window owned by $1 (a pid).
frontmost_window_id() { "$HELPER" winid "$1"; }

# Capture one window (by pid) to a PNG. Window-scoped ONLY — never the display.
capture_window() {
  local pid="$1" out="$2"
  local wid; wid="$(frontmost_window_id "$pid")"
  [ -n "$wid" ] || die "no on-screen window for pid $pid (is it frontmost/visible?)"
  # -l<id> window capture, -o no shadow, -x silent. NOT -S (that would grab screen).
  /usr/sbin/screencapture -x -o -l"$wid" "$out"
  [ -s "$out" ] || die "capture produced no image: $out"
  log "wrote $(basename "$out")"
}

# Render captured CLI text into a standalone PNG via the Swift helper, so the real
# terminal is never photographed. Body comes in on stdin.
render_text_png() {
  local title="$1" out="$2" ; shift 2
  printf '%s' "$*" | "$HELPER" render "$title" "$out"
  [ -s "$out" ] || die "text render produced no image: $out"
  log "wrote $(basename "$out") (rendered CLI output)"
}

BIN=""
build() {
  log "building autopilot + Cockpit (release)…"
  ( cd "$ROOT" && swift build -c release >/dev/null )
  BIN="$(cd "$ROOT" && swift build -c release --show-bin-path)"
  [ -x "$BIN/autopilot" ] || die "autopilot CLI not built"
  if [ ! -d "$FIXTURE" ]; then
    log "building TestHostApp fixture…"
    ( "$ROOT/Fixtures/TestHostApp/make-app.sh" >/dev/null )
  fi
}

cleanup() {
  /usr/bin/pkill -f "TestHostApp.app" 2>/dev/null || true
  /usr/bin/pkill -f "AutopilotCockpit" 2>/dev/null || true
}
trap cleanup EXIT

# ---- CLI shots (rendered from real command output) -----------------------------
capture_cli() {
  log "capturing CLI output…"
  /usr/bin/open -n "$FIXTURE"; sleep 2
  local doc sug run runf
  doc="$("$BIN/autopilot" doctor 2>&1 || true)"
  render_text_png "autopilot doctor" "$IMAGES/cli-doctor.png" "$doc"

  sug="$("$BIN/autopilot" suggest "$FIXTURE_BID" 2>&1 | head -20 || true)"
  render_text_png "autopilot suggest $FIXTURE_BID" "$IMAGES/cli-suggest.png" "$sug"

  # A tiny passing plan + a failing one, generated on the fly.
  local tmp; tmp="$(/usr/bin/mktemp -d)"
  cat > "$tmp/pass.json" <<JSON
{ "schemaVersion":"1.1","name":"guide demo","target":{"path":"$FIXTURE"},
  "defaults":{"timeoutMs":4000,"retryIntervalMs":100},
  "steps":[
    {"id":"wait","action":"waitFor","level":"happyPath","target":{"role":"AXWindow"},"args":{"present":true}},
    {"id":"type-name","action":"type","level":"happyPath","target":{"identifier":"nameField"},"args":{"text":"Ada"}},
    {"id":"check","action":"assert","level":"happyPath","target":{"identifier":"statusLabel"},"assert":{"property":"value","op":"contains","expected":"Ada"}},
    {"id":"quit","action":"terminate","level":"happyPath"} ] }
JSON
  cat > "$tmp/fail.json" <<JSON
{ "schemaVersion":"1.1","name":"guide demo fail","target":{"path":"$FIXTURE"},
  "defaults":{"timeoutMs":2500,"retryIntervalMs":100},
  "steps":[
    {"id":"wait","action":"waitFor","level":"happyPath","target":{"role":"AXWindow"},"args":{"present":true}},
    {"id":"check","action":"assert","level":"happyPath","target":{"identifier":"statusLabel"},"assert":{"property":"value","op":"equals","expected":"this will not match"}},
    {"id":"quit","action":"terminate","level":"happyPath"} ] }
JSON
  cleanup; sleep 0.5
  run="$("$BIN/autopilot" run "$tmp/pass.json" 2>&1 || true)"
  render_text_png "autopilot run pass.json" "$IMAGES/cli-run.png" "$run"
  cleanup; sleep 0.5
  runf="$("$BIN/autopilot" run "$tmp/fail.json" 2>&1 || true)"
  render_text_png "autopilot run fail.json" "$IMAGES/cli-run-fail.png" "$runf"
  rm -rf "$tmp"
}

# ---- Cockpit window shots (window-id scoped) -----------------------------------
capture_cockpit() {
  local app="$ROOT/.build/release/AutopilotCockpit.app"
  # Assemble a minimal .app around the built binary so it launches as a GUI app.
  if [ ! -d "$app" ]; then
    app="$(/usr/bin/mktemp -d)/AutopilotCockpit.app"
    mkdir -p "$app/Contents/MacOS"
    cp "$BIN/AutopilotCockpit" "$app/Contents/MacOS/AutopilotCockpit"
    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AutopilotCockpit</string>
<key>CFBundleIdentifier</key><string>com.jschwefel.autopilotcockpit</string>
<key>CFBundleName</key><string>AutopilotCockpit</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
    /usr/bin/codesign --force --sign - "$app" 2>/dev/null || true
  fi
  # Launch the Cockpit BINARY directly as a child of this (AX-trusted) shell so it
  # inherits Accessibility permission — `open -n` would detach it and it would show
  # the "permission required" banner. `--attach-pid`/`--mode` put it in a known,
  # populated state deterministically (no fragile UI-driving of its own controls).
  local cockpit_bin="$app/Contents/MacOS/AutopilotCockpit"

  # One launch per shot, each pre-attached to the fixture on the right mode.
  shoot_mode() {
    local mode="$1" out="$2"
    cleanup; sleep 0.5
    /usr/bin/open -n "$FIXTURE"; sleep 2
    local fpid; fpid="$(/usr/bin/pgrep -n -f 'TestHostApp.app' || true)"
    [ -n "$fpid" ] || die "fixture did not launch"
    "$cockpit_bin" --attach-pid "$fpid" --mode "$mode" >/dev/null 2>&1 &
    local cpid=$!
    sleep 4
    /usr/bin/pgrep -f AutopilotCockpit >/dev/null || die "Cockpit did not launch"
    capture_window "$cpid" "$out"
  }

  log "capturing Cockpit windows (attached to the fixture)…"
  shoot_mode inspect "$IMAGES/cockpit-overview.png"
  /bin/cp "$IMAGES/cockpit-overview.png" "$IMAGES/cockpit-inspect.png"
  shoot_mode run    "$IMAGES/cockpit-run.png"
  shoot_mode author "$IMAGES/cockpit-author.png"
}

main() {
  build
  build_helper
  capture_cli
  capture_cockpit
  cleanup
  log "done. Screenshots in docs/images/:"
  ls -1 "$IMAGES"/*.png 2>/dev/null | sed 's#.*/#  #'
}
main "$@"
