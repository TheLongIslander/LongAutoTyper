#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LongAutoTyper"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
PKG_PATH="${DIST_DIR}/${APP_NAME}.pkg"
STAGING_DIR=""
PKG_ROOT=""
SKIP_DMG=0
SKIP_PKG=0
CONFIGURATION="${CONFIGURATION:-release}"
APP_VERSION="${APP_VERSION:-0.1.0}"
ARCH_ARGS=()

cleanup() {
    [[ -n "${STAGING_DIR}" ]] && rm -rf "${STAGING_DIR}"
    [[ -n "${PKG_ROOT}" ]] && rm -rf "${PKG_ROOT}"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-dmg)
            SKIP_DMG=1
            shift
            ;;
        --skip-pkg)
            SKIP_PKG=1
            shift
            ;;
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --version)
            APP_VERSION="$2"
            shift 2
            ;;
        --arch)
            ARCH_ARGS+=("--arch" "$2")
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

mkdir -p "${DIST_DIR}"

BUILD_CMD=(
    "${ROOT_DIR}/scripts/build_app_bundle.sh"
    --configuration "${CONFIGURATION}"
    --version "${APP_VERSION}"
)

if [[ ${#ARCH_ARGS[@]} -gt 0 ]]; then
    BUILD_CMD+=("${ARCH_ARGS[@]}")
fi

"${BUILD_CMD[@]}"

if [[ ${SKIP_DMG} -eq 0 ]]; then
    if ! command -v hdiutil >/dev/null 2>&1; then
        echo "hdiutil not found; skipping DMG creation." >&2
    else
        rm -f "${DMG_PATH}"
        STAGING_DIR="$(mktemp -d)"
        cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
        ln -s /Applications "${STAGING_DIR}/Applications"
        hdiutil create \
            -volname "${APP_NAME}" \
            -srcfolder "${STAGING_DIR}" \
            -ov \
            -format UDZO \
            "${DMG_PATH}" >/dev/null
        rm -rf "${STAGING_DIR}"
        STAGING_DIR=""
        echo "Built DMG: ${DMG_PATH}"
    fi
fi

if [[ ${SKIP_PKG} -eq 0 ]]; then
    if ! command -v pkgbuild >/dev/null 2>&1; then
        echo "pkgbuild not found; skipping PKG creation." >&2
    else
        rm -f "${PKG_PATH}"
        PKG_ROOT="$(mktemp -d)"
        mkdir -p "${PKG_ROOT}/Applications"
        cp -R "${APP_BUNDLE}" "${PKG_ROOT}/Applications/"
        pkgbuild \
            --root "${PKG_ROOT}" \
            --identifier "com.longautotyper.app" \
            --version "${APP_VERSION}" \
            --install-location "/" \
            "${PKG_PATH}" >/dev/null || {
                echo "PKG build failed. This script requires pkgbuild root mode support." >&2
                exit 1
            }

        rm -rf "${PKG_ROOT}"
        PKG_ROOT=""
        echo "Built PKG: ${PKG_PATH}"
    fi
fi

echo "Artifacts directory: ${DIST_DIR}"
