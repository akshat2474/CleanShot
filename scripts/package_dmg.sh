#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION="${1:-1.0.0}"
echo "=========================================="
echo "  Packaging CleanShot v${VERSION} (DMG & ZIP)"
echo "=========================================="

cd "${ROOT_DIR}"

# 1. Build and bundle the app
echo "==> Step 1: Building and bundling CleanShot.app..."
bash "${SCRIPT_DIR}/bundle_app.sh"

APP_PATH="${ROOT_DIR}/build/CleanShot.app"
BUILD_DIR="${ROOT_DIR}/build"
DMG_NAME="CleanShot-v${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
LATEST_DMG_PATH="${BUILD_DIR}/CleanShot.dmg"
ZIP_NAME="CleanShot-v${VERSION}-macOS.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"
TEMP_DMG="${BUILD_DIR}/pack_temp.dmg"

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} was not found!"
    exit 1
fi

rm -f "${TEMP_DMG}" "${DMG_PATH}" "${LATEST_DMG_PATH}" "${ZIP_PATH}" "${BUILD_DIR}"/*.sha256

# 2. Check if we can run Finder AppleScript styling (local GUI environment)
CAN_STYLE=0
if osascript -e 'tell application "Finder" to get name' >/dev/null 2>&1; then
    CAN_STYLE=1
fi

if [ "${CAN_STYLE}" -eq 1 ]; then
    echo "==> Step 2: Creating styled DMG with Applications link..."
    hdiutil create -size 30m -volname "CleanShot" -fs HFS+ -ov "${TEMP_DMG}" >/dev/null

    # Mount disk image
    DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
    MOUNT_POINT="/Volumes/CleanShot"

    # Wait for mount
    sleep 1

    # Copy App & Create Symlink
    cp -R "${APP_PATH}" "${MOUNT_POINT}/CleanShot.app"
    ln -s /Applications "${MOUNT_POINT}/Applications"

    # Copy background if available
    if [ -f "${ROOT_DIR}/Resources/dmg_background.png" ]; then
        mkdir -p "${MOUNT_POINT}/.background"
        cp "${ROOT_DIR}/Resources/dmg_background.png" "${MOUNT_POINT}/.background/dmg_background.png"
    fi

    # AppleScript Finder layout
    osascript <<EOF || true
tell application "Finder"
    tell disk "CleanShot"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {350, 150, 890, 490}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 110
        try
            set background picture of viewOptions to file ".background:dmg_background.png"
        end try
        set position of item "CleanShot.app" of container window to {140, 160}
        set position of item "Applications" of container window to {400, 160}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

    sync
    hdiutil detach "${DEVICE}" -force >/dev/null 2>&1 || sleep 2 && hdiutil detach "${DEVICE}" >/dev/null 2>&1 || true

    echo "==> Step 3: Compressing styled disk image into read-only UDZO DMG..."
    hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" >/dev/null
    rm -f "${TEMP_DMG}"
else
    echo "==> Step 2: Creating standard DMG (Headless / CI mode)..."
    STAGING_DIR="${BUILD_DIR}/dmg_staging"
    rm -rf "${STAGING_DIR}"
    mkdir -p "${STAGING_DIR}"
    cp -R "${APP_PATH}" "${STAGING_DIR}/CleanShot.app"
    ln -s /Applications "${STAGING_DIR}/Applications"

    echo "==> Step 3: Compressing disk image with hdiutil..."
    hdiutil create \
        -volname "CleanShot" \
        -srcfolder "${STAGING_DIR}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}" >/dev/null
    rm -rf "${STAGING_DIR}"
fi

# Duplicate to latest CleanShot.dmg
cp "${DMG_PATH}" "${LATEST_DMG_PATH}"

# 4. Ad-hoc sign the DMG
echo "==> Step 4: Ad-hoc signing DMG..."
codesign --force -s - "${DMG_PATH}" 2>/dev/null || true
codesign --force -s - "${LATEST_DMG_PATH}" 2>/dev/null || true

# 5. Create ZIP distribution
echo "==> Step 5: Creating ZIP distribution..."
cd "${BUILD_DIR}"
zip -r -q -y "${ZIP_NAME}" "CleanShot.app"
cd "${ROOT_DIR}"

# 6. Compute SHA-256 Checksums
echo "==> Step 6: Computing SHA-256 checksums..."
cd "${BUILD_DIR}"
shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256"
shasum -a 256 "CleanShot.dmg" > "CleanShot.dmg.sha256"
shasum -a 256 "${ZIP_NAME}" > "${ZIP_NAME}.sha256"
cd "${ROOT_DIR}"

echo ""
echo "=========================================="
echo "  Build & Packaging Succeeded!"
echo "=========================================="
echo "Release Artifacts created in ${BUILD_DIR}:"
echo "  • DMG (versioned): ${DMG_PATH} ($(ls -lh "${DMG_PATH}" | awk '{print $5}'))"
echo "  • DMG (latest):    ${LATEST_DMG_PATH} ($(ls -lh "${LATEST_DMG_PATH}" | awk '{print $5}'))"
echo "  • ZIP Archive:     ${ZIP_PATH} ($(ls -lh "${ZIP_PATH}" | awk '{print $5}'))"
echo ""
echo "SHA-256 Checksums:"
cat "${BUILD_DIR}/CleanShot.dmg.sha256"
cat "${BUILD_DIR}/${ZIP_NAME}.sha256"
