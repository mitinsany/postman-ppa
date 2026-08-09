#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_NOTES_URL="https://mkt.cdn.postman.com/www-next/release-notes/app-release-notes.json"
CHANGELOGS_DIR="${ROOT_DIR}/changelogs/main/p/postman"
CHANNEL="latest"
DEBIAN_REVISION="1"

download_key_for_arch() {
    case "$1" in
        amd64) printf "%s\n" "linux64" ;;
        arm64) printf "%s\n" "linux_arm64" ;;
        *)
            >&2 echo "[E] Unsupported architecture: $1"
            return 1
            ;;
    esac
}

download_url_for_arch() {
    local version="$1"
    local arch="$2"
    printf "https://dl.pstmn.io/download/version/%s/%s\n" "${version}" "$(download_key_for_arch "${arch}")"
}

download_archive_for_url() {
    local url="$1"
    local archive
    archive="$(mktemp)"
    if ! curl -fL --retry 5 --retry-all-errors --connect-timeout 15 "${url}" -o "${archive}"; then
        rm -f "${archive}"
        return 1
    fi
    printf '%s\n' "${archive}"
}

update_package_template() {
    local package_dir="$1"
    local package_version="$2"
    local upstream_version="$3"
    local download_url="$4"
    local download_sha256="$5"
    local package_json="${package_dir}/package.json"

    jq \
        --arg version "${package_version}" \
        --arg upstream_version "${upstream_version}" \
        --arg download_url "${download_url}" \
        --arg download_sha256 "${download_sha256}" \
        '.version = $version | .upstream_version = $upstream_version | .download_url = $download_url | .download_sha256 = $download_sha256' \
        "${package_json}" > "${package_json}.tmp"
    mv "${package_json}.tmp" "${package_json}"
}

compare_version() {
    dpkg --compare-versions "$1" lt "$2"
}

require_non_empty_release_body() {
    local release_body="$1"
    grep -q '[^[:space:]]' <<< "${release_body}"
}

write_public_changelog() {
    local version="$1"
    local release_body="$2"
    mkdir -p "${CHANGELOGS_DIR}"
    printf "%s\n" "${release_body}" > "${CHANGELOGS_DIR}/postman_${version}"
}

cd "${ROOT_DIR}"

release_json="$(mktemp)"
curl -fsSL "${RELEASE_NOTES_URL}" > "${release_json}"

remote_version="$(jq --raw-output --exit-status '.notes[0].version' "${release_json}")"
release_body="$(jq --raw-output --exit-status '.notes[0].content // ""' "${release_json}")"
rm -f "${release_json}"

if [ -z "${remote_version}" ] || [ "${remote_version}" = "null" ]; then
    >&2 echo "[E] Cannot read Postman version from ${RELEASE_NOTES_URL}"
    exit 1
fi
if ! require_non_empty_release_body "${release_body}"; then
    >&2 echo "[E] Release notes are empty for ${remote_version}."
    exit 1
fi

remote_package_version="${remote_version}-${DEBIAN_REVISION}"

[ -f "commit.txt" ] && rm -f "commit.txt"

for arch in amd64 arm64; do
    package_dir="packages/${CHANNEL}/postman/${arch}"
    package_json="${package_dir}/package.json"
    local_version="$(jq --raw-output --exit-status '.version' "${package_json}")"
    package_arch="$(jq --raw-output --exit-status '.architecture' "${package_json}")"
    code="$(jq --raw-output --exit-status '.code' "${package_json}")"
    local_sha256="$(jq --raw-output '.download_sha256 // ""' "${package_json}")"
    download_url="$(download_url_for_arch "${remote_version}" "${package_arch}")"
    package_file="deb/pool/main/p/postman/postman_${remote_package_version}_${package_arch}.deb"

    if ! compare_version "${local_version}" "${remote_package_version}" && [[ "${local_sha256}" =~ ^[0-9a-f]{64}$ ]] && [ -f "${package_file}" ]; then
        >&2 printf "[I] %s: Local (%s) >= Remote (%s). Skipped.\n" "${code}" "${local_version}" "${remote_package_version}"
        continue
    fi

    printf "[I] %s: Local (%s) -> Remote (%s). Updating.\n" "${code}" "${local_version}" "${remote_package_version}"
    archive="$(download_archive_for_url "${download_url}")"
    download_sha256="$(sha256sum "${archive}" | awk '{print $1}')"
    rm -f "${archive}"

    write_public_changelog "${remote_package_version}" "${release_body}"
    update_package_template "${package_dir}" "${remote_package_version}" "${remote_version}" "${download_url}" "${download_sha256}"

    changelog_filename="changelog-postman-${remote_package_version}-${package_arch}.dsc"
    printf "%s\n" "${release_body}" > "/tmp/${changelog_filename}"
    rm -f /tmp/postman_"${remote_package_version}"_"${package_arch}".deb
    "${ROOT_DIR}/scripts/build-single-deb.sh" "${package_dir}" "${changelog_filename}"
    deb_file="/tmp/postman_${remote_package_version}_${package_arch}.deb"
    reprepro --outdir ./deb --ignore=unknownfield -C main includedeb "${CHANNEL}" "${deb_file}"
    echo "Upgrade ${code}: ${local_version} -> ${remote_package_version}" >> "commit.txt"
done

if [ -s "commit.txt" ]; then
    reprepro --outdir ./deb --ignore=unknownfield export "${CHANNEL}"
    "${ROOT_DIR}/scripts/update-release-changelogs.sh"
else
    echo "[I] No package updates detected. Skipping repository metadata export/sign."
fi
