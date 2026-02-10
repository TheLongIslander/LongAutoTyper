#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LongAutoTyper"
CONFIGURATION="${CONFIGURATION:-release}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

ARCHES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --version)
            APP_VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCHES+=("$2")
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ ${#ARCHES[@]} -eq 0 ]]; then
    ARCHES=("x86_64" "arm64")
fi

cd "${ROOT_DIR}"

BIN_DIRS=()
EXECUTABLES=()

if [[ -e "${APP_BUNDLE}" && ! -w "${APP_BUNDLE}" ]]; then
    echo "Cannot overwrite ${APP_BUNDLE}: permission denied (likely root-owned)." >&2
    echo "Fix with one of these commands, then rerun:" >&2
    echo "  sudo chown -R \"$(id -un)\":staff \"${APP_BUNDLE}\"" >&2
    echo "  sudo rm -rf \"${APP_BUNDLE}\"" >&2
    exit 1
fi

for ARCH in "${ARCHES[@]}"; do
    echo "Building ${APP_NAME} (${CONFIGURATION}, ${ARCH})..."
    swift build -c "${CONFIGURATION}" --arch "${ARCH}"

    BIN_DIR="$(swift build -c "${CONFIGURATION}" --arch "${ARCH}" --show-bin-path)"
    EXECUTABLE_PATH="${BIN_DIR}/${APP_NAME}"

    if [[ ! -f "${EXECUTABLE_PATH}" ]]; then
        echo "Missing executable for architecture ${ARCH}: ${EXECUTABLE_PATH}" >&2
        exit 1
    fi

    BIN_DIRS+=("${BIN_DIR}")
    EXECUTABLES+=("${EXECUTABLE_PATH}")
done

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

if [[ ${#EXECUTABLES[@]} -gt 1 ]]; then
    lipo -create "${EXECUTABLES[@]}" -output "${MACOS_DIR}/${APP_NAME}"
else
    cp "${EXECUTABLES[0]}" "${MACOS_DIR}/${APP_NAME}"
fi
chmod +x "${MACOS_DIR}/${APP_NAME}"

PRIMARY_BIN_DIR="${BIN_DIRS[0]}"
RESOURCE_BUNDLE="${PRIMARY_BIN_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [[ -d "${RESOURCE_BUNDLE}" ]]; then
    cp -R "${RESOURCE_BUNDLE}" "${RESOURCES_DIR}/"
fi

SOURCE_ICON="${ROOT_DIR}/Sources/${APP_NAME}/Resources/AppIcon.icns"
if [[ -f "${SOURCE_ICON}" ]]; then
    cp "${SOURCE_ICON}" "${RESOURCES_DIR}/AppIcon.icns"
fi

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.longautotyper.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so the bundle can be launched more smoothly in local testing.
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true
fi

echo "Built app bundle: ${APP_BUNDLE}"
lipo -info "${MACOS_DIR}/${APP_NAME}"
