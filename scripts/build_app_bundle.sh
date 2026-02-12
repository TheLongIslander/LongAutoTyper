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
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_AUTOMATIC_CHECKS="${SPARKLE_AUTOMATIC_CHECKS:-1}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
ADHOC_SIGN="${ADHOC_SIGN:-0}"
SKIP_SIGN="${SKIP_SIGN:-0}"

ARCHES=()

is_truthy() {
    case "$1" in
        1|true|TRUE|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

xml_escape() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&apos;}"
    printf '%s' "${value}"
}

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
        --feed-url)
            SPARKLE_FEED_URL="$2"
            shift 2
            ;;
        --sparkle-public-key)
            SPARKLE_PUBLIC_ED_KEY="$2"
            shift 2
            ;;
        --disable-automatic-update-checks)
            SPARKLE_AUTOMATIC_CHECKS="0"
            shift
            ;;
        --codesign-identity)
            CODE_SIGN_IDENTITY="$2"
            ADHOC_SIGN="0"
            SKIP_SIGN="0"
            shift 2
            ;;
        --adhoc-sign)
            ADHOC_SIGN="1"
            SKIP_SIGN="0"
            shift
            ;;
        --skip-sign)
            SKIP_SIGN="1"
            ADHOC_SIGN="0"
            CODE_SIGN_IDENTITY=""
            shift
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
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${FRAMEWORKS_DIR}"

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

SPARKLE_FRAMEWORK_SOURCE=""
if [[ -d "${PRIMARY_BIN_DIR}/Sparkle.framework" ]]; then
    SPARKLE_FRAMEWORK_SOURCE="${PRIMARY_BIN_DIR}/Sparkle.framework"
else
    SPARKLE_FRAMEWORK_SOURCE="$(find "${ROOT_DIR}/.build" -type d -name Sparkle.framework -print -quit 2>/dev/null || true)"
fi

if [[ -n "${SPARKLE_FRAMEWORK_SOURCE}" ]]; then
    ditto "${SPARKLE_FRAMEWORK_SOURCE}" "${FRAMEWORKS_DIR}/Sparkle.framework"
    if command -v otool >/dev/null 2>&1 && command -v install_name_tool >/dev/null 2>&1; then
        if ! otool -l "${MACOS_DIR}/${APP_NAME}" | grep -q "@executable_path/../Frameworks"; then
            install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" >/dev/null 2>&1 || true
        fi
    fi
else
    echo "Warning: Sparkle.framework not found in .build output; update checks will fail." >&2
fi

SPARKLE_PLIST_KEYS=""
if [[ -n "${SPARKLE_FEED_URL}" ]]; then
    SPARKLE_FEED_URL_ESCAPED="$(xml_escape "${SPARKLE_FEED_URL}")"
    SPARKLE_PLIST_KEYS="${SPARKLE_PLIST_KEYS}
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL_ESCAPED}</string>"
else
    echo "Warning: SPARKLE_FEED_URL is empty. Set it to your hosted appcast.xml URL." >&2
fi

if [[ -n "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
    SPARKLE_PUBLIC_ED_KEY_ESCAPED="$(xml_escape "${SPARKLE_PUBLIC_ED_KEY}")"
    SPARKLE_PLIST_KEYS="${SPARKLE_PLIST_KEYS}
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_ED_KEY_ESCAPED}</string>"
else
    echo "Warning: SPARKLE_PUBLIC_ED_KEY is empty. Signed updates will be rejected." >&2
fi

if is_truthy "${SPARKLE_AUTOMATIC_CHECKS}"; then
    SPARKLE_PLIST_KEYS="${SPARKLE_PLIST_KEYS}
    <key>SUEnableAutomaticChecks</key>
    <true/>"
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
${SPARKLE_PLIST_KEYS}
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    if is_truthy "${SKIP_SIGN}"; then
        echo "Skipping code signing (--skip-sign)."
    elif [[ -n "${CODE_SIGN_IDENTITY}" ]]; then
        if ! codesign --force --deep --timestamp=none --sign "${CODE_SIGN_IDENTITY}" "${APP_BUNDLE}"; then
            echo "Code signing failed for identity: ${CODE_SIGN_IDENTITY}" >&2
            exit 1
        fi
        echo "Signed app bundle with identity: ${CODE_SIGN_IDENTITY}"
    elif is_truthy "${ADHOC_SIGN}"; then
        if ! codesign --force --deep --sign - "${APP_BUNDLE}"; then
            echo "Ad-hoc code signing failed." >&2
            exit 1
        fi
        echo "Ad-hoc signed app bundle (not stable for Accessibility permission across reinstalls)."
    else
        echo "Warning: app bundle is unsigned." >&2
        echo "Set CODE_SIGN_IDENTITY or pass --codesign-identity for stable Accessibility trust across updates." >&2
        echo "Use --adhoc-sign only for local throwaway builds." >&2
    fi
else
    echo "Warning: codesign not found; app bundle is unsigned." >&2
fi

echo "Built app bundle: ${APP_BUNDLE}"
lipo -info "${MACOS_DIR}/${APP_NAME}"
