#!/bin/bash
# Run the E2E integration tests for the Augen Web Marker AR example in Chrome.
#
# Requires:
#   - chrome on PATH
#   - chromedriver on PATH (brew install chromedriver, or
#     https://chromedriver.chromium.org/downloads)
#
# As of Flutter 3.44, `flutter test integration_test -d chrome` is NOT
# supported ("Web devices are not supported for integration tests yet."),
# so web E2E must go through `flutter drive` + chromedriver.
set -e
cd "$(dirname "$0")/.."

# Ensure the JS bridge is present in the example's web/ directory.
mkdir -p web
cp ../../web/augen_web_ar.js web/ 2>/dev/null || true

echo "▶ flutter pub get"
flutter pub get

CHROMEDRIVER_BIN="${CHROMEDRIVER:-chromedriver}"

if ! command -v "${CHROMEDRIVER_BIN}" >/dev/null 2>&1; then
  echo "❌ chromedriver not found on PATH."
  echo "   Install with: brew install --cask chromedriver"
  echo "   Or download from https://googlechromelabs.github.io/chrome-for-testing/"
  echo "   (match the chromedriver major version to your installed Chrome)"
  echo ""
  echo "   You can also point this script at a specific binary:"
  echo "     CHROMEDRIVER=/path/to/chromedriver $0"
  exit 1
fi

# On macOS, unblock Gatekeeper if needed (no-op if already cleared).
xattr -d com.apple.quarantine "$(command -v "${CHROMEDRIVER_BIN}")" 2>/dev/null || true

# Warn if chromedriver / chrome major versions don't match.
if command -v google-chrome >/dev/null 2>&1 || [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  CHROME_BIN="$(command -v google-chrome 2>/dev/null || echo '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')"
  CHROME_MAJOR="$("${CHROME_BIN}" --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo '')"
  DRIVER_MAJOR="$("${CHROMEDRIVER_BIN}" --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo '')"
  if [ -n "${CHROME_MAJOR}" ] && [ -n "${DRIVER_MAJOR}" ] && [ "${CHROME_MAJOR}" != "${DRIVER_MAJOR}" ]; then
    echo "⚠️  chromedriver (${DRIVER_MAJOR}) and Chrome (${CHROME_MAJOR}) major versions differ."
    echo "    This will fail with SessionNotCreatedException. Download a matching driver from:"
    echo "    https://googlechromelabs.github.io/chrome-for-testing/"
    echo ""
  fi
fi

PORT="${CHROMEDRIVER_PORT:-4444}"
echo "▶ Starting chromedriver on port ${PORT}…"
"${CHROMEDRIVER_BIN}" --port="${PORT}" >/tmp/chromedriver-augen.log 2>&1 &
DRIVER_PID=$!
trap 'kill ${DRIVER_PID} >/dev/null 2>&1 || true' EXIT

# Give chromedriver a moment to come up.
sleep 2

echo "▶ Running E2E tests on Chrome via flutter drive…"
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/web_marker_ar_test.dart \
  -d chrome \
  --browser-name=chrome
