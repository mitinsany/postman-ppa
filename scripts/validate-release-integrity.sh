#!/usr/bin/env bash

set -euo pipefail

CHANNEL="latest"
ARCHES=(amd64 arm64)

has_pattern() {
    local pattern="$1"
    local file="$2"
    if command -v rg >/dev/null 2>&1; then
        rg -q "${pattern}" "${file}"
    else
        grep -Eq "${pattern}" "${file}"
    fi
}

echo "[I] Running shell syntax validation..."
bash -n scripts/*.sh scripts/docker/*.sh

echo "[I] Validating desktop files..."
if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate packages/latest/postman/*/root/usr/share/applications/postman.desktop
else
    echo "[I] desktop-file-validate not installed; skipping desktop validation."
fi

release_file="deb/dists/${CHANNEL}/Release"
inrelease_file="deb/dists/${CHANNEL}/InRelease"

if [ -f "${release_file}" ] && ! has_pattern '^Changelogs:' "${release_file}"; then
    >&2 echo "[E] Missing Changelogs header in ${release_file}"
    exit 1
fi
if [ -f "${inrelease_file}" ] && ! has_pattern '^Changelogs:' "${inrelease_file}"; then
    >&2 echo "[E] Missing Changelogs header in ${inrelease_file}"
    exit 1
fi

for arch in "${ARCHES[@]}"; do
    package_json="packages/${CHANNEL}/postman/${arch}/package.json"
    version="$(jq --raw-output --exit-status ".version" "${package_json}")"
    changelog_file="changelogs/main/p/postman/postman_${version}"
    if [ ! -s "${changelog_file}" ]; then
        >&2 echo "[E] Missing or empty changelog file: ${changelog_file}"
        exit 1
    fi
done

echo "[I] Release integrity validation passed."

