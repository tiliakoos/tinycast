#!/bin/bash
# Rebuild the local Tinycast build and reinstall it into /Applications.
# Personal file: lives on features/tiliakoos only, never in a PR diff.
#
# The bundle id is com.tinycast.app.tiliakoos, not upstream's com.tinycast.app. The app reads its
# channel from the bundle id, so this build counts as a local one and never updates itself.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

IDENTITY="Tinycast Self-Signed"
BUNDLE_ID="com.tinycast.app.tiliakoos"
DERIVED="build/DerivedData"
APP="$DERIVED/Build/Products/Release/Tinycast.app"
DEST="/Applications/Tinycast.app"

if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
    echo "✗ '$IDENTITY' code-signing identity not found (docs/signing.md §1)." >&2
    exit 1
fi

# The version is the newest stable tag the branch contains, so About shows what it is built on.
VERSION="$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-*' | sed 's/^v//')"
BUILD="$(git rev-list --count HEAD)"

xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -derivedDataPath "$DERIVED" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
    -quiet build

./Scripts/verify-signature.sh "$APP"

osascript -e "quit app id \"$BUNDLE_ID\"" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
ditto "$APP" "$DEST"
open "$DEST"

echo "installed $VERSION ($BUILD) from $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
