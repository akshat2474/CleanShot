#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building CleanShot with Swift Package Manager..."
cd "${ROOT_DIR}"
swift build -c release

APP_DIR="${ROOT_DIR}/build/CleanShot.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Packaging ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp ".build/release/CleanShot" "${MACOS_DIR}/CleanShot"
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Stripping extended attributes and signing ad-hoc..."
xattr -cr "${APP_DIR}"
codesign --force --deep -s - "${APP_DIR}"

echo "==> CleanShot.app bundled successfully at ${APP_DIR}"
