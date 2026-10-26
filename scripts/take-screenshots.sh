#!/usr/bin/env bash
# Installs a simulator build of the app on an iPhone simulator and screenshots each candle state.
# Usage: scripts/take-screenshots.sh <path/to/DigitalCandle.app> <output dir>
set -euo pipefail

APP_PATH="$1"
OUT_DIR="$2"
BUNDLE_ID="com.varusj.DigitalCandle"
mkdir -p "$OUT_DIR"

# Newest iOS runtime, preferring a plain "iPhone NN" / "iPhone NN Pro" model.
UDID=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in devices:
        if not device["name"].startswith("iPhone"):
            continue
        plain = re.fullmatch(r"iPhone \d+( Pro)?", device["name"]) is not None
        key = (version, plain, device["name"])
        if best is None or key > best[0]:
            best = (key, device["udid"])
print(best[1] if best else "")
')
if [ -z "$UDID" ]; then
  echo "No iPhone simulator available" >&2
  exit 1
fi
echo "Using simulator $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl privacy "$UDID" grant microphone "$BUNDLE_ID" || true

# shoot <name> <seconds to wait> [launch arguments...]
shoot() {
  local name="$1" wait="$2"
  shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  # ${@+"$@"}: macOS bash 3.2 treats an empty "$@" as unbound under set -u.
  xcrun simctl launch "$UDID" "$BUNDLE_ID" ${@+"$@"}
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$name.png"
}

shoot 1-unlit 6
shoot 2-lit 4 -DemoPhase lit
shoot 3-blowing 4 -DemoPhase lit -DemoGust 0.8
shoot 4-blown-out 2.2 -DemoPhase blownOut
