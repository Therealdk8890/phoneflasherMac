#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

APP_PATH="dist/PhoneFlasherMac.app"
DMG_PATH="dist/PhoneFlasherMac.dmg"
STAGING_DIR="build/dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH. Run build.sh first."
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

ditto "$APP_PATH" "$STAGING_DIR/PhoneFlasherMac.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "PhoneFlasherMac" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "Built $DMG_PATH"
