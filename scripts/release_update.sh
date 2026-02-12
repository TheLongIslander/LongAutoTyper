#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LongAutoTyper"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"
APPCAST_PATH="${DIST_DIR}/appcast.xml"
APPCAST_STAGING_DIR="${DIST_DIR}/appcast-staging"
PAGES_WORKTREE_DIR="${ROOT_DIR}/.release-pages"
GENERATE_APPCAST="${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"

APP_VERSION=""
CONFIGURATION="${CONFIGURATION:-release}"
PAGES_REMOTE="${PAGES_REMOTE:-origin}"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-}"
ARCH_ARGS=()
PACKAGE_ARGS=()
APPCAST_ARGS=()

usage() {
    cat <<EOF
Usage: ./scripts/release_update.sh --version VERSION [options]

Required:
  --version VERSION                      Release version (eg 0.1.3)

Optional:
  --configuration debug|release          Build configuration (default: release)
  --arch x86_64|arm64                    Repeatable architecture flag
  --feed-url URL                         Passed to package_macos.sh
  --sparkle-public-key KEY               Passed to package_macos.sh
  --disable-automatic-update-checks      Passed to package_macos.sh
  --download-url-prefix URL              URL prefix for generated appcast enclosure URLs
  --pages-remote REMOTE                  Git remote for Pages branch (default: origin)
  --pages-branch BRANCH                  GitHub Pages branch (default: gh-pages)
  --account ACCOUNT                      Keychain account for generate_appcast
  -h, --help                             Show this help

Env fallbacks:
  SPARKLE_FEED_URL can be used to infer --download-url-prefix.
EOF
}

cleanup() {
    rm -rf "${APPCAST_STAGING_DIR}"

    if [[ -d "${PAGES_WORKTREE_DIR}" ]]; then
        git worktree remove --force "${PAGES_WORKTREE_DIR}" >/dev/null 2>&1 || true
    fi
    if [[ -d "${PAGES_WORKTREE_DIR}" ]]; then
        rm -rf "${PAGES_WORKTREE_DIR}"
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            APP_VERSION="$2"
            shift 2
            ;;
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --arch)
            ARCH_ARGS+=("--arch" "$2")
            shift 2
            ;;
        --feed-url)
            PACKAGE_ARGS+=("--feed-url" "$2")
            shift 2
            ;;
        --sparkle-public-key)
            PACKAGE_ARGS+=("--sparkle-public-key" "$2")
            shift 2
            ;;
        --disable-automatic-update-checks)
            PACKAGE_ARGS+=("--disable-automatic-update-checks")
            shift
            ;;
        --download-url-prefix)
            DOWNLOAD_URL_PREFIX="$2"
            shift 2
            ;;
        --pages-remote)
            PAGES_REMOTE="$2"
            shift 2
            ;;
        --pages-branch)
            PAGES_BRANCH="$2"
            shift 2
            ;;
        --account)
            APPCAST_ARGS+=("--account" "$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "${APP_VERSION}" ]]; then
    echo "Missing required --version argument." >&2
    usage >&2
    exit 1
fi

if [[ -z "${DOWNLOAD_URL_PREFIX}" ]]; then
    if [[ -n "${SPARKLE_FEED_URL:-}" ]]; then
        DOWNLOAD_URL_PREFIX="${SPARKLE_FEED_URL%/*}/"
    else
        echo "Missing --download-url-prefix and SPARKLE_FEED_URL is not set." >&2
        echo "Example: --download-url-prefix https://thelongislander.github.io/LongAutoTyper/" >&2
        exit 1
    fi
fi

if [[ "${DOWNLOAD_URL_PREFIX}" != */ ]]; then
    DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX}/"
fi

if [[ ! -x "${GENERATE_APPCAST}" ]]; then
    echo "Missing Sparkle appcast tool at ${GENERATE_APPCAST}" >&2
    echo "Run: swift build -c release" >&2
    exit 1
fi

cd "${ROOT_DIR}"

echo "Packaging ${APP_NAME} ${APP_VERSION}..."
PACKAGE_CMD=(
    "${ROOT_DIR}/scripts/package_macos.sh"
    --configuration "${CONFIGURATION}"
    --version "${APP_VERSION}"
)
if [[ ${#ARCH_ARGS[@]} -gt 0 ]]; then
    PACKAGE_CMD+=("${ARCH_ARGS[@]}")
fi
if [[ ${#PACKAGE_ARGS[@]} -gt 0 ]]; then
    PACKAGE_CMD+=("${PACKAGE_ARGS[@]}")
fi
"${PACKAGE_CMD[@]}"

if [[ ! -f "${ZIP_PATH}" ]]; then
    echo "Missing release ZIP: ${ZIP_PATH}" >&2
    exit 1
fi

echo "Generating appcast..."
rm -rf "${APPCAST_STAGING_DIR}"
mkdir -p "${APPCAST_STAGING_DIR}"
cp "${ZIP_PATH}" "${APPCAST_STAGING_DIR}/"
APPCAST_CMD=(
    "${GENERATE_APPCAST}"
    "${APPCAST_STAGING_DIR}"
    --download-url-prefix "${DOWNLOAD_URL_PREFIX}"
)
if [[ ${#APPCAST_ARGS[@]} -gt 0 ]]; then
    APPCAST_CMD+=("${APPCAST_ARGS[@]}")
fi
"${APPCAST_CMD[@]}"

if [[ ! -f "${APPCAST_STAGING_DIR}/appcast.xml" ]]; then
    echo "generate_appcast did not produce appcast.xml" >&2
    exit 1
fi
cp "${APPCAST_STAGING_DIR}/appcast.xml" "${APPCAST_PATH}"

echo "Publishing to ${PAGES_REMOTE}/${PAGES_BRANCH}..."
git fetch "${PAGES_REMOTE}"

if git ls-remote --exit-code --heads "${PAGES_REMOTE}" "${PAGES_BRANCH}" >/dev/null 2>&1; then
    if git show-ref --verify --quiet "refs/heads/${PAGES_BRANCH}"; then
        git worktree add "${PAGES_WORKTREE_DIR}" "${PAGES_BRANCH}"
    else
        git fetch "${PAGES_REMOTE}" "${PAGES_BRANCH}:${PAGES_BRANCH}"
        git worktree add "${PAGES_WORKTREE_DIR}" "${PAGES_BRANCH}"
    fi
else
    git worktree add -b "${PAGES_BRANCH}" "${PAGES_WORKTREE_DIR}" "${PAGES_REMOTE}/main"
fi

find "${PAGES_WORKTREE_DIR}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp "${ZIP_PATH}" "${PAGES_WORKTREE_DIR}/${APP_NAME}.zip"
cp "${APPCAST_PATH}" "${PAGES_WORKTREE_DIR}/appcast.xml"
touch "${PAGES_WORKTREE_DIR}/.nojekyll"

git -C "${PAGES_WORKTREE_DIR}" add "${APP_NAME}.zip" appcast.xml .nojekyll

if git -C "${PAGES_WORKTREE_DIR}" diff --cached --quiet; then
    echo "No gh-pages changes to publish."
else
    git -C "${PAGES_WORKTREE_DIR}" commit -m "Publish Sparkle update ${APP_VERSION}"
    git -C "${PAGES_WORKTREE_DIR}" push -u "${PAGES_REMOTE}" "${PAGES_BRANCH}"
    echo "Published ${APP_VERSION} to GitHub Pages."
fi

echo "Done."
echo "Feed URL: ${DOWNLOAD_URL_PREFIX}appcast.xml"
