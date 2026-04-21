#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_PATH="${SHOTX_DERIVED_DATA_PATH:-$PROJECT_ROOT/.derived-data}"
INSTALL_DIR="${SHOTX_APP_INSTALL_DIR:-$HOME/Applications/ShotX-dev}"
BUILT_APP="$DERIVED_DATA_PATH/Build/Products/Debug/ShotX.app"
INSTALLED_APP="$INSTALL_DIR/ShotX.app"
CODE_SIGN_REQUIREMENT_FILE="$PROJECT_ROOT/ShotX/DevCodeSigning.requirements"

xcodebuild \
    -project "$PROJECT_ROOT/ShotX.xcodeproj" \
    -scheme ShotX \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    OTHER_CODE_SIGN_FLAGS="--requirements $CODE_SIGN_REQUIREMENT_FILE" \
    build

osascript -e 'tell application id "com.lynx.shotx" to quit' >/dev/null 2>&1 || true
pkill -x ShotX >/dev/null 2>&1 || true
sleep 0.5

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
codesign \
    --force \
    --sign - \
    --identifier com.lynx.shotx \
    --requirements "$CODE_SIGN_REQUIREMENT_FILE" \
    "$INSTALLED_APP"

open -n "$INSTALLED_APP"
