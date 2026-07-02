#!/bin/bash
# Build the AutopilotDragSource helper and assemble it into a proper .app bundle
# so it launches as a real foreground GUI app (a bare Mach-O does not — and only
# a foreground app can originate a cross-process file drag).
#
# The helper must sit NEXT TO the autopilot binary it will be driven by, because
# FileDragSource locates it as AutopilotDragSource.app alongside the CLI. So this
# builds it into the matching build-config dir.
#
# Usage: make-drag-source-app.sh [debug|release|both]   (default: both)
#   Builds the helper .app into each requested config's bin dir, so the plan
#   works whether it's driven by the debug OR the release autopilot binary.
#
# Output: <package .build>/<config>/AutopilotDragSource.app  (prints each path)
set -euo pipefail
cd "$(dirname "$0")/.."   # package root

CONFIGS="${1:-both}"
case "$CONFIGS" in
  debug)   CONFIGS="debug" ;;
  release) CONFIGS="release" ;;
  both)    CONFIGS="debug release" ;;
  *) echo "usage: $0 [debug|release|both]" >&2; exit 2 ;;
esac

bundle_into() {
  local flags="$1"          # "" for debug, "-c release" for release
  swift build $flags --product AutopilotDragSource
  local bindir; bindir="$(swift build $flags --show-bin-path)"
  local app="$bindir/AutopilotDragSource.app"

  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS"
  cp "$bindir/AutopilotDragSource" "$app/Contents/MacOS/AutopilotDragSource"
  cat > "$app/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AutopilotDragSource</string>
<key>CFBundleIdentifier</key><string>com.autopilot.dragsource</string>
<key>CFBundleName</key><string>AutopilotDragSource</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PL
  # Ad-hoc codesign so TCC/AX treats it as a stable identity.
  codesign --force --sign - "$app" >/dev/null 2>&1 || true
  echo "$app"
}

for cfg in $CONFIGS; do
  if [ "$cfg" = "release" ]; then bundle_into "-c release"; else bundle_into ""; fi
done
